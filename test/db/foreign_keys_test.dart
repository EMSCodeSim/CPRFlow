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
    expect(
      () => db.into(db.checklistAttempts).insert(
            ChecklistAttemptsCompanion(
              id: const drift.Value('a1'),
              classId: const drift.Value('missing'),
              studentId: const drift.Value('missingStudent'),
              checklistType: const drift.Value(ChecklistType.adult),
              status: const drift.Value(ChecklistAttemptStatus.inProgress),
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
}
