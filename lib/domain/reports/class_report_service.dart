import 'dart:convert';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_row_codec.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:flutter/foundation.dart';

class ClassReportService {
  ClassReportService({
    required AppDatabase db,
    required ClassRepository classRepository,
    required StudentRepository studentRepository,
    required ChecklistRepository checklistRepository,
    required CcfRepository ccfRepository,
    required StudentCompletionService completionService,
  })  : _db = db,
        _classRepository = classRepository,
        _studentRepository = studentRepository,
        _checklistRepository = checklistRepository,
        _ccfRepository = ccfRepository,
        _completionService = completionService;

  final AppDatabase _db;
  final ClassRepository _classRepository;
  final StudentRepository _studentRepository;
  final ChecklistRepository _checklistRepository;
  final CcfRepository _ccfRepository;
  final StudentCompletionService _completionService;

  Future<ClassReportData> buildForLiveActiveClass() async {
    final clazz = await _classRepository.getActiveClass();
    if (clazz == null) throw StateError('No active class');
    return buildForLiveClass(classId: clazz.id);
  }

  Future<ClassReportData> buildForLiveClass({required String classId}) async {
    final clazz = await _classRepository.getById(classId);
    if (clazz == null) throw StateError('Class not found');

    final students = await _studentRepository.getForClass(classId);

    final adultDef = ChecklistRegistry.definitionFor(ChecklistType.adult);
    final infantDef = ChecklistRegistry.definitionFor(ChecklistType.infantChild);

    // Completion results: single source of truth.
    final completionByStudent = <String, StudentCompletionResult>{};
    for (final s in students) {
      completionByStudent[s.id] = await _completionService.computeForStudent(clazz: clazz, student: s);
    }

    // Latest checklist attempts and item results for per-skill columns.
    final attempts = await _checklistRepository.getAttemptsForClass(classId);
    final resultsByAttempt = await _checklistRepository.getItemResultsForAttempts(attemptIds: attempts.map((e) => e.id).toList());
    final latestAttemptByStudentAndType = <String, ChecklistAttempt>{};
    for (final a in attempts) {
      final key = '${a.studentId}|${a.checklistType.name}';
      final prev = latestAttemptByStudentAndType[key];
      if (prev == null || a.updatedAt.isAfter(prev.updatedAt)) latestAttemptByStudentAndType[key] = a;
    }

    final ccfByStudent = await _ccfRepository.getLatestSessionByStudent(classId: classId);

    final adultColumns = _columnsFromDefinition(adultDef, prefix: 'A');
    final infantColumns = _columnsFromDefinition(infantDef, prefix: 'I');

    final rows = <ClassReportStudentRow>[];
    for (final s in students) {
      final comp = completionByStudent[s.id]!;
      final adultAttempt = latestAttemptByStudentAndType['${s.id}|adult'];
      final infantAttempt = latestAttemptByStudentAndType['${s.id}|infantChild'];
      final adultSkills = _skillResultsFromAttempt(adultAttempt, adultDef, resultsByAttempt);
      final infantSkills = _skillResultsFromAttempt(infantAttempt, infantDef, resultsByAttempt);
      final ccf = ccfByStudent[s.id];

      rows.add(
        ClassReportStudentRow(
          studentId: s.id,
          displayName: s.displayName,
          originalFullName: s.originalFullName,
          firstName: s.firstName,
          lastName: s.lastName,
          email: s.email,
          phone: s.phone,
          adultStatus: comp.adultStatus,
          infantChildStatus: comp.infantChildStatus,
          ccfStatus: comp.ccfStatus,
          writtenTestStatus: comp.writtenTestStatus,
          writtenScore: s.writtenTestScore,
          effectiveSkillsCheckOffDate: (s.skillsCheckOffDate ?? clazz.defaultSkillsCheckOffDate),
          effectiveIssueDate: (s.issueDate ?? clazz.defaultIssueDate),
          automaticResult: comp.overallResult,
          manualOverride: s.manualResultOverride.name,
          finalResult: _finalResultFromOverride(automatic: comp.overallResult, override: s.manualResultOverride),
          missingRequirements: List.unmodifiable(comp.missingRequirements),
          failureReasons: List.unmodifiable(comp.failureReasons),
          warnings: List.unmodifiable(comp.validationWarnings),
          adultSkillResults: adultSkills,
          infantChildSkillResults: infantSkills,
          ccfResult: _ccfReportResultFromSession(clazz: clazz, ccf: ccf, comp: comp),
          scoreResult: ScoreReportResult(
            writtenTestRequired: clazz.writtenTestRequired,
            writtenPassingScore: clazz.passingScore ?? StudentCompletionService.safeDefaultWrittenPassingScore,
            score: s.writtenTestScore,
            finalized: s.writtenTestingFinalized,
          ),
        ),
      );
    }

    rows.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    final totals = _computeTotals(clazz: clazz, rows: rows);

    return ClassReportData(
      source: ReportSource.liveClass,
      classHeader: ClassReportHeader(
        classId: clazz.id,
        className: clazz.className,
        courseType: clazz.courseType.name,
        classDate: clazz.classDate,
        startTime: clazz.startTime,
        endTime: clazz.endTime,
        location: clazz.location,
        leadInstructor: clazz.leadInstructor,
        additionalInstructor: clazz.additionalInstructor,
        trainingCenter: clazz.trainingCenter,
        trainingSite: clazz.trainingSite,
        writtenTestRequired: clazz.writtenTestRequired,
        writtenPassingScore: clazz.passingScore ?? StudentCompletionService.safeDefaultWrittenPassingScore,
        ccfRequired: clazz.ccfRequired,
        studentCount: rows.length,
        lifecycleStatus: clazz.lifecycleStatus.name,
        finalizedAt: clazz.finalizedAt,
        snapshotNumber: null,
        snapshotSchemaVersion: clazz.snapshotSchemaVersion,
      ),
      adultSkillDefinitions: adultColumns,
      infantChildSkillDefinitions: infantColumns,
      studentRows: rows,
      totals: totals,
      snapshotMetadata: null,
      warnings: const [
        'This report uses current live class data and may change as records are updated.',
      ],
    );
  }

  Future<ClassReportData> buildForFinalizedSnapshot({required String snapshotId}) async {
    final row = await (_db.select(_db.finalClassSnapshots)..where((t) => t.id.equals(snapshotId))).getSingleOrNull();
    if (row == null) throw StateError('Snapshot not found');

    final checksumValid = SnapshotRowCodec.validate(row);
    final warnings = <String>[];
    if (!checksumValid) warnings.add('Snapshot integrity warning: checksum validation failed.');
    if (row.schemaVersion != 1) warnings.add('Snapshot integrity warning: unsupported snapshot schema version ${row.schemaVersion}.');

    final source = (checksumValid && row.schemaVersion == 1) ? ReportSource.finalizedSnapshot : ReportSource.legacySnapshotWarning;

    FinalClassSnapshotV1 snapshot;
    try {
      snapshot = FinalClassSnapshotV1(
        schemaVersion: row.schemaVersion,
        completionRuleVersion: row.completionRuleVersion,
        checklistDefinitionVersion: row.checklistDefinitionVersion,
        createdAt: row.createdAt,
        finalizedAt: row.finalizedAt,
        classData: FinalSnapshotClassV1.fromJson((jsonDecode(row.classDataJson) as Map).cast<String, Object?>()),
        students: (jsonDecode(row.studentDataJson) as List)
            .cast<Map>()
            .map((e) => FinalSnapshotStudentV1.fromJson(e.cast<String, Object?>()))
            .toList(growable: false),
        totals: FinalSnapshotTotalsV1.fromJson((jsonDecode(row.totalsJson) as Map).cast<String, Object?>()),
      );
    } catch (e) {
      debugPrint('Failed to decode snapshot: $e');
      warnings.add('Snapshot could not be decoded.');
      // Create a minimal shell so UI can still show something.
      snapshot = FinalClassSnapshotV1(
        schemaVersion: row.schemaVersion,
        completionRuleVersion: row.completionRuleVersion,
        checklistDefinitionVersion: row.checklistDefinitionVersion,
        classData: FinalSnapshotClassV1(
          classId: row.classId,
          className: '(Unknown class)',
          courseType: '(Unknown)',
          classDate: null,
          startTime: null,
          endTime: null,
          location: null,
          leadInstructor: null,
          additionalInstructor: null,
          trainingCenter: null,
          trainingSite: null,
          writtenTestRequired: false,
          writtenPassingScore: null,
          ccfRequired: false,
          defaultSkillsCheckOffDate: null,
          defaultIssueDate: null,
          lifecycleStatus: 'unknown',
          snapshotNumber: row.snapshotNumber,
        ),
        students: const [],
        totals: const FinalSnapshotTotalsV1(totalStudents: 0, passedCount: 0, incompleteCount: 0, failedCount: 0, manualOverrideCount: 0),
        createdAt: row.createdAt,
        finalizedAt: row.finalizedAt,
      );
    }

    final checklistData = _decodeJson(row.checklistDataJson);
    final ccfData = _decodeJson(row.ccfDataJson);
    final scoreData = _decodeJson(row.scoreDataJson);
    final completionData = _decodeJson(row.completionResultsJson);

    final adultColumns = _columnsFromSnapshotChecklist(checklistData, checklistType: 'adult', prefix: 'A');
    final infantColumns = _columnsFromSnapshotChecklist(checklistData, checklistType: 'infantChild', prefix: 'I');

    final rows = <ClassReportStudentRow>[];
    for (final s in snapshot.students) {
      final completionSegment = (completionData is Map) ? (completionData[s.studentId] as Map?) : null;
      final automatic = completionSegment?['automatic'] as String?;
      final override = s.manualOverride;
      final finalResultStr = completionSegment?['final'] as String?;

      final adultSkillResults = _skillResultsFromSnapshot(checklistData, studentId: s.studentId, checklistType: 'adult');
      final infantSkillResults = _skillResultsFromSnapshot(checklistData, studentId: s.studentId, checklistType: 'infantChild');

      final ccfResult = _ccfResultFromSnapshot(
        clazz: snapshot.classData,
        ccfData: ccfData,
        studentId: s.studentId,
      );

      final scoreResult = _scoreResultFromSnapshot(clazz: snapshot.classData, scoreData: scoreData, studentId: s.studentId);

      rows.add(
        ClassReportStudentRow(
          studentId: s.studentId,
          displayName: s.displayName,
          originalFullName: s.originalFullName,
          firstName: s.firstName,
          lastName: s.lastName,
          email: s.email,
          phone: s.phone,
          adultStatus: _deriveChecklistStatusFromSkills(adultSkillResults),
          infantChildStatus: _deriveChecklistStatusFromSkills(infantSkillResults),
          ccfStatus: ccfResult?.status ?? RequirementStatus.notStarted,
          writtenTestStatus: _deriveWrittenStatusFromScore(scoreResult),
          writtenScore: scoreResult.score,
          effectiveSkillsCheckOffDate: _parseIso(s.effectiveSkillsCheckOffDate),
          effectiveIssueDate: _parseIso(s.effectiveIssueDate),
          automaticResult: automatic == null ? s.automaticResult : OverallStudentResult.values.byName(automatic),
          manualOverride: override,
          finalResult: finalResultStr == null ? s.finalResult : OverallStudentResult.values.byName(finalResultStr),
          missingRequirements: List.unmodifiable(s.missingRequirements),
          failureReasons: List.unmodifiable(s.failureReasons),
          warnings: List.unmodifiable({...s.warnings, ...(completionSegment?['warnings'] as List? ?? const []).cast<String>()}),
          adultSkillResults: adultSkillResults,
          infantChildSkillResults: infantSkillResults,
          ccfResult: ccfResult,
          scoreResult: scoreResult,
        ),
      );
    }

    rows.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    final writtenPassing = snapshot.classData.writtenPassingScore ?? StudentCompletionService.safeDefaultWrittenPassingScore;
    final header = ClassReportHeader(
      classId: snapshot.classData.classId,
      className: snapshot.classData.className,
      courseType: snapshot.classData.courseType,
      classDate: _parseIso(snapshot.classData.classDate),
      startTime: _parseIso(snapshot.classData.startTime),
      endTime: _parseIso(snapshot.classData.endTime),
      location: snapshot.classData.location,
      leadInstructor: snapshot.classData.leadInstructor,
      additionalInstructor: snapshot.classData.additionalInstructor,
      trainingCenter: snapshot.classData.trainingCenter,
      trainingSite: snapshot.classData.trainingSite,
      writtenTestRequired: snapshot.classData.writtenTestRequired,
      writtenPassingScore: writtenPassing,
      ccfRequired: snapshot.classData.ccfRequired,
      studentCount: rows.length,
      lifecycleStatus: snapshot.classData.lifecycleStatus,
      finalizedAt: snapshot.finalizedAt,
      snapshotNumber: snapshot.classData.snapshotNumber,
      snapshotSchemaVersion: snapshot.schemaVersion,
    );

    final totals = _computeTotalsFromSnapshot(rows: rows);

    if (source == ReportSource.finalizedSnapshot) {
      warnings.add('This report was generated from the finalized class snapshot and is read only.');
    } else {
      warnings.add('Legacy Data Preview: this snapshot failed integrity checks.');
    }

    return ClassReportData(
      source: source,
      classHeader: header,
      adultSkillDefinitions: adultColumns,
      infantChildSkillDefinitions: infantColumns,
      studentRows: rows,
      totals: totals,
      snapshotMetadata: SnapshotReportMetadata(
        snapshotId: row.id,
        snapshotNumber: row.snapshotNumber,
        snapshotSchemaVersion: row.schemaVersion,
        finalizedAt: row.finalizedAt,
        checksum: row.checksum,
        checksumValid: checksumValid,
      ),
      warnings: warnings,
    );
  }

  // --- Helpers

  List<SkillReportColumn> _columnsFromDefinition(ChecklistDefinition def, {required String prefix}) {
    final items = [...def.items]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var i = 0; i < items.length; i++)
        SkillReportColumn(
          skillId: items[i].id,
          shortLabel: '$prefix${i + 1}',
          fullTitle: items[i].title,
          order: items[i].order,
          required: items[i].required,
          imageRegistryKey: items[i].imageAssetPath,
        ),
    ];
  }

  List<SkillReportColumn> _columnsFromSnapshotChecklist(Object? checklistData, {required String checklistType, required String prefix}) {
    if (checklistData is! List) return const [];
    final match = checklistData.cast<Map>().map((e) => e.cast<String, Object?>()).where((r) => r['checklistType'] == checklistType).toList();
    if (match.isEmpty) return const [];
    // Use first row as frozen definition order (all rows share same 'items' array).
    final items = (match.first['items'] as List?)?.cast<Map>().map((e) => e.cast<String, Object?>()).toList() ?? const [];
    final sorted = [...items]..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    return [
      for (var i = 0; i < sorted.length; i++)
        SkillReportColumn(
          skillId: sorted[i]['itemId'] as String,
          shortLabel: '$prefix${i + 1}',
          fullTitle: sorted[i]['title'] as String,
          order: sorted[i]['order'] as int,
          required: sorted[i]['required'] as bool,
          imageRegistryKey: (sorted[i]['imageAssetPath'] as String?),
        ),
    ];
  }

  List<SkillReportResult> _skillResultsFromAttempt(ChecklistAttempt? attempt, ChecklistDefinition def, Map<String, List<ChecklistItemResult>> byAttempt) {
    final items = [...def.items]..sort((a, b) => a.order.compareTo(b.order));
    final results = attempt == null ? const <ChecklistItemResult>[] : (byAttempt[attempt.id] ?? const <ChecklistItemResult>[]);
    final byItem = {for (final r in results) r.itemId: r};
    return [
      for (final item in items)
        SkillReportResult(
          skillId: item.id,
          result: _skillResultValueFromChecklistItem(byItem[item.id]?.result, required: item.required),
          notes: byItem[item.id]?.notes,
          finalized: attempt?.finalized ?? false,
          imageRegistryKey: item.imageAssetPath,
        ),
    ];
  }

  List<SkillReportResult> _skillResultsFromSnapshot(Object? checklistData, {required String studentId, required String checklistType}) {
    if (checklistData is! List) return const [];
    final row = checklistData
        .cast<Map>()
        .map((e) => e.cast<String, Object?>())
        .where((r) => r['studentId'] == studentId && r['checklistType'] == checklistType)
        .toList();
    if (row.isEmpty) return const [];
    // There can be multiple attempts; pick latest by updatedAt.
    row.sort((a, b) => (a['updatedAt'] as String).compareTo(b['updatedAt'] as String));
    final latest = row.last;
    final finalized = (latest['finalized'] as bool?) ?? false;
    final items = (latest['items'] as List?)?.cast<Map>().map((e) => e.cast<String, Object?>()).toList() ?? const [];
    final sorted = [...items]..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    return [
      for (final item in sorted)
        SkillReportResult(
          skillId: item['itemId'] as String,
          result: _skillResultValueFromSnapshot(item['result'] as String?, required: item['required'] as bool),
          notes: item['notes'] as String?,
          finalized: finalized,
          imageRegistryKey: item['imageAssetPath'] as String?,
        ),
    ];
  }

  SkillResultValue _skillResultValueFromSnapshot(String? value, {required bool required}) {
    if (value == null) return required ? SkillResultValue.notEvaluated : SkillResultValue.notRequired;
    return switch (value) {
      'passed' => SkillResultValue.passed,
      'needsRemediation' => SkillResultValue.failed,
      'notEvaluated' => required ? SkillResultValue.notEvaluated : SkillResultValue.notRequired,
      _ => required ? SkillResultValue.notEvaluated : SkillResultValue.notRequired,
    };
  }

  SkillResultValue _skillResultValueFromChecklistItem(ChecklistItemResultValue? value, {required bool required}) {
    if (value == null) return required ? SkillResultValue.notEvaluated : SkillResultValue.notRequired;
    return switch (value) {
      ChecklistItemResultValue.passed => SkillResultValue.passed,
      ChecklistItemResultValue.needsRemediation => SkillResultValue.failed,
      ChecklistItemResultValue.notEvaluated => required ? SkillResultValue.notEvaluated : SkillResultValue.notRequired,
    };
  }

  OverallStudentResult _finalResultFromOverride({required OverallStudentResult automatic, required ManualStudentResultOverride override}) => switch (override) {
        ManualStudentResultOverride.none => automatic,
        ManualStudentResultOverride.pass => OverallStudentResult.pass,
        ManualStudentResultOverride.incomplete => OverallStudentResult.incomplete,
        ManualStudentResultOverride.fail => OverallStudentResult.fail,
      };

  CcfReportResult? _ccfReportResultFromSession({required ClassRecord clazz, required CcfSession? ccf, required StudentCompletionResult comp}) {
    if (!clazz.ccfRequired && ccf == null) {
      return CcfReportResult(status: RequirementStatus.notRequired, ccfPercentage: null, compressionTimeSeconds: null, pauseTimeSeconds: null);
    }
    if (ccf == null) return CcfReportResult(status: RequirementStatus.notStarted, ccfPercentage: null, compressionTimeSeconds: null, pauseTimeSeconds: null);
    return CcfReportResult(
      status: comp.ccfStatus,
      ccfPercentage: ccf.ccfPercentage,
      compressionTimeSeconds: ccf.compressionDurationMilliseconds == null ? null : (ccf.compressionDurationMilliseconds! / 1000).round(),
      pauseTimeSeconds: ccf.pauseDurationMilliseconds == null ? null : (ccf.pauseDurationMilliseconds! / 1000).round(),
    );
  }

  CcfReportResult? _ccfResultFromSnapshot({required FinalSnapshotClassV1 clazz, required Object? ccfData, required String studentId}) {
    final required = clazz.ccfRequired;
    if (ccfData is! List) {
      return required
          ? CcfReportResult(status: RequirementStatus.notStarted, ccfPercentage: null, compressionTimeSeconds: null, pauseTimeSeconds: null)
          : CcfReportResult(status: RequirementStatus.notRequired, ccfPercentage: null, compressionTimeSeconds: null, pauseTimeSeconds: null);
    }
    final rows = ccfData.cast<Map>().map((e) => e.cast<String, Object?>()).where((r) => r['studentId'] == studentId).toList();
    if (rows.isEmpty) {
      return required
          ? CcfReportResult(status: RequirementStatus.notStarted, ccfPercentage: null, compressionTimeSeconds: null, pauseTimeSeconds: null)
          : CcfReportResult(status: RequirementStatus.notRequired, ccfPercentage: null, compressionTimeSeconds: null, pauseTimeSeconds: null);
    }
    rows.sort((a, b) => (a['startedAt'] as String).compareTo(b['startedAt'] as String));
    final latest = rows.last;
    final resultStr = (latest['result'] as String?) ?? 'notStarted';
    final status = switch (resultStr) {
      'passed' => RequirementStatus.passed,
      'failed' => RequirementStatus.failed,
      'incomplete' => RequirementStatus.incomplete,
      _ => RequirementStatus.notStarted,
    };
    return CcfReportResult(
      status: required ? status : RequirementStatus.notRequired,
      ccfPercentage: (latest['ccfPercentage'] as num?)?.toDouble(),
      compressionTimeSeconds: (latest['compressionDurationMilliseconds'] as int?) == null ? null : ((latest['compressionDurationMilliseconds'] as int) / 1000).round(),
      pauseTimeSeconds: (latest['pauseDurationMilliseconds'] as int?) == null ? null : ((latest['pauseDurationMilliseconds'] as int) / 1000).round(),
    );
  }

  ScoreReportResult _scoreResultFromSnapshot({required FinalSnapshotClassV1 clazz, required Object? scoreData, required String studentId}) {
    final required = clazz.writtenTestRequired;
    final passing = clazz.writtenPassingScore ?? StudentCompletionService.safeDefaultWrittenPassingScore;
    if (scoreData is! List) {
      return ScoreReportResult(writtenTestRequired: required, writtenPassingScore: passing, score: null, finalized: false);
    }
    final row = scoreData.cast<Map>().map((e) => e.cast<String, Object?>()).firstWhere(
          (r) => r['studentId'] == studentId,
          orElse: () => const <String, Object?>{},
        );
    return ScoreReportResult(
      writtenTestRequired: required,
      writtenPassingScore: passing,
      score: row['score'] as int?,
      finalized: (row['finalized'] as bool?) ?? false,
    );
  }

  RequirementStatus _deriveWrittenStatusFromScore(ScoreReportResult score) {
    if (!score.writtenTestRequired) return RequirementStatus.notRequired;
    if (score.score == null) return RequirementStatus.notStarted;
    if (!score.finalized) return RequirementStatus.incomplete;
    return (score.score! >= score.writtenPassingScore) ? RequirementStatus.passed : RequirementStatus.failed;
  }

  ChecklistStatus _deriveChecklistStatusFromSkills(List<SkillReportResult> skills) {
    if (skills.isEmpty) return ChecklistStatus.notStarted;
    final required = skills.where((s) => s.result != SkillResultValue.notRequired).toList();
    if (required.isEmpty) return ChecklistStatus.notRequired;
    final anyEval = required.any((s) => s.result == SkillResultValue.passed || s.result == SkillResultValue.failed);
    if (!anyEval) return ChecklistStatus.notStarted;
    final anyMissing = required.any((s) => s.result == SkillResultValue.notEvaluated);
    if (anyMissing) return ChecklistStatus.incomplete;
    final anyFailed = required.any((s) => s.result == SkillResultValue.failed);
    return anyFailed ? ChecklistStatus.failed : ChecklistStatus.passed;
  }

  ReportTotals _computeTotals({required ClassRecord clazz, required List<ClassReportStudentRow> rows}) {
    final passed = rows.where((r) => r.finalResult == OverallStudentResult.pass).length;
    final incomplete = rows.where((r) => r.finalResult == OverallStudentResult.incomplete).length;
    final failed = rows.where((r) => r.finalResult == OverallStudentResult.fail).length;
    final adultComplete = rows.where((r) => r.adultStatus == ChecklistStatus.passed).length;
    final infantComplete = rows.where((r) => r.infantChildStatus == ChecklistStatus.passed).length;
    final requiredCcfComplete = rows.where((r) => clazz.ccfRequired && r.ccfStatus == RequirementStatus.passed).length;

    final finalizedScores = rows.where((r) => r.scoreResult.finalized && r.scoreResult.score != null && r.scoreResult.writtenTestRequired).map((r) => r.scoreResult.score!).toList();
    final avg = finalizedScores.isEmpty ? null : finalizedScores.reduce((a, b) => a + b) / finalizedScores.length;
    final writtenEnteredCount = rows.where((r) => r.scoreResult.score != null && r.scoreResult.writtenTestRequired).length;
    final overrideCount = rows.where((r) => r.manualOverride != ManualStudentResultOverride.none.name).length;

    return ReportTotals(
      totalStudents: rows.length,
      passedCount: passed,
      incompleteCount: incomplete,
      failedCount: failed,
      adultCompleteCount: adultComplete,
      infantCompleteCount: infantComplete,
      requiredCcfCompleteCount: requiredCcfComplete,
      writtenScoresEnteredCount: writtenEnteredCount,
      averageFinalizedWrittenScore: avg,
      averageFinalizedWrittenScoreCount: finalizedScores.length,
      manualOverrideCount: overrideCount,
    );
  }

  ReportTotals _computeTotalsFromSnapshot({required List<ClassReportStudentRow> rows}) {
    final passed = rows.where((r) => r.finalResult == OverallStudentResult.pass).length;
    final incomplete = rows.where((r) => r.finalResult == OverallStudentResult.incomplete).length;
    final failed = rows.where((r) => r.finalResult == OverallStudentResult.fail).length;
    final adultComplete = rows.where((r) => r.adultStatus == ChecklistStatus.passed).length;
    final infantComplete = rows.where((r) => r.infantChildStatus == ChecklistStatus.passed).length;
    final requiredCcfComplete = rows.where((r) => r.ccfStatus == RequirementStatus.passed).length;

    final finalizedScores = rows.where((r) => r.scoreResult.finalized && r.scoreResult.score != null && r.scoreResult.writtenTestRequired).map((r) => r.scoreResult.score!).toList();
    final avg = finalizedScores.isEmpty ? null : finalizedScores.reduce((a, b) => a + b) / finalizedScores.length;
    final writtenEnteredCount = rows.where((r) => r.scoreResult.score != null && r.scoreResult.writtenTestRequired).length;
    final overrideCount = rows.where((r) => r.manualOverride != ManualStudentResultOverride.none.name).length;

    return ReportTotals(
      totalStudents: rows.length,
      passedCount: passed,
      incompleteCount: incomplete,
      failedCount: failed,
      adultCompleteCount: adultComplete,
      infantCompleteCount: infantComplete,
      requiredCcfCompleteCount: requiredCcfComplete,
      writtenScoresEnteredCount: writtenEnteredCount,
      averageFinalizedWrittenScore: avg,
      averageFinalizedWrittenScoreCount: finalizedScores.length,
      manualOverrideCount: overrideCount,
    );
  }

  Object? _decodeJson(String jsonStr) {
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      debugPrint('Failed to decode JSON segment: $e');
      return null;
    }
  }

  DateTime? _parseIso(String? iso) => (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso);
}
