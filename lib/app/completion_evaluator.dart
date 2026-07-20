import 'package:ccf_timer_low_risk_test/app/models.dart';

class CompletionEvaluator {
  static Set<RequiredComponent> requiredForCourse(CourseClass course) {
    switch (course.courseType) {
      case CourseType.blsProvider:
        return {
          RequiredComponent.adultChecklist,
          RequiredComponent.infantChecklist,
          RequiredComponent.ccfEvaluation,
          RequiredComponent.writtenTest,
        };
      case CourseType.skillsSession:
      case CourseType.custom:
        return course.skillsSessionRequired;
      case CourseType.heartsaverCprAed:
      case CourseType.heartsaverFirstAidCprAed:
        // Temporary restoration-stage assumption:
        // Heartsaver typically requires adult skills + CCF-style evaluation + test.
        return {
          RequiredComponent.adultChecklist,
          RequiredComponent.ccfEvaluation,
          RequiredComponent.writtenTest,
        };
    }
  }

  static CompletionStatus evaluateStudent({required Student s, required CourseClass course}) {
    final required = requiredForCourse(course);
    final results = <CompletionStatus>[];
    for (final c in required) {
      results.add(_componentStatus(s: s, component: c));
    }

    if (results.isEmpty) return CompletionStatus.notStarted;
    if (results.every((r) => r == CompletionStatus.complete)) return CompletionStatus.complete;
    if (results.any((r) => r == CompletionStatus.needsReview)) return CompletionStatus.needsReview;
    if (results.every((r) => r == CompletionStatus.notStarted)) return CompletionStatus.notStarted;
    return CompletionStatus.inProgress;
  }

  static CourseSummary evaluateClass({required CourseClass course, required List<Student> students}) {
    var complete = 0;
    var needsReview = 0;
    var inProgress = 0;
    var notStarted = 0;

    for (final s in students) {
      final st = evaluateStudent(s: s, course: course);
      switch (st) {
        case CompletionStatus.complete:
          complete++;
        case CompletionStatus.needsReview:
          needsReview++;
        case CompletionStatus.inProgress:
          inProgress++;
        case CompletionStatus.notStarted:
          notStarted++;
      }
    }

    CompletionStatus overall;
    if (students.isEmpty) {
      overall = CompletionStatus.notStarted;
    } else if (needsReview > 0) {
      overall = CompletionStatus.needsReview;
    } else if (complete == students.length) {
      overall = CompletionStatus.complete;
    } else if (notStarted == students.length) {
      overall = CompletionStatus.notStarted;
    } else {
      overall = CompletionStatus.inProgress;
    }

    return CourseSummary(
      totalStudents: students.length,
      completeCount: complete,
      needsReviewCount: needsReview,
      inProgressCount: inProgress,
      notStartedCount: notStarted,
      overallStatus: overall,
    );
  }

  static CompletionStatus _componentStatus({required Student s, required RequiredComponent component}) {
    switch (component) {
      case RequiredComponent.adultChecklist:
        return _checklistStatus(s.adultChecklist);
      case RequiredComponent.infantChecklist:
        return _checklistStatus(s.infantChecklist);
      case RequiredComponent.ccfEvaluation:
        return _decisionStatus(s.ccf.decision);
      case RequiredComponent.writtenTest:
        final score = s.testScore.scorePercent;
        if (score == null) return CompletionStatus.notStarted;
        if (s.testScore.decision == ChecklistDecision.notDecided) return CompletionStatus.inProgress;
        if (!s.testScore.isPass) return CompletionStatus.needsReview;
        return CompletionStatus.complete;
    }
  }

  static CompletionStatus _checklistStatus(ChecklistAttempt attempt) {
    if (!attempt.reviewed || attempt.decision == ChecklistDecision.notDecided) {
      final anyTouched = attempt.ratings.values.any((r) => r != ChecklistRating.notEvaluated);
      return anyTouched ? CompletionStatus.inProgress : CompletionStatus.notStarted;
    }

    if (attempt.decision == ChecklistDecision.pass) return CompletionStatus.complete;
    return CompletionStatus.needsReview;
  }

  static CompletionStatus _decisionStatus(ChecklistDecision d) {
    switch (d) {
      case ChecklistDecision.notDecided:
        return CompletionStatus.notStarted;
      case ChecklistDecision.pass:
        return CompletionStatus.complete;
      case ChecklistDecision.needsReview:
        return CompletionStatus.needsReview;
    }
  }
}
