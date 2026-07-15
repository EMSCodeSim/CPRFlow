import 'dart:async';

typedef ChecklistNotesSaver = Future<void> Function({required String attemptId, required String itemId, required String? notes});

class ChecklistNotesSaveRequest {
  const ChecklistNotesSaveRequest({required this.attemptId, required this.itemId, required this.notes});

  final String attemptId;
  final String itemId;
  final String notes;

  bool isSameTargetAs(ChecklistNotesSaveRequest other) => attemptId == other.attemptId && itemId == other.itemId;
}

/// Serializes checklist note saves so a newer pending edit cannot be lost while
/// an earlier save is in-flight.
class ChecklistNotesSaveQueue {
  ChecklistNotesSaveQueue({required ChecklistNotesSaver saver}) : _saver = saver;

  final ChecklistNotesSaver _saver;

  ChecklistNotesSaveRequest? _pending;
  Object? _lastError;
  bool _drainScheduled = false;
  Future<void> _chain = Future.value();

  ChecklistNotesSaveRequest? get pending => _pending;
  Object? get lastError => _lastError;

  void enqueue(ChecklistNotesSaveRequest request) {
    _pending = request;
    _scheduleDrain();
  }

  Future<void> flush() async {
    _scheduleDrain();
    await _chain;
  }

  Future<void> retry() async {
    if (_pending == null) return;
    _scheduleDrain();
    await _chain;
  }

  void _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    _chain = _chain.then((_) => _drainLoop()).whenComplete(() => _drainScheduled = false);
  }

  Future<void> _drainLoop() async {
    while (true) {
      final req = _pending;
      if (req == null) return;
      _pending = null;
      _lastError = null;

      try {
        final trimmed = req.notes.trim();
        await _saver(attemptId: req.attemptId, itemId: req.itemId, notes: trimmed.isEmpty ? null : trimmed);
      } catch (e) {
        // Restore the request so the UI can offer Retry.
        _pending = req;
        _lastError = e;
        return;
      }
    }
  }
}
