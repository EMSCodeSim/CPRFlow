import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class ScoreRepository {
  ScoreRepository(this._db);

  final AppDatabase? _db;

  bool get isEnabled => _db != null;

  Future<void> saveScore({required String studentId, required int? score}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();
    await (db.update(db.studentRecords)..where((t) => t.id.equals(studentId))).write(
      StudentRecordsCompanion(writtenTestScore: Value(score), updatedAt: Value(now)),
    );
  }

  Future<void> saveMultipleScores({required Map<String, int?> scoresByStudentId}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();
    await db.transaction(() async {
      for (final entry in scoresByStudentId.entries) {
        await (db.update(db.studentRecords)..where((t) => t.id.equals(entry.key))).write(
          StudentRecordsCompanion(writtenTestScore: Value(entry.value), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<void> markScoreFinalized({required String studentId, required bool finalized}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();
    await (db.update(db.studentRecords)..where((t) => t.id.equals(studentId))).write(
      StudentRecordsCompanion(writtenTestingFinalized: Value(finalized), updatedAt: Value(now)),
    );
  }

  /// Marks all *entered* (non-null) scores as finalized.
  Future<void> markEnteredScoresFinalizedForClass(String classId) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();
    await (db.update(db.studentRecords)
          ..where((t) => t.classId.equals(classId) & t.writtenTestScore.isNotNull()))
        .write(StudentRecordsCompanion(writtenTestingFinalized: const Value(true), updatedAt: Value(now)));
  }

  Future<void> clearScore({required String studentId}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();
    try {
      await (db.update(db.studentRecords)..where((t) => t.id.equals(studentId))).write(
        StudentRecordsCompanion(writtenTestScore: const Value(null), writtenTestingFinalized: const Value(false), updatedAt: Value(now)),
      );
    } on Exception catch (e, st) {
      debugPrint('Failed to clear score for $studentId: $e\n$st');
      rethrow;
    }
  }

  Stream<List<StudentRecord>> watchClassScores(String classId) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.studentRecords)
          ..where((t) => t.classId.equals(classId))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .watch();
  }
}
