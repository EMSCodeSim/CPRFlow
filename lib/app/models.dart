import 'package:flutter/foundation.dart';

enum CourseType {
  blsProvider,
  heartsaverCprAed,
  heartsaverFirstAidCprAed,
  skillsSession,
  custom,
}

extension CourseTypeUi on CourseType {
  String get label => switch (this) {
        CourseType.blsProvider => 'BLS Provider',
        CourseType.heartsaverCprAed => 'Heartsaver CPR AED',
        CourseType.heartsaverFirstAidCprAed => 'Heartsaver First Aid CPR AED',
        CourseType.skillsSession => 'Skills Session',
        CourseType.custom => 'Custom',
      };
}

enum RequiredComponent {
  adultChecklist,
  infantChecklist,
  ccfEvaluation,
  writtenTest,
}

extension RequiredComponentUi on RequiredComponent {
  String get label => switch (this) {
        RequiredComponent.adultChecklist => 'Adult checklist',
        RequiredComponent.infantChecklist => 'Infant checklist',
        RequiredComponent.ccfEvaluation => 'CCF evaluation',
        RequiredComponent.writtenTest => 'Written test',
      };
}

enum CompletionStatus {
  notStarted,
  inProgress,
  complete,
  needsReview,
}

extension CompletionStatusUi on CompletionStatus {
  String get label => switch (this) {
        CompletionStatus.notStarted => 'Not Started',
        CompletionStatus.inProgress => 'In Progress',
        CompletionStatus.complete => 'Complete',
        CompletionStatus.needsReview => 'Needs Review',
      };
}

enum ChecklistRating {
  notEvaluated,
  meetsCriteria,
  needsImprovement,
  notApplicable,
}

extension ChecklistRatingUi on ChecklistRating {
  String get label => switch (this) {
        ChecklistRating.notEvaluated => 'Not Evaluated',
        ChecklistRating.meetsCriteria => 'Meets Criteria',
        ChecklistRating.needsImprovement => 'Needs Improvement',
        ChecklistRating.notApplicable => 'Not Applicable',
      };
}

enum ChecklistDecision {
  notDecided,
  pass,
  needsReview,
}

extension ChecklistDecisionUi on ChecklistDecision {
  String get label => switch (this) {
        ChecklistDecision.notDecided => 'Not decided',
        ChecklistDecision.pass => 'Pass',
        ChecklistDecision.needsReview => 'Needs Remediation',
      };
}

@immutable
class CourseClass {
  const CourseClass({
    required this.id,
    required this.className,
    required this.courseType,
    required this.classDate,
    required this.trainingCenter,
    required this.location,
    required this.primaryInstructor,
    required this.additionalInstructor,
    required this.notes,
    required this.skillsSessionRequired,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String className;
  final CourseType courseType;
  final DateTime classDate;
  final String trainingCenter;
  final String location;
  final String primaryInstructor;
  final String additionalInstructor;
  final String notes;

  /// Only used for Skills Session and Custom.
  final Set<RequiredComponent> skillsSessionRequired;

  final DateTime createdAt;
  final DateTime updatedAt;

  CourseClass copyWith({
    String? className,
    CourseType? courseType,
    DateTime? classDate,
    String? trainingCenter,
    String? location,
    String? primaryInstructor,
    String? additionalInstructor,
    String? notes,
    Set<RequiredComponent>? skillsSessionRequired,
    DateTime? updatedAt,
  }) =>
      CourseClass(
        id: id,
        className: className ?? this.className,
        courseType: courseType ?? this.courseType,
        classDate: classDate ?? this.classDate,
        trainingCenter: trainingCenter ?? this.trainingCenter,
        location: location ?? this.location,
        primaryInstructor: primaryInstructor ?? this.primaryInstructor,
        additionalInstructor: additionalInstructor ?? this.additionalInstructor,
        notes: notes ?? this.notes,
        skillsSessionRequired: skillsSessionRequired ?? this.skillsSessionRequired,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class ChecklistAttempt {
  const ChecklistAttempt({
    required this.ratings,
    required this.reviewed,
    required this.decision,
    required this.instructorNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChecklistAttempt.empty({required DateTime now}) => ChecklistAttempt(
        ratings: const {},
        reviewed: false,
        decision: ChecklistDecision.notDecided,
        instructorNotes: '',
        createdAt: now,
        updatedAt: now,
      );

  final Map<String, ChecklistRating> ratings;
  final bool reviewed;
  final ChecklistDecision decision;
  final String instructorNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChecklistAttempt copyWith({
    Map<String, ChecklistRating>? ratings,
    bool? reviewed,
    ChecklistDecision? decision,
    String? instructorNotes,
    DateTime? updatedAt,
  }) =>
      ChecklistAttempt(
        ratings: ratings ?? this.ratings,
        reviewed: reviewed ?? this.reviewed,
        decision: decision ?? this.decision,
        instructorNotes: instructorNotes ?? this.instructorNotes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class CcfEvaluation {
  const CcfEvaluation({
    required this.compressionFractionPercent,
    required this.compressionRate,
    required this.compressionQuality,
    required this.ventilationQuality,
    required this.pausesMinimized,
    required this.instructorComments,
    required this.decision,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CcfEvaluation.empty({required DateTime now}) => CcfEvaluation(
        compressionFractionPercent: null,
        compressionRate: null,
        compressionQuality: '',
        ventilationQuality: '',
        pausesMinimized: false,
        instructorComments: '',
        decision: ChecklistDecision.notDecided,
        createdAt: now,
        updatedAt: now,
      );

  final int? compressionFractionPercent;
  final int? compressionRate;
  final String compressionQuality;
  final String ventilationQuality;
  final bool pausesMinimized;
  final String instructorComments;
  final ChecklistDecision decision;
  final DateTime createdAt;
  final DateTime updatedAt;

  CcfEvaluation copyWith({
    int? compressionFractionPercent,
    int? compressionRate,
    String? compressionQuality,
    String? ventilationQuality,
    bool? pausesMinimized,
    String? instructorComments,
    ChecklistDecision? decision,
    DateTime? updatedAt,
  }) =>
      CcfEvaluation(
        compressionFractionPercent: compressionFractionPercent ?? this.compressionFractionPercent,
        compressionRate: compressionRate ?? this.compressionRate,
        compressionQuality: compressionQuality ?? this.compressionQuality,
        ventilationQuality: ventilationQuality ?? this.ventilationQuality,
        pausesMinimized: pausesMinimized ?? this.pausesMinimized,
        instructorComments: instructorComments ?? this.instructorComments,
        decision: decision ?? this.decision,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class TestScore {
  const TestScore({
    required this.scorePercent,
    required this.passingThresholdPercent,
    required this.decision,
    required this.instructorNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestScore.empty({required DateTime now}) => TestScore(
        scorePercent: null,
        passingThresholdPercent: 84,
        decision: ChecklistDecision.notDecided,
        instructorNotes: '',
        createdAt: now,
        updatedAt: now,
      );

  final int? scorePercent;
  final int passingThresholdPercent;
  final ChecklistDecision decision;
  final String instructorNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get meetsThreshold {
    final s = scorePercent;
    if (s == null) return false;
    return s >= passingThresholdPercent;
  }

  bool get isPass => decision == ChecklistDecision.pass;

  TestScore copyWith({
    int? scorePercent,
    int? passingThresholdPercent,
    ChecklistDecision? decision,
    String? instructorNotes,
    DateTime? updatedAt,
  }) =>
      TestScore(
        scorePercent: scorePercent ?? this.scorePercent,
        passingThresholdPercent: passingThresholdPercent ?? this.passingThresholdPercent,
        decision: decision ?? this.decision,
        instructorNotes: instructorNotes ?? this.instructorNotes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class ArchivedStudentSnapshot {
  const ArchivedStudentSnapshot({
    required this.studentId,
    required this.fullName,
    required this.adultChecklistStatus,
    required this.infantChecklistStatus,
    required this.ccfStatus,
    required this.writtenTestStatus,
    required this.overallStatus,
  });

  final String studentId;
  final String fullName;
  final CompletionStatus adultChecklistStatus;
  final CompletionStatus infantChecklistStatus;
  final CompletionStatus ccfStatus;
  final CompletionStatus writtenTestStatus;
  final CompletionStatus overallStatus;
}

@immutable
class Student {
  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.studentId,
    required this.notes,
    required this.adultChecklist,
    required this.infantChecklist,
    required this.ccf,
    required this.testScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.empty({required String id, required DateTime createdAt}) => Student(
        id: id,
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        studentId: '',
        notes: '',
        adultChecklist: ChecklistAttempt.empty(now: createdAt),
        infantChecklist: ChecklistAttempt.empty(now: createdAt),
        ccf: CcfEvaluation.empty(now: createdAt),
        testScore: TestScore.empty(now: createdAt),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String studentId;
  final String notes;
  final ChecklistAttempt adultChecklist;
  final ChecklistAttempt infantChecklist;
  final CcfEvaluation ccf;
  final TestScore testScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName {
    final f = firstName.trim();
    final l = lastName.trim();
    return [f, l].where((e) => e.isNotEmpty).join(' ').trim();
  }

  Student copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? studentId,
    String? notes,
    ChecklistAttempt? adultChecklist,
    ChecklistAttempt? infantChecklist,
    CcfEvaluation? ccf,
    TestScore? testScore,
    DateTime? updatedAt,
  }) =>
      Student(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        studentId: studentId ?? this.studentId,
        notes: notes ?? this.notes,
        adultChecklist: adultChecklist ?? this.adultChecklist,
        infantChecklist: infantChecklist ?? this.infantChecklist,
        ccf: ccf ?? this.ccf,
        testScore: testScore ?? this.testScore,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class CourseSummary {
  const CourseSummary({
    required this.totalStudents,
    required this.completeCount,
    required this.needsReviewCount,
    required this.inProgressCount,
    required this.notStartedCount,
    required this.overallStatus,
  });

  final int totalStudents;
  final int completeCount;
  final int needsReviewCount;
  final int inProgressCount;
  final int notStartedCount;
  final CompletionStatus overallStatus;
}

@immutable
class ArchivedClass {
  const ArchivedClass({
    required this.archivedId,
    required this.sourceClassId,
    required this.classSnapshot,
    required this.summarySnapshot,
    required this.rosterSnapshot,
    required this.archivedAt,
  });

  final String archivedId;
  final String sourceClassId;
  final CourseClass classSnapshot;
  final CourseSummary summarySnapshot;
  final List<ArchivedStudentSnapshot> rosterSnapshot;
  final DateTime archivedAt;
}
