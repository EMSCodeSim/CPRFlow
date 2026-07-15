import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Class round-trip persists all fields and updates selected fields', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final repo = ClassRepository(db);

    final now = DateTime(2026, 1, 1, 12, 0);
    final classId = 'c_all';
    final classDate = DateTime(2026, 2, 3);
    final startTime = DateTime(2026, 2, 3, 9, 15);
    final endTime = DateTime(2026, 2, 3, 16, 45);
    final skillsDate = DateTime(2026, 2, 10);
    final issueDate = DateTime(2026, 2, 11);

    await repo.upsertClass(
      companion: ClassRecordsCompanion(
        id: Value(classId),
        className: const Value('Mega Class'),
        courseType: const Value(CourseType.blsProvider),
        classDate: Value(classDate),
        startTime: Value(startTime),
        endTime: Value(endTime),
        location: const Value('HQ'),
        leadInstructor: const Value('Lead'),
        additionalInstructor: const Value('Addl'),
        trainingCenter: const Value('Center'),
        trainingSite: const Value('Site'),
        writtenTestRequired: const Value(true),
        passingScore: const Value(84),
        ccfRequired: const Value(true),
        defaultSkillsCheckOffDate: Value(skillsDate),
        defaultIssueDate: Value(issueDate),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    final loaded = await repo.getById(classId);
    expect(loaded, isNotNull);
    expect(loaded!.className, 'Mega Class');
    expect(loaded.courseType, CourseType.blsProvider);
    expect(loaded.classDate, classDate);
    expect(loaded.startTime, startTime);
    expect(loaded.endTime, endTime);
    expect(loaded.location, 'HQ');
    expect(loaded.leadInstructor, 'Lead');
    expect(loaded.additionalInstructor, 'Addl');
    expect(loaded.trainingCenter, 'Center');
    expect(loaded.trainingSite, 'Site');
    expect(loaded.writtenTestRequired, true);
    expect(loaded.passingScore, 84);
    expect(loaded.ccfRequired, true);
    expect(loaded.defaultSkillsCheckOffDate, skillsDate);
    expect(loaded.defaultIssueDate, issueDate);

    await repo.upsertClass(
      companion: ClassRecordsCompanion(
        id: Value(classId),
        className: const Value('Mega Class v2'),
        courseType: const Value(CourseType.blsProvider),
        location: const Value('HQ West'),
        passingScore: const Value(90),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now.add(const Duration(minutes: 5))),
      ),
      makeActiveIfNone: true,
    );

    final updated = await repo.getById(classId);
    expect(updated, isNotNull);
    expect(updated!.className, 'Mega Class v2');
    expect(updated.location, 'HQ West');
    expect(updated.passingScore, 90);
  });

  test('Student round-trip persists all fields and does not drop original full name', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);

    final now = DateTime(2026, 1, 1, 12, 0);
    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const Value('c1'),
        className: const Value('Class'),
        courseType: const Value(CourseType.blsProvider),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const Value('s1'),
        classId: const Value('c1'),
        displayName: const Value('Display'),
        originalFullName: const Value('Orig Full'),
        firstName: const Value('First'),
        lastName: const Value('Last'),
        email: const Value('a@b.com'),
        phone: const Value('555'),
        nameNeedsReview: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final loaded = await studentRepo.getById('s1');
    expect(loaded, isNotNull);
    expect(loaded!.displayName, 'Display');
    expect(loaded.originalFullName, 'Orig Full');
    expect(loaded.firstName, 'First');
    expect(loaded.lastName, 'Last');
    expect(loaded.email, 'a@b.com');
    expect(loaded.phone, '555');
    expect(loaded.nameNeedsReview, true);

    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const Value('s1'),
        classId: const Value('c1'),
        displayName: const Value('Display2'),
        firstName: const Value('First2'),
        lastName: const Value('Last2'),
        nameNeedsReview: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now.add(const Duration(minutes: 1))),
      ),
    );

    final updated = await studentRepo.getById('s1');
    expect(updated, isNotNull);
    expect(updated!.displayName, 'Display2');
    expect(updated.firstName, 'First2');
    expect(updated.lastName, 'Last2');
    expect(updated.originalFullName, 'Orig Full');
  });
}
