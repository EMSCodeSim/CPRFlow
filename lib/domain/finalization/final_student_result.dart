import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';

/// Phase 3: Automatic result + instructor override + final result.
///
/// The underlying completion rules remain exclusively owned by
/// [StudentCompletionService]. Phase 3 adds only a typed overlay.
class FinalStudentResult {
  const FinalStudentResult({
    required this.automatic,
    required this.overrideType,
    required this.finalResult,
    required this.overrideReason,
    required this.overrideChangedAt,
    required this.instructorInitials,
    required this.missingRequirements,
    required this.failureReasons,
    required this.warnings,
  });

  final StudentCompletionResult automatic;

  /// Stored on the student record.
  final ManualStudentResultOverride overrideType;

  /// Final effective result used for finalization totals.
  final OverallStudentResult finalResult;

  final String? overrideReason;
  final DateTime? overrideChangedAt;
  final String? instructorInitials;

  /// Carried from [automatic]. We never erase automatic findings.
  final List<String> missingRequirements;
  final List<String> failureReasons;
  final List<String> warnings;

  static FinalStudentResult fromAutomaticAndStudent({
    required StudentCompletionResult automatic,
    required StudentRecord student,
  }) {
    final overrideType = student.manualResultOverride;
    final finalResult = switch (overrideType) {
      ManualStudentResultOverride.none => automatic.overallResult,
      ManualStudentResultOverride.pass => OverallStudentResult.pass,
      ManualStudentResultOverride.incomplete => OverallStudentResult.incomplete,
      ManualStudentResultOverride.fail => OverallStudentResult.fail,
    };

    return FinalStudentResult(
      automatic: automatic,
      overrideType: overrideType,
      finalResult: finalResult,
      overrideReason: student.manualResultReason,
      overrideChangedAt: student.manualResultChangedAt,
      instructorInitials: student.manualResultInstructorInitials,
      missingRequirements: List.unmodifiable(automatic.missingRequirements),
      failureReasons: List.unmodifiable(automatic.failureReasons),
      warnings: List.unmodifiable(automatic.validationWarnings),
    );
  }
}
