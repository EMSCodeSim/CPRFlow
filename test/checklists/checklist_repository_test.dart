import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Create attempt, save results, and finalize transactionally', () async {
    final db = AppDatabase.inMemory();
    final repo = ChecklistRepository(db);
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

    final attempt = await repo.createOrGetUnfinalizedAttempt(classId: 'c1', studentId: 's1', checklistType: ChecklistType.adult);
    expect(attempt.finalized, isFalse);

    final def = ChecklistRegistry.definitionFor(ChecklistType.adult);
    final required = def.items.where((i) => i.required).toList();
    await repo.saveItemResult(attemptId: attempt.id, itemId: required.first.id, value: ChecklistItemResultValue.passed);
    final missing = await repo.findFirstMissingRequiredItem(attemptId: attempt.id, definition: def);
    expect(missing, isNotNull);

    for (final item in required) {
      await repo.saveItemResult(attemptId: attempt.id, itemId: item.id, value: ChecklistItemResultValue.passed);
    }
    expect(await repo.findFirstMissingRequiredItem(attemptId: attempt.id, definition: def), isNull);
    await repo.finalizeAttempt(attemptId: attempt.id, definition: def);

    final loaded = await repo.loadAttemptById(attempt.id);
    expect(loaded, isNotNull);
    expect(loaded!.finalized, isTrue);
    expect(loaded.status, ChecklistAttemptStatus.passed);
    await db.close();
  });

  test('Current unfinalized attempt overrides older finalized attempt', () async {
    final db = AppDatabase.inMemory();
    final repo = ChecklistRepository(db);
    final now = DateTime(2025, 1, 1, 12, 0);

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

    // Historical finalized PASS.
    final def = ChecklistRegistry.definitionFor(ChecklistType.adult);
    final old = await repo.createOrGetUnfinalizedAttempt(classId: 'c1', studentId: 's1', checklistType: ChecklistType.adult);
    for (final item in def.items.where((i) => i.required)) {
      await repo.saveItemResult(attemptId: old.id, itemId: item.id, value: ChecklistItemResultValue.passed);
    }
    await repo.finalizeAttempt(attemptId: old.id, definition: def);

    // Create a *new* unfinalized attempt by reopening the finalized one first
    // (simulate a new run by directly inserting a new attempt).
    final newerAttemptId = 'attempt_new';
    await db.into(db.checklistAttempts).insert(
      ChecklistAttemptsCompanion(
        id: drift.Value(newerAttemptId),
        classId: const drift.Value('c1'),
        studentId: const drift.Value('s1'),
        checklistType: const drift.Value(ChecklistType.adult),
        status: const drift.Value(ChecklistAttemptStatus.inProgress),
        finalized: const drift.Value(false),
        finalizedAt: const drift.Value(null),
        createdAt: drift.Value(now.add(const Duration(minutes: 10))),
        updatedAt: drift.Value(now.add(const Duration(minutes: 10))),
      ),
    );

    final current = await repo.getCurrentAttempt(studentId: 's1', checklistType: ChecklistType.adult);
    expect(current, isNotNull);
    expect(current!.id, newerAttemptId);

    final latestFinal = await repo.getLatestFinalizedAttempt(studentId: 's1', checklistType: ChecklistType.adult);
    expect(latestFinal, isNotNull);
    expect(latestFinal!.finalized, isTrue);

    final selected = await repo.getCurrentOrLatestFinalizedAttempt(studentId: 's1', checklistType: ChecklistType.adult);
    expect(selected, isNotNull);
    expect(selected!.id, newerAttemptId);
    await db.close();
  });

  test('Latest finalized attempt selects newest finalized when no current attempt', () async {
    final db = AppDatabase.inMemory();
    final repo = ChecklistRepository(db);
    final now = DateTime(2025, 1, 1, 12, 0);

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

    final def = ChecklistRegistry.definitionFor(ChecklistType.adult);
    Future<void> insertFinal(String id, DateTime finalizedAt) async {
      await db.into(db.checklistAttempts).insert(
        ChecklistAttemptsCompanion(
          id: drift.Value(id),
          classId: const drift.Value('c1'),
          studentId: const drift.Value('s1'),
          checklistType: const drift.Value(ChecklistType.adult),
          status: const drift.Value(ChecklistAttemptStatus.passed),
          finalized: const drift.Value(true),
          finalizedAt: drift.Value(finalizedAt),
          createdAt: drift.Value(finalizedAt.subtract(const Duration(minutes: 2))),
          updatedAt: drift.Value(finalizedAt),
        ),
      );
      for (final item in def.items.where((i) => i.required)) {
        await repo.saveItemResult(attemptId: id, itemId: item.id, value: ChecklistItemResultValue.passed);
      }
    }

    await insertFinal('a1', now.add(const Duration(minutes: 1)));
    await insertFinal('a2', now.add(const Duration(minutes: 7)));
    await insertFinal('a3', now.add(const Duration(minutes: 4)));

    final latest = await repo.getLatestFinalizedAttempt(studentId: 's1', checklistType: ChecklistType.adult);
    expect(latest, isNotNull);
    expect(latest!.id, 'a2');

    final selected = await repo.getCurrentOrLatestFinalizedAttempt(studentId: 's1', checklistType: ChecklistType.adult);
    expect(selected!.id, 'a2');
    await db.close();
  });
}
