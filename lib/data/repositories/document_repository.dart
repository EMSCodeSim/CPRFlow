import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/drift.dart';

class DocumentRepository {
  DocumentRepository(this._db);

  final AppDatabase? _db;

  bool get isEnabled => _db != null;

  Stream<List<ClassDocument>> watchForClass({required String classId, bool includeDeleted = false}) {
    final db = _db;
    if (db == null) return const Stream.empty();
    final q = db.select(db.classDocuments)..where((t) => t.classId.equals(classId));
    if (!includeDeleted) q.where((t) => t.deleted.equals(false));
    q.orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<ClassDocument>> watchForStudent({required String studentId, bool includeDeleted = false}) {
    final db = _db;
    if (db == null) return const Stream.empty();
    final q = db.select(db.classDocuments)..where((t) => t.studentId.equals(studentId));
    if (!includeDeleted) q.where((t) => t.deleted.equals(false));
    q.orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<List<ClassDocument>> search({
    required String classId,
    String? studentId,
    required String query,
    Set<DocumentType>? types,
    bool includeDeleted = false,
  }) async {
    final db = _db;
    if (db == null) return [];
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final q = db.select(db.classDocuments)..where((t) => t.classId.equals(classId));
    if (studentId != null) q.where((t) => t.studentId.equals(studentId));
    if (!includeDeleted) q.where((t) => t.deleted.equals(false));
    if (types != null && types.isNotEmpty) q.where((t) => t.documentType.isInValues(types.toList()));
    q.orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);

    // Drift does not have portable full-text search by default; use a conservative
    // in-memory filter.
    final all = await q.get();
    return all
        .where((d) =>
            d.displayName.toLowerCase().contains(normalized) ||
            d.originalFilename.toLowerCase().contains(normalized) ||
            (d.notes ?? '').toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  Future<ClassDocument?> getById(String id) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.classDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(ClassDocumentsCompanion companion) async {
    final db = _db;
    if (db == null) throw StateError('DocumentRepository is disabled');
    await db.into(db.classDocuments).insertOnConflictUpdate(companion);
  }

  Future<void> markDeleted({required String id, required bool deleted}) async {
    final db = _db;
    if (db == null) throw StateError('DocumentRepository is disabled');
    await (db.update(db.classDocuments)..where((t) => t.id.equals(id))).write(ClassDocumentsCompanion(deleted: Value(deleted), updatedAt: Value(DateTime.now())));
  }

  Future<void> hardDeleteById(String id) async {
    final db = _db;
    if (db == null) throw StateError('DocumentRepository is disabled');
    await (db.delete(db.classDocuments)..where((t) => t.id.equals(id))).go();
  }
}
