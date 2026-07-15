import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/utils/id_generator.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class CcfRepository {
  CcfRepository(this._db, {IdGenerator? idGenerator}) : _idGenerator = idGenerator ?? IdGenerator();

  final AppDatabase? _db;
  final IdGenerator _idGenerator;

  bool get isEnabled => _db != null;

  Future<CcfSession> createStandaloneSession({required double passingThreshold}) async {
    return _createSessionInternal(classId: null, studentId: null, passingThreshold: passingThreshold);
  }

  Future<CcfSession> createStudentLinkedSession({required String classId, required String studentId, required double passingThreshold}) async {
    return _createSessionInternal(classId: classId, studentId: studentId, passingThreshold: passingThreshold);
  }

  Future<CcfSession> _createSessionInternal({required String? classId, required String? studentId, required double passingThreshold}) async {
    final db = _db;
    if (db == null) throw StateError('CcfRepository is disabled');

    if ((classId == null) != (studentId == null)) {
      throw ArgumentError('classId and studentId must both be provided for a student-linked session');
    }
    if (classId != null && studentId != null) {
      final student = await (db.select(db.studentRecords)..where((t) => t.id.equals(studentId))..limit(1)).getSingleOrNull();
      if (student == null) throw StateError('Student not found');
      if (student.classId != classId) throw StateError('Student does not belong to class');
    }

    final now = DateTime.now();
    final id = _idGenerator.newId(prefix: 'ccf');
    final companion = CcfSessionsCompanion(
      id: Value(id),
      classId: Value(classId),
      studentId: Value(studentId),
      startedAt: Value(now),
      endedAt: const Value(null),
      totalDurationMilliseconds: const Value(0),
      compressionDurationMilliseconds: const Value(0),
      pauseDurationMilliseconds: const Value(0),
      ccfPercentage: const Value(0),
      passingThreshold: Value(passingThreshold),
      finalized: const Value(false),
      result: const Value(CcfResultValue.incomplete),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await db.into(db.ccfSessions).insert(companion);
    return (await getById(id))!;
  }

  Future<CcfSession?> getById(String id) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.ccfSessions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<List<CcfSession>> watchSessionsForStudent(String studentId) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.ccfSessions)
          ..where((t) => t.studentId.equals(studentId))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<CcfSession?> getLatestFinalizedStudentSession(String studentId) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.ccfSessions)
          ..where((t) => t.studentId.equals(studentId) & t.finalized.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.endedAt, mode: OrderingMode.desc, nulls: NullsOrder.last)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CcfSession?> getLatestStudentSession(String studentId) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.ccfSessions)
          ..where((t) => t.studentId.equals(studentId))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns the latest (by startedAt) session for each student in the class.
  Future<Map<String, CcfSession>> getLatestSessionByStudent({required String classId}) async {
    final db = _db;
    if (db == null) return const {};
    final sessions = await (db.select(db.ccfSessions)
          ..where((t) => t.classId.equals(classId) & t.studentId.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .get();
    final map = <String, CcfSession>{};
    for (final s in sessions) {
      final sid = s.studentId;
      if (sid == null) continue;
      map.putIfAbsent(sid, () => s);
    }
    return map;
  }

  Future<void> saveUnfinishedSession({
    required String sessionId,
    required int totalDurationMs,
    required int compressionDurationMs,
    required int pauseDurationMs,
    required double ccfPercentage,
    required double passingThreshold,
  }) async {
    final db = _db;
    if (db == null) throw StateError('CcfRepository is disabled');
    final now = DateTime.now();
    await (db.update(db.ccfSessions)..where((t) => t.id.equals(sessionId))).write(
      CcfSessionsCompanion(
        totalDurationMilliseconds: Value(totalDurationMs),
        compressionDurationMilliseconds: Value(compressionDurationMs),
        pauseDurationMilliseconds: Value(pauseDurationMs),
        ccfPercentage: Value(ccfPercentage),
        passingThreshold: Value(passingThreshold),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> finalizeSession({
    required String sessionId,
    required DateTime endedAt,
    required int totalDurationMs,
    required int compressionDurationMs,
    required int pauseDurationMs,
    required double ccfPercentage,
    required double passingThreshold,
  }) async {
    final db = _db;
    if (db == null) throw StateError('CcfRepository is disabled');
    final now = DateTime.now();

    await db.transaction(() async {
      final existing = await getById(sessionId);
      if (existing == null) throw StateError('CCF session not found');

      final result = ccfPercentage >= passingThreshold ? CcfResultValue.passed : CcfResultValue.failed;
      await (db.update(db.ccfSessions)..where((t) => t.id.equals(sessionId))).write(
        CcfSessionsCompanion(
          endedAt: Value(endedAt),
          totalDurationMilliseconds: Value(totalDurationMs),
          compressionDurationMilliseconds: Value(compressionDurationMs),
          pauseDurationMilliseconds: Value(pauseDurationMs),
          ccfPercentage: Value(ccfPercentage),
          passingThreshold: Value(passingThreshold),
          finalized: const Value(true),
          result: Value(result),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> deleteUnfinalizedSession(String sessionId) async {
    final db = _db;
    if (db == null) throw StateError('CcfRepository is disabled');
    final existing = await getById(sessionId);
    if (existing == null) return;
    if (existing.finalized) throw StateError('Cannot delete a finalized session');
    try {
      await (db.delete(db.ccfSessions)..where((t) => t.id.equals(sessionId))).go();
    } on Exception catch (e, st) {
      debugPrint('Failed to delete CCF session $sessionId: $e\n$st');
      rethrow;
    }
  }

  Future<void> assignSessionToStudent({required String sessionId, required String classId, required String studentId}) async {
    final db = _db;
    if (db == null) throw StateError('CcfRepository is disabled');

    final student = await (db.select(db.studentRecords)..where((t) => t.id.equals(studentId))..limit(1)).getSingleOrNull();
    if (student == null) throw StateError('Student not found');
    if (student.classId != classId) throw StateError('Student does not belong to class');

    final now = DateTime.now();
    await (db.update(db.ccfSessions)..where((t) => t.id.equals(sessionId))).write(
      CcfSessionsCompanion(classId: Value(classId), studentId: Value(studentId), updatedAt: Value(now)),
    );
  }
}
