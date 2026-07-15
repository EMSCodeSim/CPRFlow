import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Create and finalize standalone CCF session', () async {
    final db = AppDatabase.inMemory();
    final repo = CcfRepository(db);

    final session = await repo.createStandaloneSession(passingThreshold: 80);
    expect(session.finalized, isFalse);

    await repo.finalizeSession(
      sessionId: session.id,
      endedAt: DateTime(2025, 1, 1),
      totalDurationMs: 1000,
      compressionDurationMs: 900,
      pauseDurationMs: 100,
      ccfPercentage: 90,
      passingThreshold: 80,
    );

    final loaded = await repo.getById(session.id);
    expect(loaded, isNotNull);
    expect(loaded!.finalized, isTrue);
    expect(loaded.result, CcfResultValue.passed);
    await db.close();
  });

  test('Latest finalized student session returns newest one (limit 1)', () async {
    final db = AppDatabase.inMemory();
    final repo = CcfRepository(db);
    final now = DateTime(2025, 1, 1);

    await db.into(db.classRecords).insert(
      ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.studentRecords).insert(
      StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    final a = await repo.createStudentLinkedSession(classId: 'c1', studentId: 's1', passingThreshold: 80);
    await repo.finalizeSession(
      sessionId: a.id,
      endedAt: now.add(const Duration(minutes: 1)),
      totalDurationMs: 1000,
      compressionDurationMs: 800,
      pauseDurationMs: 200,
      ccfPercentage: 80,
      passingThreshold: 80,
    );
    final b = await repo.createStudentLinkedSession(classId: 'c1', studentId: 's1', passingThreshold: 80);
    await repo.finalizeSession(
      sessionId: b.id,
      endedAt: now.add(const Duration(minutes: 5)),
      totalDurationMs: 1000,
      compressionDurationMs: 900,
      pauseDurationMs: 100,
      ccfPercentage: 90,
      passingThreshold: 80,
    );

    final latest = await repo.getLatestFinalizedStudentSession('s1');
    expect(latest, isNotNull);
    expect(latest!.id, b.id);
    await db.close();
  });

  test('Rejects creating/assigning student-linked session across classes', () async {
    final db = AppDatabase.inMemory();
    final repo = CcfRepository(db);
    final now = DateTime(2025, 1, 1);

    await db.into(db.classRecords).insert(
      ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.classRecords).insert(
      ClassRecordsCompanion(
        id: const drift.Value('c2'),
        className: const drift.Value('C2'),
        courseType: const drift.Value(CourseType.blsProvider),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.studentRecords).insert(
      StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    await expectLater(
      repo.createStudentLinkedSession(classId: 'c2', studentId: 's1', passingThreshold: 80),
      throwsA(isA<StateError>()),
    );

    final session = await repo.createStandaloneSession(passingThreshold: 80);
    await expectLater(
      repo.assignSessionToStudent(sessionId: session.id, classId: 'c2', studentId: 's1'),
      throwsA(isA<StateError>()),
    );
    await db.close();
  });
}
