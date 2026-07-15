import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class ActiveClassAlreadyExistsException implements Exception {
  ActiveClassAlreadyExistsException();

  @override
  String toString() => 'ActiveClassAlreadyExistsException';
}

class ClassRepository {
  ClassRepository(this._db);

  final AppDatabase? _db;

  bool get isEnabled => _db != null;

  Stream<ClassRecord?> watchActiveClass() {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.classRecords)..where((t) => t.isActive.equals(true))).watchSingleOrNull();
  }

  Stream<List<ClassRecord>> watchAllClasses() {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.classRecords)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])).watch();
  }

  Future<ClassRecord?> getActiveClass() async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.classRecords)..where((t) => t.isActive.equals(true))).getSingleOrNull();
  }

  Future<ClassRecord?> getById(String id) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.classRecords)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertClass({required ClassRecordsCompanion companion, required bool makeActiveIfNone}) async {
    final db = _db;
    if (db == null) throw StateError('ClassRepository is disabled');

    await db.transaction(() async {
      final active = await getActiveClass();
      final incomingId = companion.id.value;

      if (active != null && active.id != incomingId) {
        if (companion.isActive.present && companion.isActive.value == true) {
          throw ActiveClassAlreadyExistsException();
        }
        if (makeActiveIfNone) {
          // Caller requested activation when none exists, but we do have one.
          throw ActiveClassAlreadyExistsException();
        }
      }

      final now = DateTime.now();
      final toWrite = companion.copyWith(updatedAt: Value(now));
      await db.into(db.classRecords).insertOnConflictUpdate(toWrite);

      final shouldActivate = (companion.isActive.present && companion.isActive.value == true) || (active == null && makeActiveIfNone);
      if (shouldActivate) {
        await (db.update(db.classRecords)..where((t) => t.id.equals(incomingId))).write(const ClassRecordsCompanion(isActive: Value(true)));
        await (db.update(db.classRecords)..where((t) => t.id.equals(incomingId).not())).write(const ClassRecordsCompanion(isActive: Value(false)));
      }
    });
  }

  Future<void> setActiveClass(String classId) async {
    final db = _db;
    if (db == null) throw StateError('ClassRepository is disabled');
    await db.transaction(() async {
      final active = await getActiveClass();
      if (active != null && active.id != classId) {
        // Phase 2 safety: Never silently deactivate/switch the active class.
        throw ActiveClassAlreadyExistsException();
      }
      await (db.update(db.classRecords)..where((t) => t.id.equals(classId))).write(const ClassRecordsCompanion(isActive: Value(true)));
      await (db.update(db.classRecords)..where((t) => t.id.equals(classId).not())).write(const ClassRecordsCompanion(isActive: Value(false)));
    });
  }

  Future<void> deactivateActiveClass() async {
    final db = _db;
    if (db == null) return;
    await (db.update(db.classRecords)..where((t) => t.isActive.equals(true))).write(const ClassRecordsCompanion(isActive: Value(false)));
  }

  Future<void> deleteAllForTestOnly() async {
    final db = _db;
    if (db == null) return;
    debugPrint('Deleting all class records (test only)');
    await db.delete(db.classRecords).go();
  }
}
