import 'dart:async';

import 'package:cpr_instructor_doc/domain/ccf/ccf_snapshot_save_queue.dart';
import 'package:flutter_test/flutter_test.dart';

CcfSnapshotSaveRequest request(int revision) => CcfSnapshotSaveRequest(
      sessionId: 'session-1',
      totalDurationMs: revision * 1000,
      compressionDurationMs: revision * 800,
      pauseDurationMs: revision * 200,
      ccfPercentage: 80,
      passingThreshold: 80,
      revision: revision,
      reason: 'test-$revision',
      capturedAt: DateTime(2026, 7, 15),
    );

void main() {
  test('serializes writes and keeps only the newest pending snapshot', () async {
    final firstGate = Completer<void>();
    final written = <int>[];

    final queue = CcfSnapshotSaveQueue(
      writer: (snapshot) async {
        written.add(snapshot.revision);
        if (snapshot.revision == 1) {
          await firstGate.future;
        }
      },
    );

    final first = queue.enqueue(request(1));
    await Future<void>.delayed(Duration.zero);
    final second = queue.enqueue(request(2));
    final third = queue.enqueue(request(3));

    expect(queue.hasUnsavedChanges, isTrue);
    firstGate.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(await third, isTrue);
    expect(written, [1, 3]);
    expect(queue.lastSavedRevision, 3);
    expect(queue.hasUnsavedChanges, isFalse);
  });

  test('newer pending snapshot survives an older failed write', () async {
    final firstGate = Completer<void>();
    final written = <int>[];
    var failFirst = true;

    final queue = CcfSnapshotSaveQueue(
      writer: (snapshot) async {
        written.add(snapshot.revision);
        if (snapshot.revision == 1) {
          await firstGate.future;
          if (failFirst) {
            failFirst = false;
            throw StateError('first write failed');
          }
        }
      },
    );

    final first = queue.enqueue(request(1));
    await Future<void>.delayed(Duration.zero);
    final newer = queue.enqueue(request(2));
    firstGate.complete();

    expect(await first, isFalse);
    expect(await newer, isFalse);
    expect(queue.hasPending, isTrue);
    expect(queue.hasUnsavedChanges, isTrue);
    expect(queue.lastError, isA<StateError>());

    expect(await queue.retry(), isTrue);
    expect(written, [1, 2]);
    expect(queue.lastSavedRevision, 2);
    expect(queue.lastError, isNull);
    expect(queue.hasUnsavedChanges, isFalse);
  });

  test('dirty timer state remains unsaved until its revision is written', () async {
    final gate = Completer<void>();
    final queue = CcfSnapshotSaveQueue(
      writer: (_) => gate.future,
    );

    queue.markDirty(1);
    expect(queue.hasUnsavedChanges, isTrue);

    final save = queue.enqueue(request(1));
    queue.markDirty(2);
    expect(queue.hasUnsavedChanges, isTrue);

    gate.complete();
    expect(await save, isTrue);
    expect(queue.lastSavedRevision, 1);
    expect(queue.hasUnsavedChanges, isTrue);

    final latest = queue.enqueue(request(2));
    expect(await latest, isTrue);
    expect(queue.lastSavedRevision, 2);
    expect(queue.hasUnsavedChanges, isFalse);
  });
}
