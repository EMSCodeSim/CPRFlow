import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class ScoreStateUpdate {
  const ScoreStateUpdate({required this.studentId, required this.score, required this.finalized});

  final String studentId;
  final int? score;
  final bool finalized;
}

class ScoreRepository {
  ScoreRepository(this._db);

  final AppDatabase? _db;

  bool get isEnabled => _db != null;

  @Deprecated('Use saveScoreState (atomic score+finalized)')
  Future<void> saveScore({required String studentId, required int? score}) => saveScoreState(studentId: studentId, score: score, finalized: false);

  @Deprecated('Use saveClassScoreStates (atomic score+finalized)')
  Future<void> saveMultipleScores({required Map<String, int?> scoresByStudentId}) async {
    await saveClassScoreStates(
      updates: [
        for (final e in scoresByStudentId.entries) ScoreStateUpdate(studentId: e.key, score: e.value, finalized: false),
      ],
    );
  }

  Future<void> saveScoreState({required String studentId, required int? score, required bool finalized}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();
    await (db.update(db.studentRecords)..where((t) => t.id.equals(studentId))).write(
      StudentRecordsCompanion(
        writtenTestScore: Value(score),
        writtenTestingFinalized: Value(finalized),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> saveClassScoreStates({required List<ScoreStateUpdate> updates}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();

    await db.transaction(() async {
      for (final u in updates) {
        await (db.update(db.studentRecords)..where((t) => t.id.equals(u.studentId))).write(
          StudentRecordsCompanion(
            writtenTestScore: Value(u.score),
            writtenTestingFinalized: Value(u.finalized),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  @Deprecated('Use saveScoreState (atomic score+finalized)')
  Future<void> markScoreFinalized({required String studentId, required bool finalized}) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final existing = await (db.select(db.studentRecords)..where((t) => t.id.equals(studentId))).getSingleOrNull();
    await saveScoreState(studentId: studentId, score: existing?.writtenTestScore, finalized: finalized);
  }

  /// Marks all *entered* (non-null) scores as finalized.
  Future<void> markEnteredScoresFinalizedForClass(String classId) async {
    final db = _db;
    if (db == null) throw StateError('ScoreRepository is disabled');
    final now = DateTime.now();

    await db.transaction(() async {
      // Only finalize non-blank scores.
      final rows = await (db.select(db.studentRecords)..where((t) => t.classId.equals(classId))).get();
      for (final s in rows) {
        if (s.writtenTestScore == null) continue;
        await (db.update(db.studentRecords)..where((t) => t.id.equals(s.id))).write(
          StudentRecordsCompanion(
            writtenTestScore: Value(s.writtenTestScore),
            writtenTestingFinalized: const Value(true),
            updatedAt: Value(now),
          ),
        );
      }
    });
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
