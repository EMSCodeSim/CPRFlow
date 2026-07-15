import 'dart:async';

/// Immutable timer snapshot captured at the moment a save is requested.
class CcfSnapshotSaveRequest {
  const CcfSnapshotSaveRequest({
    required this.sessionId,
    required this.totalDurationMs,
    required this.compressionDurationMs,
    required this.pauseDurationMs,
    required this.ccfPercentage,
    required this.passingThreshold,
    required this.revision,
    required this.reason,
    required this.capturedAt,
  });

  final String sessionId;
  final int totalDurationMs;
  final int compressionDurationMs;
  final int pauseDurationMs;
  final double ccfPercentage;
  final double passingThreshold;
  final int revision;
  final String reason;
  final DateTime capturedAt;
}

typedef CcfSnapshotWriter = Future<void> Function(
  CcfSnapshotSaveRequest request,
);

/// Serializes unfinished CCF snapshot writes.
///
/// While a write is in progress, only the newest pending snapshot is retained.
/// If an older write fails, a newer pending snapshot is never replaced by the
/// older data. Call [retry] or enqueue a new snapshot to resume processing.
class CcfSnapshotSaveQueue {
  CcfSnapshotSaveQueue({
    required CcfSnapshotWriter writer,
    void Function()? onStateChanged,
  })  : _writer = writer,
        _onStateChanged = onStateChanged;

  final CcfSnapshotWriter _writer;
  void Function()? _onStateChanged;

  CcfSnapshotSaveRequest? _pending;
  Future<bool>? _drainFuture;
  bool _isSaving = false;
  bool _disposed = false;
  Object? _lastError;
  StackTrace? _lastStackTrace;
  DateTime? _lastSuccessfulSaveAt;
  int _latestDirtyRevision = 0;
  int _lastSavedRevision = 0;

  bool get isSaving => _isSaving;
  bool get hasPending => _pending != null;
  bool get hasUnsavedChanges =>
      _latestDirtyRevision > _lastSavedRevision || _pending != null || _isSaving;
  Object? get lastError => _lastError;
  StackTrace? get lastStackTrace => _lastStackTrace;
  DateTime? get lastSuccessfulSaveAt => _lastSuccessfulSaveAt;
  int get lastSavedRevision => _lastSavedRevision;

  void markDirty(int revision) {
    if (_disposed) return;
    if (revision > _latestDirtyRevision) {
      _latestDirtyRevision = revision;
      _notify();
    }
  }

  Future<bool> enqueue(CcfSnapshotSaveRequest request) {
    if (_disposed) return Future<bool>.value(false);

    if (request.revision > _latestDirtyRevision) {
      _latestDirtyRevision = request.revision;
    }

    // Keep only the newest pending state. The in-flight request continues.
    if (_pending == null || request.revision >= _pending!.revision) {
      _pending = request;
    }
    _notify();
    return _ensureDrain();
  }

  /// Retries the newest unsaved request after a failed write.
  Future<bool> retry() {
    if (_disposed || _pending == null) return Future<bool>.value(false);
    return _ensureDrain();
  }

  /// Waits until every queued snapshot has been written.
  ///
  /// If the most recent write failed, the failed newest request remains queued
  /// and this returns false without discarding it.
  Future<bool> flush() {
    if (_disposed) return Future<bool>.value(false);
    if (_pending == null && !_isSaving) {
      return Future<bool>.value(
        _lastError == null && _latestDirtyRevision <= _lastSavedRevision,
      );
    }
    return _ensureDrain();
  }

  /// Waits only for the currently running drain. This does not force a failed
  /// request to retry and is useful before a final write supersedes snapshots.
  Future<void> waitForInFlight() async {
    final current = _drainFuture;
    if (current != null) {
      await current;
    }
  }

  void markSavedThrough(int revision) {
    if (_disposed) return;
    if (revision > _lastSavedRevision) {
      _lastSavedRevision = revision;
    }
    if (_latestDirtyRevision < _lastSavedRevision) {
      _latestDirtyRevision = _lastSavedRevision;
    }
    _pending = null;
    _lastError = null;
    _lastStackTrace = null;
    _lastSuccessfulSaveAt = DateTime.now();
    _notify();
  }

  void reset() {
    if (_disposed) return;
    _pending = null;
    _lastError = null;
    _lastStackTrace = null;
    _lastSuccessfulSaveAt = null;
    _latestDirtyRevision = 0;
    _lastSavedRevision = 0;
    _notify();
  }

  Future<bool> _ensureDrain() {
    final current = _drainFuture;
    if (current != null) return current;

    late final Future<bool> future;
    future = _drain().whenComplete(() {
      if (identical(_drainFuture, future)) {
        _drainFuture = null;
      }
    });
    _drainFuture = future;
    return future;
  }

  Future<bool> _drain() async {
    while (!_disposed && _pending != null) {
      final request = _pending!;
      _pending = null;
      _isSaving = true;
      _notify();

      try {
        await _writer(request);
        if (_disposed) return false;

        if (request.revision > _lastSavedRevision) {
          _lastSavedRevision = request.revision;
        }
        _lastError = null;
        _lastStackTrace = null;
        _lastSuccessfulSaveAt = DateTime.now();
      } catch (error, stackTrace) {
        if (_disposed) return false;

        _lastError = error;
        _lastStackTrace = stackTrace;

        // Preserve a newer pending request. Otherwise retain the failed request
        // so Retry Save can write the exact state that failed.
        if (_pending == null || _pending!.revision <= request.revision) {
          _pending = request;
        }
        _isSaving = false;
        _notify();
        return false;
      }

      _isSaving = false;
      _notify();
    }

    return !_disposed &&
        _lastError == null &&
        _pending == null &&
        _latestDirtyRevision <= _lastSavedRevision;
  }

  void dispose() {
    _disposed = true;
    _onStateChanged = null;
    _pending = null;
  }

  void _notify() {
    if (_disposed) return;
    _onStateChanged?.call();
  }
}
