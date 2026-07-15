import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Can create an active class and a student', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);

    final now = DateTime(2026, 1, 1, 12);
    final classId = 'c1';
    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: Value(classId),
        className: const Value('Test Class'),
        courseType: const Value(CourseType.blsProvider),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    final active = await classRepo.getActiveClass();
    expect(active, isNotNull);
    expect(active!.id, classId);
    expect(active.isActive, true);

    await studentRepo.upsertStudent(
      companion: StudentRecordsCompanion(
        id: const Value('s1'),
        classId: Value(classId),
        displayName: const Value('Alice'),
        nameNeedsReview: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final student = await studentRepo.getById('s1');
    expect(student, isNotNull);
    expect(student!.displayName, 'Alice');
  });

  test('Creating a new active class while one exists throws', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final repo = ClassRepository(db);
    final now = DateTime(2026, 1, 1, 12);

    await repo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const Value('c1'),
        className: const Value('Class 1'),
        courseType: const Value(CourseType.blsProvider),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    await expectLater(
      repo.upsertClass(
        companion: ClassRecordsCompanion(
          id: const Value('c2'),
          className: const Value('Class 2'),
          courseType: const Value(CourseType.blsProvider),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        makeActiveIfNone: true,
      ),
      throwsA(isA<ActiveClassAlreadyExistsException>()),
    );
  });
}
