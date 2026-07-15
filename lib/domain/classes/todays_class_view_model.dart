import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';

class StudentProgressRow {
  const StudentProgressRow({
    required this.student,
    required this.completion,
    required this.writtenScoreDisplay,
    required this.calculationError,
  });

  final StudentRecord student;
  final StudentCompletionResult completion;
  final String writtenScoreDisplay;
  final Object? calculationError;
}

class TodaysClassViewModel {
  const TodaysClassViewModel({
    required this.classRecord,
    required this.students,
    required this.totalStudents,
    required this.passedCount,
    required this.incompleteCount,
    required this.failedCount,
    required this.adultCompleteCount,
    required this.infantChildCompleteCount,
    required this.requiredCcfCompleteCount,
    required this.missingScoreCount,
  });

  final ClassRecord classRecord;
  final List<StudentProgressRow> students;
  final int totalStudents;
  final int passedCount;
  final int incompleteCount;
  final int failedCount;
  final int adultCompleteCount;
  final int infantChildCompleteCount;
  final int requiredCcfCompleteCount;
  final int missingScoreCount;
}
