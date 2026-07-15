import 'dart:convert';

import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';

/// Phase 3 snapshot schema.
///
/// IMPORTANT: These models are immutable and versioned.
/// Live tables remain normalized; JSON is used only inside the snapshot record.

class FinalClassSnapshotV1 {
  const FinalClassSnapshotV1({
    required this.schemaVersion,
    required this.completionRuleVersion,
    required this.checklistDefinitionVersion,
    required this.classData,
    required this.students,
    required this.totals,
    required this.createdAt,
    required this.finalizedAt,
  });

  final int schemaVersion;
  final int completionRuleVersion;
  final int checklistDefinitionVersion;
  final FinalSnapshotClassV1 classData;
  final List<FinalSnapshotStudentV1> students;
  final FinalSnapshotTotalsV1 totals;
  final DateTime createdAt;
  final DateTime finalizedAt;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'completionRuleVersion': completionRuleVersion,
        'checklistDefinitionVersion': checklistDefinitionVersion,
        'createdAt': createdAt.toIso8601String(),
        'finalizedAt': finalizedAt.toIso8601String(),
        'class': classData.toJson(),
        'students': students.map((s) => s.toJson()).toList(growable: false),
        'totals': totals.toJson(),
      };

  /// Canonical JSON string used for checksum generation.
  ///
  /// We explicitly control field ordering by constructing Maps in a stable
  /// order and ensuring student sorting is stable.
  String canonicalJson() {
    final sortedStudents = [...students]..sort((a, b) => a.studentId.compareTo(b.studentId));
    final canonical = {
      'schemaVersion': schemaVersion,
      'completionRuleVersion': completionRuleVersion,
      'checklistDefinitionVersion': checklistDefinitionVersion,
      'createdAt': createdAt.toIso8601String(),
      'finalizedAt': finalizedAt.toIso8601String(),
      'class': classData.toCanonicalJsonMap(),
      'students': sortedStudents.map((s) => s.toCanonicalJsonMap()).toList(growable: false),
      'totals': totals.toCanonicalJsonMap(),
    };
    return jsonEncode(canonical);
  }

  static FinalClassSnapshotV1 fromJson(Map<String, Object?> json) {
    final studentsJson = (json['students'] as List).cast<Map>().map((e) => e.cast<String, Object?>()).toList();
    return FinalClassSnapshotV1(
      schemaVersion: json['schemaVersion'] as int,
      completionRuleVersion: json['completionRuleVersion'] as int,
      checklistDefinitionVersion: json['checklistDefinitionVersion'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      finalizedAt: DateTime.parse(json['finalizedAt'] as String),
      classData: FinalSnapshotClassV1.fromJson((json['class'] as Map).cast<String, Object?>()),
      students: studentsJson.map(FinalSnapshotStudentV1.fromJson).toList(growable: false),
      totals: FinalSnapshotTotalsV1.fromJson((json['totals'] as Map).cast<String, Object?>()),
    );
  }
}

class FinalSnapshotClassV1 {
  const FinalSnapshotClassV1({
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
    required this.defaultSkillsCheckOffDate,
    required this.defaultIssueDate,
    required this.lifecycleStatus,
    required this.snapshotNumber,
  });

  final String classId;
  final String className;
  final String courseType;
  final String? classDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? leadInstructor;
  final String? additionalInstructor;
  final String? trainingCenter;
  final String? trainingSite;
  final bool writtenTestRequired;
  final int? writtenPassingScore;
  final bool ccfRequired;
  final String? defaultSkillsCheckOffDate;
  final String? defaultIssueDate;
  final String lifecycleStatus;
  final int snapshotNumber;

  Map<String, Object?> toJson() => {
        'classId': classId,
        'className': className,
        'courseType': courseType,
        'classDate': classDate,
        'startTime': startTime,
        'endTime': endTime,
        'location': location,
        'leadInstructor': leadInstructor,
        'additionalInstructor': additionalInstructor,
        'trainingCenter': trainingCenter,
        'trainingSite': trainingSite,
        'writtenTestRequired': writtenTestRequired,
        'writtenPassingScore': writtenPassingScore,
        'ccfRequired': ccfRequired,
        'defaultSkillsCheckOffDate': defaultSkillsCheckOffDate,
        'defaultIssueDate': defaultIssueDate,
        'lifecycleStatus': lifecycleStatus,
        'snapshotNumber': snapshotNumber,
      };

  Map<String, Object?> toCanonicalJsonMap() => {
        'classId': classId,
        'className': className,
        'courseType': courseType,
        'classDate': classDate,
        'startTime': startTime,
        'endTime': endTime,
        'location': location,
        'leadInstructor': leadInstructor,
        'additionalInstructor': additionalInstructor,
        'trainingCenter': trainingCenter,
        'trainingSite': trainingSite,
        'writtenTestRequired': writtenTestRequired,
        'writtenPassingScore': writtenPassingScore,
        'ccfRequired': ccfRequired,
        'defaultSkillsCheckOffDate': defaultSkillsCheckOffDate,
        'defaultIssueDate': defaultIssueDate,
        'lifecycleStatus': lifecycleStatus,
        'snapshotNumber': snapshotNumber,
      };

  static FinalSnapshotClassV1 fromJson(Map<String, Object?> json) => FinalSnapshotClassV1(
        classId: json['classId'] as String,
        className: json['className'] as String,
        courseType: json['courseType'] as String,
        classDate: json['classDate'] as String?,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        location: json['location'] as String?,
        leadInstructor: json['leadInstructor'] as String?,
        additionalInstructor: json['additionalInstructor'] as String?,
        trainingCenter: json['trainingCenter'] as String?,
        trainingSite: json['trainingSite'] as String?,
        writtenTestRequired: json['writtenTestRequired'] as bool,
        writtenPassingScore: json['writtenPassingScore'] as int?,
        ccfRequired: json['ccfRequired'] as bool,
        defaultSkillsCheckOffDate: json['defaultSkillsCheckOffDate'] as String?,
        defaultIssueDate: json['defaultIssueDate'] as String?,
        lifecycleStatus: json['lifecycleStatus'] as String,
        snapshotNumber: json['snapshotNumber'] as int,
      );
}

class FinalSnapshotStudentV1 {
  const FinalSnapshotStudentV1({
    required this.studentId,
    required this.displayName,
    required this.originalFullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.nameNeedsReview,
    required this.writtenScore,
    required this.writtenFinalized,
    required this.effectiveSkillsCheckOffDate,
    required this.effectiveIssueDate,
    required this.automaticResult,
    required this.manualOverride,
    required this.manualOverrideReason,
    required this.finalResult,
    required this.missingRequirements,
    required this.failureReasons,
    required this.warnings,
  });

  final String studentId;
  final String displayName;
  final String? originalFullName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final bool nameNeedsReview;
  final int? writtenScore;
  final bool writtenFinalized;
  final String? effectiveSkillsCheckOffDate;
  final String? effectiveIssueDate;
  final OverallStudentResult automaticResult;
  final String manualOverride;
  final String? manualOverrideReason;
  final OverallStudentResult finalResult;
  final List<String> missingRequirements;
  final List<String> failureReasons;
  final List<String> warnings;

  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'displayName': displayName,
        'originalFullName': originalFullName,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'nameNeedsReview': nameNeedsReview,
        'writtenScore': writtenScore,
        'writtenFinalized': writtenFinalized,
        'effectiveSkillsCheckOffDate': effectiveSkillsCheckOffDate,
        'effectiveIssueDate': effectiveIssueDate,
        'automaticResult': automaticResult.name,
        'manualOverride': manualOverride,
        'manualOverrideReason': manualOverrideReason,
        'finalResult': finalResult.name,
        'missingRequirements': missingRequirements,
        'failureReasons': failureReasons,
        'warnings': warnings,
      };

  Map<String, Object?> toCanonicalJsonMap() => {
        'studentId': studentId,
        'displayName': displayName,
        'originalFullName': originalFullName,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'nameNeedsReview': nameNeedsReview,
        'writtenScore': writtenScore,
        'writtenFinalized': writtenFinalized,
        'effectiveSkillsCheckOffDate': effectiveSkillsCheckOffDate,
        'effectiveIssueDate': effectiveIssueDate,
        'automaticResult': automaticResult.name,
        'manualOverride': manualOverride,
        'manualOverrideReason': manualOverrideReason,
        'finalResult': finalResult.name,
        'missingRequirements': [...missingRequirements]..sort(),
        'failureReasons': [...failureReasons]..sort(),
        'warnings': [...warnings]..sort(),
      };

  static FinalSnapshotStudentV1 fromJson(Map<String, Object?> json) => FinalSnapshotStudentV1(
        studentId: json['studentId'] as String,
        displayName: json['displayName'] as String,
        originalFullName: json['originalFullName'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        nameNeedsReview: json['nameNeedsReview'] as bool,
        writtenScore: json['writtenScore'] as int?,
        writtenFinalized: json['writtenFinalized'] as bool,
        effectiveSkillsCheckOffDate: json['effectiveSkillsCheckOffDate'] as String?,
        effectiveIssueDate: json['effectiveIssueDate'] as String?,
        automaticResult: OverallStudentResult.values.byName(json['automaticResult'] as String),
        manualOverride: json['manualOverride'] as String,
        manualOverrideReason: json['manualOverrideReason'] as String?,
        finalResult: OverallStudentResult.values.byName(json['finalResult'] as String),
        missingRequirements: (json['missingRequirements'] as List).cast<String>(),
        failureReasons: (json['failureReasons'] as List).cast<String>(),
        warnings: (json['warnings'] as List).cast<String>(),
      );
}

class FinalSnapshotTotalsV1 {
  const FinalSnapshotTotalsV1({
    required this.totalStudents,
    required this.passedCount,
    required this.incompleteCount,
    required this.failedCount,
    required this.manualOverrideCount,
  });

  final int totalStudents;
  final int passedCount;
  final int incompleteCount;
  final int failedCount;
  final int manualOverrideCount;

  Map<String, Object?> toJson() => {
        'totalStudents': totalStudents,
        'passedCount': passedCount,
        'incompleteCount': incompleteCount,
        'failedCount': failedCount,
        'manualOverrideCount': manualOverrideCount,
      };

  Map<String, Object?> toCanonicalJsonMap() => {
        'totalStudents': totalStudents,
        'passedCount': passedCount,
        'incompleteCount': incompleteCount,
        'failedCount': failedCount,
        'manualOverrideCount': manualOverrideCount,
      };

  static FinalSnapshotTotalsV1 fromJson(Map<String, Object?> json) => FinalSnapshotTotalsV1(
        totalStudents: json['totalStudents'] as int,
        passedCount: json['passedCount'] as int,
        incompleteCount: json['incompleteCount'] as int,
        failedCount: json['failedCount'] as int,
        manualOverrideCount: json['manualOverrideCount'] as int,
      );
}
