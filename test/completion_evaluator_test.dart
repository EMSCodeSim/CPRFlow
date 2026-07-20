import 'package:flutter_test/flutter_test.dart';

import 'package:ccf_timer_low_risk_test/app/completion_evaluator.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';

void main() {
  final now = DateTime(2026, 7, 20);

  CourseClass course() => CourseClass(
        id: 'class-1',
        className: 'BLS',
        courseType: CourseType.blsProvider,
        classDate: now,
        trainingCenter: '',
        location: '',
        primaryInstructor: 'Instructor',
        additionalInstructor: '',
        notes: '',
        skillsSessionRequired: const {},
        createdAt: now,
        updatedAt: now,
      );

  test('BLS student is not complete without all four passed components', () {
    final student = Student.empty(id: 'student-1', createdAt: now);
    expect(
      CompletionEvaluator.evaluateStudent(s: student, course: course()),
      CompletionStatus.notStarted,
    );
  });

  test('explicit instructor decisions complete all BLS components', () {
    final base = Student.empty(id: 'student-1', createdAt: now);
    final passedChecklist = ChecklistAttempt(
      ratings: const {'skill': ChecklistRating.meetsCriteria},
      reviewed: true,
      decision: ChecklistDecision.pass,
      instructorNotes: '',
      createdAt: now,
      updatedAt: now,
    );
    final student = base.copyWith(
      adultChecklist: passedChecklist,
      infantChecklist: passedChecklist,
      ccf: CcfEvaluation(
        compressionFractionPercent: 85,
        compressionRate: 110,
        compressionQuality: 'Meets Criteria',
        ventilationQuality: 'Meets Criteria',
        pausesMinimized: true,
        instructorComments: '',
        decision: ChecklistDecision.pass,
        createdAt: now,
        updatedAt: now,
      ),
      testScore: TestScore(
        scorePercent: 90,
        passingThresholdPercent: 84,
        decision: ChecklistDecision.pass,
        instructorNotes: '',
        createdAt: now,
        updatedAt: now,
      ),
      updatedAt: now,
    );

    expect(
      CompletionEvaluator.evaluateStudent(s: student, course: course()),
      CompletionStatus.complete,
    );
  });
}
