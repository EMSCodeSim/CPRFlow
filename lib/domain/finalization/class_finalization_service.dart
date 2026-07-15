import 'dart:convert';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_student_result.dart';
import 'package:cpr_instructor_doc/domain/finalization/finalization_audit_actions.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_checksum.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_row_codec.dart';
import 'package:cpr_instructor_doc/utils/id_generator.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class FinalizationStaleReviewException implements Exception {
  @override
  String toString() => 'FinalizationStaleReviewException';
}

class FinalizationValidationException implements Exception {
  FinalizationValidationException(this.message);
  final String message;
  @override
  String toString() => 'FinalizationValidationException: $message';
}

class ClassFinalizationRequest {
  const ClassFinalizationRequest({
    required this.classId,
    required this.allowIncompleteStudents,
    required this.instructorName,
    required this.instructorInitials,
    required this.expectedClassUpdatedAt,
    required this.expectedStudentUpdatedAt,
  });

  final String classId;
  final bool allowIncompleteStudents;
  final String? instructorName;
  final String? instructorInitials;

  final DateTime expectedClassUpdatedAt;
  final Map<String, DateTime> expectedStudentUpdatedAt;
}

class ClassFinalizationResult {
  const ClassFinalizationResult({
    required this.classId,
    required this.snapshotId,
    required this.snapshotNumber,
    required this.lifecycleStatus,
    required this.passedCount,
    required this.incompleteCount,
    required this.failedCount,
    required this.finalizedAt,
    required this.checksum,
  });

  final String classId;
  final String snapshotId;
  final int snapshotNumber;
  final ClassLifecycleStatus lifecycleStatus;
  final int passedCount;
  final int incompleteCount;
  final int failedCount;
  final DateTime finalizedAt;
  final String checksum;
}

/// Owns the Phase 3 finalization transaction.
class ClassFinalizationService {
  ClassFinalizationService({required AppDatabase db, required StudentCompletionService completionService})
      : _db = db,
        _completionService = completionService;

  final AppDatabase _db;
  final StudentCompletionService _completionService;

  Future<void> saveProgress({required String classId}) async {
    final now = DateTime.now();
    await (_db.update(_db.classRecords)..where((t) => t.id.equals(classId))).write(
      ClassRecordsCompanion(finalizationStatus: const Value(ClassFinalizationStatus.inProgress), updatedAt: Value(now)),
    );
  }

  Future<ClassFinalizationResult> finalize(ClassFinalizationRequest request) async {
    final now = DateTime.now();
    final ids = IdGenerator();

    return _db.transaction(() async {
      final clazz = await (_db.select(_db.classRecords)..where((t) => t.id.equals(request.classId))).getSingleOrNull();
      if (clazz == null) throw FinalizationValidationException('Class not found');
      if (clazz.lifecycleStatus != ClassLifecycleStatus.active) {
        throw FinalizationValidationException('Only active classes can be finalized');
      }

      if (clazz.updatedAt != request.expectedClassUpdatedAt) throw FinalizationStaleReviewException();

      final students = await (_db.select(_db.studentRecords)..where((t) => t.classId.equals(clazz.id))).get();
      if (students.isEmpty) throw FinalizationValidationException('At least one student is required');

      for (final s in students) {
        final expected = request.expectedStudentUpdatedAt[s.id];
        if (expected == null || expected != s.updatedAt) throw FinalizationStaleReviewException();
      }

      _validateRequiredClassInformation(clazz);

      // Bulk load data needed for snapshot-based completion.
      final attempts = await (_db.select(_db.checklistAttempts)..where((t) => t.classId.equals(clazz.id))).get();
      final itemResults = await (_db.select(_db.checklistItemResults)).get();
      final resultsByAttempt = <String, List<ChecklistItemResult>>{};
      for (final r in itemResults) {
        (resultsByAttempt[r.attemptId] ??= []).add(r);
      }

      final ccfSessions = await (_db.select(_db.ccfSessions)..where((t) => t.classId.equals(clazz.id))).get();
      final ccfByStudent = <String, List<CcfSession>>{};
      for (final s in ccfSessions) {
        final sid = s.studentId;
        if (sid == null) continue;
        (ccfByStudent[sid] ??= []).add(s);
      }

      FinalStudentResult compute(StudentRecord student) {
        final attemptsForStudent = attempts.where((a) => a.studentId == student.id).toList(growable: false);
        final ccfForStudent = ccfByStudent[student.id] ?? const [];
        final automatic = _completionService.computeForStudentFromData(
          clazz: clazz,
          student: student,
          attemptsForStudent: attemptsForStudent,
          itemResultsByAttemptId: resultsByAttempt,
          ccfSessionsForStudent: ccfForStudent,
        );
        return FinalStudentResult.fromAutomaticAndStudent(automatic: automatic, student: student);
      }

      final finalResults = {for (final s in students) s.id: compute(s)};

      final passedCount = finalResults.values.where((r) => r.finalResult == OverallStudentResult.pass).length;
      final incompleteCount = finalResults.values.where((r) => r.finalResult == OverallStudentResult.incomplete).length;
      final failedCount = finalResults.values.where((r) => r.finalResult == OverallStudentResult.fail).length;

      if (!request.allowIncompleteStudents && incompleteCount > 0) {
        throw FinalizationValidationException('One or more students are still incomplete');
      }

      // Snapshot number per class.
      final existing = await (_db.select(_db.finalClassSnapshots)..where((t) => t.classId.equals(clazz.id))).get();
      final nextNumber = (existing.map((e) => e.snapshotNumber).fold<int>(0, (p, n) => n > p ? n : p)) + 1;
      final snapshotId = ids.newId(prefix: 'snap');

      final lifecycle = request.allowIncompleteStudents && incompleteCount > 0
          ? ClassLifecycleStatus.completedIncomplete
          : ClassLifecycleStatus.completed;

      final snapshot = _buildSnapshot(
        clazz: clazz,
        lifecycle: lifecycle,
        snapshotNumber: nextNumber,
        finalizedAt: now,
        results: finalResults,
        students: students,
      );

      final checklistData = _buildChecklistSnapshotData(
        students: students,
        attempts: attempts,
        resultsByAttempt: resultsByAttempt,
      );
      final ccfData = _buildCcfSnapshotData(students: students, sessions: ccfSessions);
      final scoreData = _buildScoreSnapshotData(clazz: clazz, students: students);
      final completionData = {
        for (final entry in finalResults.entries)
          entry.key: {
            'automatic': entry.value.automatic.overallResult.name,
            'override': entry.value.overrideType.name,
            'final': entry.value.finalResult.name,
            'missingRequirements': entry.value.missingRequirements,
            'failureReasons': entry.value.failureReasons,
            'warnings': entry.value.warnings,
          },
      };
      final canonical = SnapshotRowCodec.canonicalFromSegments(
        snapshot: snapshot,
        checklistData: checklistData,
        ccfData: ccfData,
        scoreData: scoreData,
        completionResults: completionData,
      );
      final checksum = SnapshotChecksum.sha256HexFromUtf8(canonical);

      final snapshotRow = FinalClassSnapshotsCompanion(
        id: Value(snapshotId),
        classId: Value(clazz.id),
        snapshotNumber: Value(nextNumber),
        schemaVersion: const Value(1),
        completionRuleVersion: Value(clazz.completionRuleVersion),
        checklistDefinitionVersion: Value(clazz.checklistDefinitionVersion),
        createdAt: Value(now),
        finalizedAt: Value(now),
        classDataJson: Value(jsonEncode(snapshot.classData.toJson())),
        studentDataJson: Value(jsonEncode(snapshot.students.map((s) => s.toJson()).toList(growable: false))),
        checklistDataJson: Value(jsonEncode(checklistData)),
        ccfDataJson: Value(jsonEncode(ccfData)),
        scoreDataJson: Value(jsonEncode(scoreData)),
        completionResultsJson: Value(jsonEncode(completionData)),
        totalsJson: Value(jsonEncode(snapshot.totals.toJson())),
        checksum: Value(checksum),
      );

      await _db.into(_db.finalClassSnapshots).insert(snapshotRow);

      // Update the class (still within same transaction).
      await (_db.update(_db.classRecords)..where((t) => t.id.equals(clazz.id))).write(
        ClassRecordsCompanion(
          isActive: const Value(false),
          lifecycleStatus: Value(lifecycle),
          finalizationStatus: const Value(ClassFinalizationStatus.notStarted),
          finalizedAt: Value(now),
          completedAt: Value(now),
          archivedAt: Value(now),
          finalizedPassedCount: Value(passedCount),
          finalizedIncompleteCount: Value(incompleteCount),
          finalizedFailedCount: Value(failedCount),
          activeSnapshotId: Value(snapshotId),
          snapshotSchemaVersion: const Value(1),
          updatedAt: Value(now),
        ),
      );

      // Ensure no other class remains selected.
      await (_db.update(_db.classRecords)..where((t) => t.isActive.equals(true))).write(const ClassRecordsCompanion(isActive: Value(false)));

      final auditAction = lifecycle == ClassLifecycleStatus.completed
          ? FinalizationAuditAction.classFinalized
          : FinalizationAuditAction.classFinalizedWithIncompleteStudents;
      await _db.into(_db.finalizationAuditEntries).insert(
        FinalizationAuditEntriesCompanion(
          id: Value(ids.newId(prefix: 'audit')),
          classId: Value(clazz.id),
          snapshotId: Value(snapshotId),
          action: Value(auditAction.sql),
          timestamp: Value(now),
          instructorName: Value(request.instructorName),
          instructorInitials: Value(request.instructorInitials),
          newValueJson: Value(jsonEncode({'passed': passedCount, 'incomplete': incompleteCount, 'failed': failedCount})),
        ),
      );

      debugPrint('Class finalized: classId=${clazz.id} snapshot=$snapshotId checksum=$checksum');

      return ClassFinalizationResult(
        classId: clazz.id,
        snapshotId: snapshotId,
        snapshotNumber: nextNumber,
        lifecycleStatus: lifecycle,
        passedCount: passedCount,
        incompleteCount: incompleteCount,
        failedCount: failedCount,
        finalizedAt: now,
        checksum: checksum,
      );
    });
  }

  void _validateRequiredClassInformation(ClassRecord clazz) {
    final missing = <String>[];
    if (clazz.className.trim().isEmpty) missing.add('Class name');
    if (clazz.courseType.name.trim().isEmpty) missing.add('Course type');
    if (clazz.classDate == null) missing.add('Class date');
    if (clazz.location == null || clazz.location!.trim().isEmpty) missing.add('Location');
    if (clazz.leadInstructor == null || clazz.leadInstructor!.trim().isEmpty) missing.add('Lead instructor');
    if (clazz.writtenTestRequired) {
      final passing = clazz.passingScore;
      if (passing == null || passing <= 0) missing.add('Written passing score');
    }
    if (missing.isNotEmpty) throw FinalizationValidationException('Missing required information: ${missing.join(', ')}');
  }

  FinalClassSnapshotV1 _buildSnapshot({
    required ClassRecord clazz,
    required ClassLifecycleStatus lifecycle,
    required int snapshotNumber,
    required DateTime finalizedAt,
    required Map<String, FinalStudentResult> results,
    required List<StudentRecord> students,
  }) {
    String? fmt(DateTime? dt) => dt?.toIso8601String();

    String lifecycleLabel(ClassLifecycleStatus status) => switch (status) {
      ClassLifecycleStatus.active => 'active',
      ClassLifecycleStatus.finalizationInProgress => 'finalizationInProgress',
      ClassLifecycleStatus.completed => 'completed',
      ClassLifecycleStatus.completedIncomplete => 'completedIncomplete',
    };

    final classSnap = FinalSnapshotClassV1(
      classId: clazz.id,
      className: clazz.className,
      courseType: clazz.courseType.name,
      classDate: fmt(clazz.classDate),
      startTime: fmt(clazz.startTime),
      endTime: fmt(clazz.endTime),
      location: clazz.location,
      leadInstructor: clazz.leadInstructor,
      additionalInstructor: clazz.additionalInstructor,
      trainingCenter: clazz.trainingCenter,
      trainingSite: clazz.trainingSite,
      writtenTestRequired: clazz.writtenTestRequired,
      writtenPassingScore: clazz.passingScore,
      ccfRequired: clazz.ccfRequired,
      defaultSkillsCheckOffDate: fmt(clazz.defaultSkillsCheckOffDate),
      defaultIssueDate: fmt(clazz.defaultIssueDate),
      lifecycleStatus: lifecycleLabel(lifecycle),
      snapshotNumber: snapshotNumber,
    );

    DateTime? effectiveSkills(StudentRecord s) => s.skillsCheckOffDate ?? clazz.defaultSkillsCheckOffDate;
    DateTime? effectiveIssue(StudentRecord s) => s.issueDate ?? clazz.defaultIssueDate;

    final studentSnaps = students.map((s) {
      final r = results[s.id]!;
      return FinalSnapshotStudentV1(
        studentId: s.id,
        displayName: s.displayName,
        originalFullName: s.originalFullName,
        firstName: s.firstName,
        lastName: s.lastName,
        email: s.email,
        phone: s.phone,
        nameNeedsReview: s.nameNeedsReview,
        writtenScore: s.writtenTestScore,
        writtenFinalized: s.writtenTestingFinalized,
        effectiveSkillsCheckOffDate: fmt(effectiveSkills(s)),
        effectiveIssueDate: fmt(effectiveIssue(s)),
        automaticResult: r.automatic.overallResult,
        manualOverride: s.manualResultOverride.name,
        manualOverrideReason: s.manualResultReason,
        finalResult: r.finalResult,
        missingRequirements: r.missingRequirements,
        failureReasons: r.failureReasons,
        warnings: r.warnings,
      );
    }).toList(growable: false);

    final overrideCount = students.where((s) => s.manualResultOverride != ManualStudentResultOverride.none).length;
    final totals = FinalSnapshotTotalsV1(
      totalStudents: students.length,
      passedCount: studentSnaps.where((s) => s.finalResult == OverallStudentResult.pass).length,
      incompleteCount: studentSnaps.where((s) => s.finalResult == OverallStudentResult.incomplete).length,
      failedCount: studentSnaps.where((s) => s.finalResult == OverallStudentResult.fail).length,
      manualOverrideCount: overrideCount,
    );

    return FinalClassSnapshotV1(
      schemaVersion: 1,
      completionRuleVersion: clazz.completionRuleVersion,
      checklistDefinitionVersion: clazz.checklistDefinitionVersion,
      classData: classSnap,
      students: studentSnaps,
      totals: totals,
      createdAt: finalizedAt,
      finalizedAt: finalizedAt,
    );
  }
  List<Map<String, Object?>> _buildChecklistSnapshotData({
    required List<StudentRecord> students,
    required List<ChecklistAttempt> attempts,
    required Map<String, List<ChecklistItemResult>> resultsByAttempt,
  }) {
    final studentIds = students.map((e) => e.id).toSet();
    final rows = <Map<String, Object?>>[];
    for (final attempt in attempts.where((a) => studentIds.contains(a.studentId))) {
      final definition = ChecklistRegistry.definitionFor(attempt.checklistType);
      final byItem = {for (final r in resultsByAttempt[attempt.id] ?? const <ChecklistItemResult>[]) r.itemId: r};
      rows.add({
        'attemptId': attempt.id,
        'classId': attempt.classId,
        'studentId': attempt.studentId,
        'checklistType': attempt.checklistType.name,
        'status': attempt.status.name,
        'finalized': attempt.finalized,
        'finalizedAt': attempt.finalizedAt?.toIso8601String(),
        'updatedAt': attempt.updatedAt.toIso8601String(),
        'items': [
          for (final item in [...definition.items]..sort((a, b) => a.order.compareTo(b.order)))
            {
              'itemId': item.id,
              'title': item.title,
              'instructorPrompt': item.instructorPrompt,
              'required': item.required,
              'order': item.order,
              'section': item.section,
              'imageAssetPath': item.imageAssetPath,
              'result': byItem[item.id]?.result.name ?? ChecklistItemResultValue.notEvaluated.name,
              'notes': byItem[item.id]?.notes,
            },
        ],
      });
    }
    rows.sort((a, b) {
      final sa = '${a['studentId']}|${a['checklistType']}|${a['attemptId']}';
      final sb = '${b['studentId']}|${b['checklistType']}|${b['attemptId']}';
      return sa.compareTo(sb);
    });
    return rows;
  }

  List<Map<String, Object?>> _buildCcfSnapshotData({
    required List<StudentRecord> students,
    required List<CcfSession> sessions,
  }) {
    final studentIds = students.map((e) => e.id).toSet();
    final rows = sessions.where((s) => s.studentId != null && studentIds.contains(s.studentId)).map((s) => {
      'sessionId': s.id,
      'classId': s.classId,
      'studentId': s.studentId,
      'startedAt': s.startedAt.toIso8601String(),
      'endedAt': s.endedAt?.toIso8601String(),
      'totalDurationMilliseconds': s.totalDurationMilliseconds,
      'compressionDurationMilliseconds': s.compressionDurationMilliseconds,
      'pauseDurationMilliseconds': s.pauseDurationMilliseconds,
      'ccfPercentage': s.ccfPercentage,
      'passingThreshold': s.passingThreshold,
      'finalized': s.finalized,
      'result': s.result.name,
      'updatedAt': s.updatedAt.toIso8601String(),
    }).toList(growable: false);
    rows.sort((a, b) => '${a['studentId']}|${a['startedAt']}|${a['sessionId']}'.compareTo('${b['studentId']}|${b['startedAt']}|${b['sessionId']}'));
    return rows;
  }

  List<Map<String, Object?>> _buildScoreSnapshotData({
    required ClassRecord clazz,
    required List<StudentRecord> students,
  }) => [
    for (final s in [...students]..sort((a, b) => a.id.compareTo(b.id)))
      {
        'studentId': s.id,
        'writtenTestRequired': clazz.writtenTestRequired,
        'passingScore': clazz.passingScore,
        'score': s.writtenTestScore,
        'finalized': s.writtenTestingFinalized,
      },
  ];

}
