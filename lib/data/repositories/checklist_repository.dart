import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/utils/id_generator.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class ChecklistRepository {
  ChecklistRepository(this._db, {IdGenerator? idGenerator}) : _idGenerator = idGenerator ?? IdGenerator();

  final AppDatabase? _db;
  final IdGenerator _idGenerator;

  bool get isEnabled => _db != null;

  Future<ChecklistAttempt> createOrGetUnfinalizedAttempt({required String classId, required String studentId, required ChecklistType checklistType}) async {
    final db = _db;
    if (db == null) throw StateError('ChecklistRepository is disabled');

    final existing = await (db.select(db.checklistAttempts)
          ..where((t) => t.studentId.equals(studentId) & t.checklistType.equalsValue(checklistType) & t.finalized.equals(false))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now();
    final attemptId = _idGenerator.newId(prefix: 'attempt');
    final attempt = ChecklistAttemptsCompanion(
      id: Value(attemptId),
      classId: Value(classId),
      studentId: Value(studentId),
      checklistType: Value(checklistType),
      status: const Value(ChecklistAttemptStatus.inProgress),
      finalized: const Value(false),
      finalizedAt: const Value(null),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    try {
      await db.into(db.checklistAttempts).insert(attempt);
    } on Exception catch (e, st) {
      debugPrint('Failed to create checklist attempt: $e\n$st');
      // If a race created the unique (student, type) attempt first, re-read it.
      final retry = await (db.select(db.checklistAttempts)
            ..where((t) => t.studentId.equals(studentId) & t.checklistType.equalsValue(checklistType) & t.finalized.equals(false))
            ..limit(1))
          .getSingleOrNull();
      if (retry != null) return retry;
      rethrow;
    }

    return (await loadAttemptById(attemptId))!;
  }

  Future<ChecklistAttempt?> loadAttemptById(String id) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.checklistAttempts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Returns the current in-progress attempt, if any.
  ///
  /// Selection rule: *unfinalized wins* even if an older finalized attempt exists.
  Future<ChecklistAttempt?> getCurrentAttempt({required String studentId, required ChecklistType checklistType}) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.checklistAttempts)
          ..where((t) => t.studentId.equals(studentId) & t.checklistType.equalsValue(checklistType) & t.finalized.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns the newest finalized attempt (by finalizedAt, falling back to updatedAt).
  Future<ChecklistAttempt?> getLatestFinalizedAttempt({required String studentId, required ChecklistType checklistType}) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.checklistAttempts)
          ..where((t) => t.studentId.equals(studentId) & t.checklistType.equalsValue(checklistType) & t.finalized.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.finalizedAt, mode: OrderingMode.desc, nulls: NullsOrder.last),
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns the current in-progress attempt if it exists, otherwise the newest
  /// finalized attempt.
  ///
  /// This avoids the bug where an older finalized attempt hides a newer in-progress
  /// attempt.
  Future<ChecklistAttempt?> getCurrentOrLatestFinalizedAttempt({required String studentId, required ChecklistType checklistType}) async {
    final current = await getCurrentAttempt(studentId: studentId, checklistType: checklistType);
    if (current != null) return current;
    return getLatestFinalizedAttempt(studentId: studentId, checklistType: checklistType);
  }

  @Deprecated('Use getCurrentAttempt / getLatestFinalizedAttempt / getCurrentOrLatestFinalizedAttempt')
  Future<ChecklistAttempt?> loadLatestAttempt({required String studentId, required ChecklistType checklistType}) =>
      getCurrentOrLatestFinalizedAttempt(studentId: studentId, checklistType: checklistType);

  Stream<List<ChecklistAttempt>> watchAttemptsForStudent(String studentId) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.checklistAttempts)
          ..where((t) => t.studentId.equals(studentId))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<ChecklistItemResult>> watchItemResults(String attemptId) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return (db.select(db.checklistItemResults)
          ..where((t) => t.attemptId.equals(attemptId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<List<ChecklistItemResult>> getItemResults(String attemptId) async {
    final db = _db;
    if (db == null) return const [];
    return (db.select(db.checklistItemResults)..where((t) => t.attemptId.equals(attemptId))).get();
  }

  Future<ChecklistItemResult?> getItemResult({required String attemptId, required String itemId}) async {
    final db = _db;
    if (db == null) return null;
    return (db.select(db.checklistItemResults)
          ..where((t) => t.attemptId.equals(attemptId) & t.itemId.equals(itemId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> saveItemResult({required String attemptId, required String itemId, required ChecklistItemResultValue value}) async {
    final db = _db;
    if (db == null) throw StateError('ChecklistRepository is disabled');
    final now = DateTime.now();
    final id = _idGenerator.checklistItemResultId(attemptId: attemptId, itemId: itemId);
    await db.into(db.checklistItemResults).insertOnConflictUpdate(
          ChecklistItemResultsCompanion(
            id: Value(id),
            attemptId: Value(attemptId),
            itemId: Value(itemId),
            result: Value(value),
            updatedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    await _touchAttempt(attemptId);
  }

  Future<void> saveNotes({required String attemptId, required String itemId, required String? notes}) async {
    final db = _db;
    if (db == null) throw StateError('ChecklistRepository is disabled');
    final now = DateTime.now();
    final id = _idGenerator.checklistItemResultId(attemptId: attemptId, itemId: itemId);

    final existing = await getItemResult(attemptId: attemptId, itemId: itemId);
    final resultValue = existing?.result ?? ChecklistItemResultValue.notEvaluated;
    await db.into(db.checklistItemResults).insertOnConflictUpdate(
          ChecklistItemResultsCompanion(
            id: Value(id),
            attemptId: Value(attemptId),
            itemId: Value(itemId),
            result: Value(resultValue),
            notes: Value(notes),
            updatedAt: Value(now),
            createdAt: Value(existing?.createdAt ?? now),
          ),
        );
    await _touchAttempt(attemptId);
  }

  Future<String?> findFirstMissingRequiredItem({required String attemptId, required ChecklistDefinition definition}) async {
    final db = _db;
    if (db == null) return null;
    final results = await (db.select(db.checklistItemResults)..where((t) => t.attemptId.equals(attemptId))).get();
    final byItemId = {for (final r in results) r.itemId: r};
    for (final item in definition.items.where((i) => i.required).toList()..sort((a, b) => a.order.compareTo(b.order))) {
      final r = byItemId[item.id];
      if (r == null) return item.id;
      if (r.result == ChecklistItemResultValue.notEvaluated) return item.id;
    }
    return null;
  }

  Future<void> finalizeAttempt({required String attemptId, required ChecklistDefinition definition}) async {
    final db = _db;
    if (db == null) throw StateError('ChecklistRepository is disabled');
    final now = DateTime.now();

    await db.transaction(() async {
      final attempt = await loadAttemptById(attemptId);
      if (attempt == null) throw StateError('Attempt not found');
      if (attempt.finalized) return;

      final firstMissing = await findFirstMissingRequiredItem(attemptId: attemptId, definition: definition);
      if (firstMissing != null) {
        throw StateError('Cannot finalize: missing required items');
      }

      final results = await (db.select(db.checklistItemResults)..where((t) => t.attemptId.equals(attemptId))).get();
      final requiredIds = definition.items.where((i) => i.required).map((i) => i.id).toSet();
      final hasRemediation = results.any((r) => requiredIds.contains(r.itemId) && r.result == ChecklistItemResultValue.needsRemediation);
      final status = hasRemediation ? ChecklistAttemptStatus.failed : ChecklistAttemptStatus.passed;

      await (db.update(db.checklistAttempts)..where((t) => t.id.equals(attemptId))).write(
        ChecklistAttemptsCompanion(
          status: Value(status),
          finalized: const Value(true),
          finalizedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> reopenAttempt({required String attemptId}) async {
    final db = _db;
    if (db == null) throw StateError('ChecklistRepository is disabled');
    final now = DateTime.now();
    await (db.update(db.checklistAttempts)..where((t) => t.id.equals(attemptId))).write(
      ChecklistAttemptsCompanion(
        finalized: const Value(false),
        finalizedAt: const Value(null),
        status: const Value(ChecklistAttemptStatus.inProgress),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<ChecklistAttempt>> loadFinalizedAttempts({required String studentId, required ChecklistType checklistType}) async {
    final db = _db;
    if (db == null) return const [];
    return (db.select(db.checklistAttempts)
          ..where((t) => t.studentId.equals(studentId) & t.checklistType.equalsValue(checklistType) & t.finalized.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.finalizedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<void> _touchAttempt(String attemptId) async {
    final db = _db;
    if (db == null) return;
    final now = DateTime.now();
    await (db.update(db.checklistAttempts)..where((t) => t.id.equals(attemptId))).write(ChecklistAttemptsCompanion(updatedAt: Value(now)));
  }
}
