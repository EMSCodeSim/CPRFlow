import 'dart:async';
import 'dart:collection';

typedef ChecklistNotesSaver = Future<void> Function({
  required String attemptId,
  required String itemId,
  required String? notes,
});

class ChecklistNotesSaveRequest {
  const ChecklistNotesSaveRequest({
    required this.attemptId,
    required this.itemId,
    required this.notes,
  });

  final String attemptId;
  final String itemId;
  final String notes;

  String get targetKey => '$attemptId::$itemId';

  bool isSameTargetAs(ChecklistNotesSaveRequest other) =>
      attemptId == other.attemptId && itemId == other.itemId;
}

/// Serializes checklist note saves and coalesces rapid edits per checklist item.
///
/// Important guarantees:
/// - Only one database write runs at a time.
/// - The newest text for a given item wins.
/// - A failed older write never overwrites a newer queued edit.
/// - Notes for different items remain independent.
class ChecklistNotesSaveQueue {
  ChecklistNotesSaveQueue({required ChecklistNotesSaver saver}) : _saver = saver;

  final ChecklistNotesSaver _saver;

  final LinkedHashMap<String, ChecklistNotesSaveRequest> _pendingByTarget =
      LinkedHashMap<String, ChecklistNotesSaveRequest>();
  final LinkedHashMap<String, ChecklistNotesSaveRequest> _failedByTarget =
      LinkedHashMap<String, ChecklistNotesSaveRequest>();
  final LinkedHashMap<String, Object> _errorsByTarget =
      LinkedHashMap<String, Object>();

  ChecklistNotesSaveRequest? _inFlight;
  Future<void> _drainFuture = Future<void>.value();
  bool _draining = false;

  ChecklistNotesSaveRequest? get pending {
    if (_pendingByTarget.isNotEmpty) return _pendingByTarget.values.first;
    if (_failedByTarget.isNotEmpty) return _failedByTarget.values.first;
    return null;
  }

  ChecklistNotesSaveRequest? get inFlight => _inFlight;
  Object? get lastError =>
      _errorsByTarget.isEmpty ? null : _errorsByTarget.values.first;
  bool get hasUnsavedWork =>
      _inFlight != null ||
      _pendingByTarget.isNotEmpty ||
      _failedByTarget.isNotEmpty;

  void enqueue(ChecklistNotesSaveRequest request) {
    final key = request.targetKey;

    // A new edit is the desired state. Replace older queued/failed text for the
    // same item, but never disturb requests for another item.
    _pendingByTarget[key] = request;
    _failedByTarget.remove(key);
    _errorsByTarget.remove(key);
    _scheduleDrain();
  }

  Future<void> flush() async {
    _scheduleDrain();
    await _drainFuture;
  }

  Future<void> retry() async {
    if (_failedByTarget.isNotEmpty) {
      for (final entry in _failedByTarget.entries.toList()) {
        // Do not replace a newer pending edit for the same target.
        _pendingByTarget.putIfAbsent(entry.key, () => entry.value);
      }
      _failedByTarget.clear();
      _errorsByTarget.clear();
    }
    _scheduleDrain();
    await _drainFuture;
  }

  void _scheduleDrain() {
    if (_draining || _pendingByTarget.isEmpty) return;
    _draining = true;
    _drainFuture = _drainFuture.then((_) => _drainLoop()).whenComplete(() {
      _draining = false;
      // A request may have arrived after the loop observed an empty queue.
      if (_pendingByTarget.isNotEmpty) _scheduleDrain();
    });
  }

  Future<void> _drainLoop() async {
    while (_pendingByTarget.isNotEmpty) {
      final key = _pendingByTarget.keys.first;
      final request = _pendingByTarget.remove(key)!;
      _inFlight = request;

      try {
        final trimmed = request.notes.trim();
        await _saver(
          attemptId: request.attemptId,
          itemId: request.itemId,
          notes: trimmed.isEmpty ? null : trimmed,
        );
        _failedByTarget.remove(key);
        _errorsByTarget.remove(key);
      } catch (error) {
        // If a newer edit was queued while this request was in flight, keep the
        // newer edit. Otherwise retain the failed request for an explicit retry.
        if (!_pendingByTarget.containsKey(key)) {
          _failedByTarget[key] = request;
        }
        _errorsByTarget[key] = error;
      } finally {
        _inFlight = null;
      }
    }
  }
}
