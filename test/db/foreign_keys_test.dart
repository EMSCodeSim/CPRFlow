import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Foreign keys are enabled in in-memory test database', () async {
    final db = AppDatabase.inMemory();
    final row = await db.customSelect('PRAGMA foreign_keys;').getSingle();
    expect(row.data.values.first, 1);
    await db.close();
  });

  test('Checklist attempt cannot reference a missing class', () async {
    final db = AppDatabase.inMemory();
    final now = DateTime(2025, 1, 1);

    await db.into(db.classRecords).insert(
          ClassRecordsCompanion(
            id: const drift.Value('real-class'),
            className: const drift.Value('Class'),
            courseType: const drift.Value(CourseType.blsProvider),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
    await db.into(db.studentRecords).insert(
          StudentRecordsCompanion(
            id: const drift.Value('student-1'),
            classId: const drift.Value('real-class'),
            displayName: const drift.Value('Student'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

    await expectLater(
      db.into(db.checklistAttempts).insert(
            ChecklistAttemptsCompanion(
              id: const drift.Value('attempt-1'),
              classId: const drift.Value('missing-class'),
              studentId: const drift.Value('student-1'),
              checklistType: const drift.Value(ChecklistType.adult),
              status:
                  const drift.Value(ChecklistAttemptStatus.inProgress),
              finalized: const drift.Value(false),
              finalizedAt: const drift.Value(null),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await db.close();
  });

  test('Checklist attempt cannot reference a missing student', () async {
    final db = AppDatabase.inMemory();
    final now = DateTime(2025, 1, 1);

    await db.into(db.classRecords).insert(
          ClassRecordsCompanion(
            id: const drift.Value('class-1'),
            className: const drift.Value('Class'),
            courseType: const drift.Value(CourseType.blsProvider),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

    await expectLater(
      db.into(db.checklistAttempts).insert(
            ChecklistAttemptsCompanion(
              id: const drift.Value('attempt-1'),
              classId: const drift.Value('class-1'),
              studentId: const drift.Value('missing-student'),
              checklistType: const drift.Value(ChecklistType.adult),
              status:
                  const drift.Value(ChecklistAttemptStatus.inProgress),
              finalized: const drift.Value(false),
              finalizedAt: const drift.Value(null),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await db.close();
  });

  test('Checklist item result cannot reference a missing attempt', () async {
    final db = AppDatabase.inMemory();
    final now = DateTime(2025, 1, 1);

    await expectLater(
      db.into(db.checklistItemResults).insert(
            ChecklistItemResultsCompanion(
              id: const drift.Value('result-1'),
              attemptId: const drift.Value('missing-attempt'),
              itemId: const drift.Value('adult_scene_safety_ppe'),
              result:
                  const drift.Value(ChecklistItemResultValue.passed),
              notes: const drift.Value(null),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await db.close();
  });
}
