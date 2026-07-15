import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';

class AtlasStudentValidation {
  const AtlasStudentValidation({required this.student, required this.problems});
  final ClassReportStudentRow student;
  final List<String> problems;
  bool get isReady => problems.isEmpty && student.finalResult == OverallStudentResult.pass;
}

class AtlasValidationSummary {
  const AtlasValidationSummary({required this.students});
  final List<AtlasStudentValidation> students;
  int get total => students.length;
  int get ready => students.where((e) => e.isReady).length;
  int get needsFix => total - ready;
}
