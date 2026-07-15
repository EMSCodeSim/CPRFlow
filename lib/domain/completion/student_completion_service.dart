import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';

/// Centralized completion logic for Phase 2.
///
/// Widgets must not compute pass/fail/incomplete themselves.
class StudentCompletionService {
  StudentCompletionService.unwired();

  late ChecklistRepository _checklistRepository;
  late CcfRepository _ccfRepository;
  bool _wired = false;

  void wire({
    required ChecklistRepository checklistRepository,
    required CcfRepository ccfRepository,
  }) {
    _checklistRepository = checklistRepository;
    _ccfRepository = ccfRepository;
    _wired = true;
  }

  void _ensureWired() {
    if (!_wired) throw StateError('StudentCompletionService is not wired');
  }

  Future<StudentCompletionResult> computeForStudent({required ClassRecord clazz, required StudentRecord student}) async {
    _ensureWired();

    final missing = <String>[];
    final failures = <String>[];

    final adult = await _computeChecklistStatus(studentId: student.id, type: ChecklistType.adult);
    final infant = await _computeChecklistStatus(studentId: student.id, type: ChecklistType.infantChild);

    if (adult == ChecklistStatus.notStarted || adult == ChecklistStatus.incomplete) missing.add('Adult checklist');
    if (infant == ChecklistStatus.notStarted || infant == ChecklistStatus.incomplete) missing.add('Infant/Child checklist');
    if (adult == ChecklistStatus.failed) failures.add('Adult checklist failed');
    if (infant == ChecklistStatus.failed) failures.add('Infant/Child checklist failed');

    final ccf = await _computeCcfStatus(clazz: clazz, student: student);
    final written = _computeWrittenStatus(clazz: clazz, student: student);

    if (clazz.ccfRequired && (ccf == RequirementStatus.notStarted || ccf == RequirementStatus.incomplete)) missing.add('CCF session');
    if (clazz.ccfRequired && ccf == RequirementStatus.failed) failures.add('CCF below threshold');

    if (clazz.writtenTestRequired && (written == RequirementStatus.notStarted || written == RequirementStatus.incomplete)) missing.add('Written score');
    if (clazz.writtenTestRequired && written == RequirementStatus.failed) failures.add('Written score below passing');

    final overall = _computeOverallResult(adult: adult, infant: infant, ccf: ccf, written: written);
    final completionPct = _computeCompletionPercentage(clazz: clazz, adult: adult, infant: infant, ccf: ccf, written: written);

    return StudentCompletionResult(
      adultStatus: adult,
      infantChildStatus: infant,
      ccfStatus: ccf,
      writtenTestStatus: written,
      overallResult: overall,
      missingRequirements: missing,
      failureReasons: failures,
      completionPercentage: completionPct,
    );
  }

  Future<ChecklistStatus> _computeChecklistStatus({required String studentId, required ChecklistType type}) async {
    final def = ChecklistRegistry.definitionFor(type);
    final latest = await _checklistRepository.getCurrentOrLatestFinalizedAttempt(studentId: studentId, checklistType: type);
    if (latest == null) return ChecklistStatus.notStarted;
    if (!latest.finalized) {
      final missing = await _checklistRepository.findFirstMissingRequiredItem(attemptId: latest.id, definition: def);
      return missing == null ? ChecklistStatus.incomplete : ChecklistStatus.incomplete;
    }

    final results = await _checklistRepository.getItemResults(latest.id);
    final requiredIds = def.items.where((i) => i.required).map((i) => i.id).toSet();
    final byItem = {for (final r in results) r.itemId: r};
    for (final item in def.items.where((i) => i.required)) {
      final r = byItem[item.id];
      if (r == null || r.result == ChecklistItemResultValue.notEvaluated) return ChecklistStatus.incomplete;
      if (r.result == ChecklistItemResultValue.needsRemediation) return ChecklistStatus.failed;
    }
    // If any non-required items need remediation, we ignore for pass/fail.
    if (results.any((r) => requiredIds.contains(r.itemId) && r.result == ChecklistItemResultValue.needsRemediation)) return ChecklistStatus.failed;
    return ChecklistStatus.passed;
  }

  Future<RequirementStatus> _computeCcfStatus({required ClassRecord clazz, required StudentRecord student}) async {
    if (!clazz.ccfRequired) {
      final latestFinal = await _ccfRepository.getLatestFinalizedStudentSession(student.id);
      if (latestFinal == null) return RequirementStatus.notRequired;
      return latestFinal.result == CcfResultValue.passed ? RequirementStatus.passed : RequirementStatus.failed;
    }

    final latest = await _ccfRepository.getLatestStudentSession(student.id);
    if (latest == null) return RequirementStatus.incomplete;
    if (!latest.finalized) return RequirementStatus.incomplete;
    return latest.result == CcfResultValue.passed ? RequirementStatus.passed : RequirementStatus.failed;
  }

  RequirementStatus _computeWrittenStatus({required ClassRecord clazz, required StudentRecord student}) {
    if (!clazz.writtenTestRequired) return RequirementStatus.notRequired;
    final score = student.writtenTestScore;
    if (score == null) return RequirementStatus.incomplete;
    if (!student.writtenTestingFinalized) return RequirementStatus.incomplete;
    final threshold = clazz.passingScore ?? 0;
    return score >= threshold ? RequirementStatus.passed : RequirementStatus.failed;
  }

  OverallStudentResult _computeOverallResult({
    required ChecklistStatus adult,
    required ChecklistStatus infant,
    required RequirementStatus ccf,
    required RequirementStatus written,
  }) {
    final anyFail = adult == ChecklistStatus.failed || infant == ChecklistStatus.failed || ccf == RequirementStatus.failed || written == RequirementStatus.failed;
    if (anyFail) return OverallStudentResult.fail;

    final anyIncomplete = adult != ChecklistStatus.passed || infant != ChecklistStatus.passed ||
        !(ccf == RequirementStatus.passed || ccf == RequirementStatus.notRequired) ||
        !(written == RequirementStatus.passed || written == RequirementStatus.notRequired);
    if (anyIncomplete) return OverallStudentResult.incomplete;
    return OverallStudentResult.pass;
  }

  int _computeCompletionPercentage({
    required ClassRecord clazz,
    required ChecklistStatus adult,
    required ChecklistStatus infant,
    required RequirementStatus ccf,
    required RequirementStatus written,
  }) {
    var total = 2; // adult + infant
    var done = (adult == ChecklistStatus.passed ? 1 : 0) + (infant == ChecklistStatus.passed ? 1 : 0);

    if (clazz.ccfRequired) {
      total += 1;
      if (ccf == RequirementStatus.passed) done += 1;
    }
    if (clazz.writtenTestRequired) {
      total += 1;
      if (written == RequirementStatus.passed) done += 1;
    }

    return ((done / total) * 100).round();
  }
}
