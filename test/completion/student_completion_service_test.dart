import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Optional CCF produces notRequired when missing', () async {
    final db = AppDatabase.inMemory();
    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);
    final checklistRepo = ChecklistRepository(db);
    final ccfRepo = CcfRepository(db);

    final now = DateTime(2025, 1, 1);
    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
      makeActiveIfNone: true,
    );
    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    final clazz = (await classRepo.getActiveClass())!;
    final student = (await studentRepo.getById('s1'))!;

    final service = StudentCompletionService.unwired();
    service.wire(checklistRepository: checklistRepo, ccfRepository: ccfRepo);

    final result = await service.computeForStudent(clazz: clazz, student: student);
    expect(result.ccfStatus, RequirementStatus.notRequired);
    expect(result.overallResult, OverallStudentResult.incomplete);
    await db.close();
  });

  test('Finalized failing written score fails overall when required', () async {
    final db = AppDatabase.inMemory();
    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);
    final checklistRepo = ChecklistRepository(db);
    final ccfRepo = CcfRepository(db);
    final now = DateTime(2025, 1, 1);

    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        writtenTestRequired: const drift.Value(true),
        passingScore: const drift.Value(84),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
      makeActiveIfNone: true,
    );
    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        writtenTestScore: const drift.Value(70),
        writtenTestingFinalized: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    // Make both checklists pass.
    final clazz = (await classRepo.getActiveClass())!;
    final attemptA = await checklistRepo.createOrGetUnfinalizedAttempt(classId: clazz.id, studentId: 's1', checklistType: ChecklistType.adult);
    final attemptI = await checklistRepo.createOrGetUnfinalizedAttempt(classId: clazz.id, studentId: 's1', checklistType: ChecklistType.infantChild);
    for (final item in ChecklistRegistry.definitionFor(ChecklistType.adult).items.where((i) => i.required)) {
      await checklistRepo.saveItemResult(attemptId: attemptA.id, itemId: item.id, value: ChecklistItemResultValue.passed);
    }
    await checklistRepo.finalizeAttempt(attemptId: attemptA.id, definition: ChecklistRegistry.definitionFor(ChecklistType.adult));
    for (final item in ChecklistRegistry.definitionFor(ChecklistType.infantChild).items.where((i) => i.required)) {
      await checklistRepo.saveItemResult(attemptId: attemptI.id, itemId: item.id, value: ChecklistItemResultValue.passed);
    }
    await checklistRepo.finalizeAttempt(attemptId: attemptI.id, definition: ChecklistRegistry.definitionFor(ChecklistType.infantChild));

    final student = (await studentRepo.getById('s1'))!;
    final service = StudentCompletionService.unwired();
    service.wire(checklistRepository: checklistRepo, ccfRepository: ccfRepo);

    final r = await service.computeForStudent(clazz: clazz, student: student);
    expect(r.writtenTestStatus, RequirementStatus.failed);
    expect(r.overallResult, OverallStudentResult.fail);
    await db.close();
  });

  test('New unfinalized checklist attempt makes completion incomplete until finalized', () async {
    final db = AppDatabase.inMemory();
    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);
    final checklistRepo = ChecklistRepository(db);
    final ccfRepo = CcfRepository(db);
    final now = DateTime(2025, 1, 1);

    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
      makeActiveIfNone: true,
    );
    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    final clazz = (await classRepo.getActiveClass())!;

    // Finalize adult + infant as PASS.
    Future<void> makePass(ChecklistType type) async {
      final def = ChecklistRegistry.definitionFor(type);
      final attempt = await checklistRepo.createOrGetUnfinalizedAttempt(classId: clazz.id, studentId: 's1', checklistType: type);
      for (final item in def.items.where((i) => i.required)) {
        await checklistRepo.saveItemResult(attemptId: attempt.id, itemId: item.id, value: ChecklistItemResultValue.passed);
      }
      await checklistRepo.finalizeAttempt(attemptId: attempt.id, definition: def);
    }

    await makePass(ChecklistType.adult);
    await makePass(ChecklistType.infantChild);

    final service = StudentCompletionService.unwired()..wire(checklistRepository: checklistRepo, ccfRepository: ccfRepo);
    var student = (await studentRepo.getById('s1'))!;
    var r = await service.computeForStudent(clazz: clazz, student: student);
    expect(r.adultStatus, ChecklistStatus.passed);

    // Insert a newer unfinalized adult attempt with no results; completion must
    // become incomplete (older finalized PASS must not remain visible).
    await db.into(db.checklistAttempts).insert(
      ChecklistAttemptsCompanion(
        id: const drift.Value('adult_new'),
        classId: drift.Value(clazz.id),
        studentId: const drift.Value('s1'),
        checklistType: const drift.Value(ChecklistType.adult),
        status: const drift.Value(ChecklistAttemptStatus.inProgress),
        finalized: const drift.Value(false),
        finalizedAt: const drift.Value(null),
        createdAt: drift.Value(now.add(const Duration(hours: 1))),
        updatedAt: drift.Value(now.add(const Duration(hours: 1))),
      ),
    );

    student = (await studentRepo.getById('s1'))!;
    r = await service.computeForStudent(clazz: clazz, student: student);
    expect(r.adultStatus, ChecklistStatus.incomplete);
    expect(r.overallResult, OverallStudentResult.incomplete);

    // Finalize the new attempt as PASS; completion should return to PASS.
    final defAdult = ChecklistRegistry.definitionFor(ChecklistType.adult);
    for (final item in defAdult.items.where((i) => i.required)) {
      await checklistRepo.saveItemResult(attemptId: 'adult_new', itemId: item.id, value: ChecklistItemResultValue.passed);
    }
    await checklistRepo.finalizeAttempt(attemptId: 'adult_new', definition: defAdult);

    r = await service.computeForStudent(clazz: clazz, student: student);
    expect(r.adultStatus, ChecklistStatus.passed);
    await db.close();
  });

  test('Missing legacy passingScore uses 84 and adds a warning', () async {
    final db = AppDatabase.inMemory();
    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);
    final checklistRepo = ChecklistRepository(db);
    final ccfRepo = CcfRepository(db);
    final now = DateTime(2025, 1, 1);

    // writtenTestRequired true but passingScore missing (malformed/migrated).
    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        writtenTestRequired: const drift.Value(true),
        passingScore: const drift.Value(null),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
      makeActiveIfNone: true,
    );
    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        writtenTestScore: const drift.Value(80),
        writtenTestingFinalized: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    final clazz = (await classRepo.getActiveClass())!;

    // Make both checklists pass.
    Future<void> makePass(ChecklistType type) async {
      final def = ChecklistRegistry.definitionFor(type);
      final attempt = await checklistRepo.createOrGetUnfinalizedAttempt(classId: clazz.id, studentId: 's1', checklistType: type);
      for (final item in def.items.where((i) => i.required)) {
        await checklistRepo.saveItemResult(attemptId: attempt.id, itemId: item.id, value: ChecklistItemResultValue.passed);
      }
      await checklistRepo.finalizeAttempt(attemptId: attempt.id, definition: def);
    }

    await makePass(ChecklistType.adult);
    await makePass(ChecklistType.infantChild);

    final student = (await studentRepo.getById('s1'))!;
    final service = StudentCompletionService.unwired()..wire(checklistRepository: checklistRepo, ccfRepository: ccfRepo);
    final r = await service.computeForStudent(clazz: clazz, student: student);

    // 80 is below fallback 84.
    expect(r.writtenTestStatus, RequirementStatus.failed);
    expect(r.overallResult, OverallStudentResult.fail);
    expect(r.validationWarnings, isNotEmpty);
    expect(r.validationWarnings.join(' '), contains('defaulted'));

    await db.close();
  });
}
