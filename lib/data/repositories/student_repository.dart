import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class StudentRepository {
  StudentRepository(this._db);

  final AppDatabase? _db;

  bool get isEnabled => _db != null;

  Stream<List<StudentRecord>> watchStudentsForClass(String classId) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.studentRecords)..where((t) => t.classId.equals(classId))..orderBy([(t) => OrderingTerm(expression: t.displayName)])).watch();
  }

  Future<List<StudentRecord>> getForClass(String classId) async {
    final db = _db;
    if (db == null) return const [];
    return (db.select(db.studentRecords)..where((t) => t.classId.equals(classId))..orderBy([(t) => OrderingTerm(expression: t.displayName)])).get();
  }

  Future<StudentRecord?> getById(String id) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.studentRecords)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<StudentRecord?> watchById(String id) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.studentRecords)..where((t) => t.id.equals(id))..limit(1)).watchSingleOrNull();
  }

  Future<void> upsertStudent({required StudentRecordsCompanion companion}) async {
    final db = _db;
    if (db == null) throw StateError('StudentRepository is disabled');

    final now = DateTime.now();
    final toWrite = companion.copyWith(updatedAt: Value(now));
    await db.into(db.studentRecords).insertOnConflictUpdate(toWrite);
  }

  Future<void> deleteAllForTestOnly() async {
    final db = _db;
    if (db == null) return;
    debugPrint('Deleting all student records (test only)');
    await db.delete(db.studentRecords).go();
  }
}
