import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';

class StudentCompletionResult {
  const StudentCompletionResult({
    required this.adultStatus,
    required this.infantChildStatus,
    required this.ccfStatus,
    required this.writtenTestStatus,
    required this.overallResult,
    required this.missingRequirements,
    required this.failureReasons,
    required this.completionPercentage,
    this.validationWarnings = const [],
  });

  final ChecklistStatus adultStatus;
  final ChecklistStatus infantChildStatus;
  final RequirementStatus ccfStatus;
  final RequirementStatus writtenTestStatus;
  final OverallStudentResult overallResult;

  final List<String> missingRequirements;
  final List<String> failureReasons;

  /// 0–100.
  final int completionPercentage;

  /// Non-fatal data issues that can affect correctness.
  ///
  /// Example: A migrated class record where `writtenTestRequired` is true but
  /// `passingScore` is missing. We apply a safe fallback but still surface a
  /// warning.
  final List<String> validationWarnings;

  bool get isAdultComplete => adultStatus == ChecklistStatus.passed;
  bool get isInfantChildComplete => infantChildStatus == ChecklistStatus.passed;
  bool get isCcfComplete => ccfStatus == RequirementStatus.passed || ccfStatus == RequirementStatus.notRequired;
  bool get isWrittenTestComplete => writtenTestStatus == RequirementStatus.passed || writtenTestStatus == RequirementStatus.notRequired;
}
