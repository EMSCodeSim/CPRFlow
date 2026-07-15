import 'dart:async';

import 'package:cpr_instructor_doc/domain/checklists/checklist_notes_save_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Two rapid edits on same item save newest text', () async {
    final saved = <String>[];
    final queue = ChecklistNotesSaveQueue(
      saver: ({required attemptId, required itemId, required notes}) async {
        saved.add('$attemptId/$itemId:${notes ?? ''}');
      },
    );

    queue.enqueue(const ChecklistNotesSaveRequest(attemptId: 'a', itemId: 'i', notes: 'first'));
    queue.enqueue(const ChecklistNotesSaveRequest(attemptId: 'a', itemId: 'i', notes: 'second'));
    await queue.flush();

    expect(saved, ['a/i:second']);
  });

  test('Edit during in-flight save is not lost', () async {
    final saved = <String>[];
    final gate = Completer<void>();
    var first = true;

    final queue = ChecklistNotesSaveQueue(
      saver: ({required attemptId, required itemId, required notes}) async {
        if (first) {
          first = false;
          await gate.future;
        }
        saved.add('${notes ?? ''}');
      },
    );

    queue.enqueue(const ChecklistNotesSaveRequest(attemptId: 'a', itemId: 'i', notes: 'v1'));
    // Allow drain to start.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    queue.enqueue(const ChecklistNotesSaveRequest(attemptId: 'a', itemId: 'i', notes: 'v2'));
    gate.complete();
    await queue.flush();

    expect(saved.last, 'v2');
  });

  test('Save failure preserves request for retry', () async {
    var calls = 0;
    final saved = <String>[];
    final queue = ChecklistNotesSaveQueue(
      saver: ({required attemptId, required itemId, required notes}) async {
        calls += 1;
        if (calls == 1) throw StateError('fail');
        saved.add(notes ?? '');
      },
    );

    queue.enqueue(const ChecklistNotesSaveRequest(attemptId: 'a', itemId: 'i', notes: 'v1'));
    await queue.flush();
    expect(queue.lastError, isNotNull);
    expect(queue.pending, isNotNull);

    await queue.retry();
    expect(queue.lastError, isNull);
    expect(queue.pending, isNull);
    expect(saved, ['v1']);
  });
}
