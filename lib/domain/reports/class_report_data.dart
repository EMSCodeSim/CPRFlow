import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';

class ClassReportData {
  const ClassReportData({
    required this.source,
    required this.classHeader,
    required this.adultSkillDefinitions,
    required this.infantChildSkillDefinitions,
    required this.studentRows,
    required this.totals,
    required this.snapshotMetadata,
    required this.warnings,
  });

  final ReportSource source;
  final ClassReportHeader classHeader;
  final List<SkillReportColumn> adultSkillDefinitions;
  final List<SkillReportColumn> infantChildSkillDefinitions;
  final List<ClassReportStudentRow> studentRows;
  final ReportTotals totals;

  /// Null for live classes.
  final SnapshotReportMetadata? snapshotMetadata;

  /// Human-readable warnings to display in UI/PDF headers.
  final List<String> warnings;
}

class SnapshotReportMetadata {
  const SnapshotReportMetadata({
    required this.snapshotId,
    required this.snapshotNumber,
    required this.snapshotSchemaVersion,
    required this.finalizedAt,
    required this.checksum,
    required this.checksumValid,
  });

  final String snapshotId;
  final int snapshotNumber;
  final int snapshotSchemaVersion;
  final DateTime finalizedAt;
  final String checksum;
  final bool checksumValid;
}

class ClassReportHeader {
  const ClassReportHeader({
    required this.classId,
    required this.className,
    required this.courseType,
    required this.classDate,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.leadInstructor,
    required this.additionalInstructor,
    required this.trainingCenter,
    required this.trainingSite,
    required this.writtenTestRequired,
    required this.writtenPassingScore,
    required this.ccfRequired,
    required this.studentCount,
    required this.lifecycleStatus,
    required this.finalizedAt,
    required this.snapshotNumber,
    required this.snapshotSchemaVersion,
  });

  final String classId;
  final String className;
  final String courseType;
  final DateTime? classDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? location;
  final String? leadInstructor;
  final String? additionalInstructor;
  final String? trainingCenter;
  final String? trainingSite;
  final bool writtenTestRequired;
  final int writtenPassingScore;
  final bool ccfRequired;
  final int studentCount;
  final String lifecycleStatus;
  final DateTime? finalizedAt;
  final int? snapshotNumber;
  final int? snapshotSchemaVersion;
}

class ClassReportStudentRow {
  const ClassReportStudentRow({
    required this.studentId,
    required this.displayName,
    required this.originalFullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.adultStatus,
    required this.infantChildStatus,
    required this.ccfStatus,
    required this.writtenTestStatus,
    required this.writtenScore,
    required this.effectiveSkillsCheckOffDate,
    required this.effectiveIssueDate,
    required this.automaticResult,
    required this.manualOverride,
    required this.finalResult,
    required this.missingRequirements,
    required this.failureReasons,
    required this.warnings,
    required this.adultSkillResults,
    required this.infantChildSkillResults,
    required this.ccfResult,
    required this.scoreResult,
  });

  final String studentId;
  final String displayName;
  final String? originalFullName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;

  final ChecklistStatus adultStatus;
  final ChecklistStatus infantChildStatus;
  final RequirementStatus ccfStatus;
  final RequirementStatus writtenTestStatus;
  final int? writtenScore;

  final DateTime? effectiveSkillsCheckOffDate;
  final DateTime? effectiveIssueDate;

  final OverallStudentResult automaticResult;
  final String manualOverride;
  final OverallStudentResult finalResult;
  final List<String> missingRequirements;
  final List<String> failureReasons;
  final List<String> warnings;

  final List<SkillReportResult> adultSkillResults;
  final List<SkillReportResult> infantChildSkillResults;
  final CcfReportResult? ccfResult;
  final ScoreReportResult scoreResult;
}

class SkillReportColumn {
  const SkillReportColumn({
    required this.skillId,
    required this.shortLabel,
    required this.fullTitle,
    required this.order,
    required this.required,
    required this.imageRegistryKey,
  });

  final String skillId;
  final String shortLabel;
  final String fullTitle;
  final int order;
  final bool required;
  final String? imageRegistryKey;
}

enum SkillResultValue {
  passed,
  failed,
  notEvaluated,
  notRequired,
}

class SkillReportResult {
  const SkillReportResult({
    required this.skillId,
    required this.result,
    required this.notes,
    required this.finalized,
    required this.imageRegistryKey,
  });

  final String skillId;
  final SkillResultValue result;
  final String? notes;
  final bool finalized;
  final String? imageRegistryKey;
}

class CcfReportResult {
  const CcfReportResult({
    required this.status,
    required this.ccfPercentage,
    required this.compressionTimeSeconds,
    required this.pauseTimeSeconds,
  });

  final RequirementStatus status;
  final double? ccfPercentage;
  final int? compressionTimeSeconds;
  final int? pauseTimeSeconds;
}

class ScoreReportResult {
  const ScoreReportResult({
    required this.writtenTestRequired,
    required this.writtenPassingScore,
    required this.score,
    required this.finalized,
  });

  final bool writtenTestRequired;
  final int writtenPassingScore;
  final int? score;
  final bool finalized;
}

class ReportTotals {
  const ReportTotals({
    required this.totalStudents,
    required this.passedCount,
    required this.incompleteCount,
    required this.failedCount,
    required this.adultCompleteCount,
    required this.infantCompleteCount,
    required this.requiredCcfCompleteCount,
    required this.writtenScoresEnteredCount,
    required this.averageFinalizedWrittenScore,
    required this.averageFinalizedWrittenScoreCount,
    required this.manualOverrideCount,
  });

  final int totalStudents;
  final int passedCount;
  final int incompleteCount;
  final int failedCount;
  final int adultCompleteCount;
  final int infantCompleteCount;
  final int requiredCcfCompleteCount;
  final int writtenScoresEnteredCount;
  final double? averageFinalizedWrittenScore;
  final int averageFinalizedWrittenScoreCount;
  final int manualOverrideCount;
}
