import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/score_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Save and clear written score', () async {
    final db = AppDatabase.inMemory();
    final repo = ScoreRepository(db);
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

    await repo.saveScore(studentId: 's1', score: 88);
    var s = await (db.select(db.studentRecords)..where((t) => t.id.equals('s1'))).getSingle();
    expect(s.writtenTestScore, 88);

    await repo.markScoreFinalized(studentId: 's1', finalized: true);
    s = await (db.select(db.studentRecords)..where((t) => t.id.equals('s1'))).getSingle();
    expect(s.writtenTestingFinalized, isTrue);

    await repo.clearScore(studentId: 's1');
    s = await (db.select(db.studentRecords)..where((t) => t.id.equals('s1'))).getSingle();
    expect(s.writtenTestScore, isNull);
    expect(s.writtenTestingFinalized, isFalse);
    await db.close();
  });
}
