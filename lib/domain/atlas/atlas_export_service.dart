import 'package:cpr_instructor_doc/domain/atlas/atlas_csv_service.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_template.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_validation.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:intl/intl.dart';

class AtlasExportResult {
  const AtlasExportResult({required this.csv, required this.filename, required this.exportedCount});
  final String csv; final String filename; final int exportedCount;
}

class AtlasExportService {
  const AtlasExportService();
  AtlasValidationSummary validate(ClassReportData data) => AtlasValidationSummary(students: data.studentRows.map((s) {
    final p = <String>[];
    if ((s.firstName ?? '').trim().isEmpty) p.add('First name missing');
    if ((s.lastName ?? '').trim().isEmpty) p.add('Last name missing');
    final email = (s.email ?? '').trim();
    if (email.isEmpty) p.add('Email missing'); else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) p.add('Email is invalid');
    if (data.classHeader.writtenTestRequired) {
      if (s.writtenScore == null) p.add('Final exam score missing');
      if (!s.scoreResult.finalized) p.add('Written test not finalized');
      if (s.scoreResult.finalized && s.writtenScore != null && s.writtenScore! < data.classHeader.writtenPassingScore) p.add('Final exam score is below passing');
    }
    if (s.adultStatus != ChecklistStatus.passed) p.add('Adult checklist not complete');
    if (s.infantChildStatus != ChecklistStatus.passed) p.add('Infant/Child checklist not complete');
    if (data.classHeader.ccfRequired && s.ccfStatus != RequirementStatus.passed) p.add('Required CCF not complete');
    if (s.effectiveSkillsCheckOffDate == null) p.add('Skills check-off date missing');
    if (s.effectiveIssueDate == null) p.add('Issue date missing');
    if (s.finalResult == OverallStudentResult.incomplete) p.add('Final result is Incomplete');
    if (s.finalResult == OverallStudentResult.fail) p.add('Final result is Failed');
    return AtlasStudentValidation(student: s, problems: p.toSet().toList(growable: false));
  }).toList(growable: false));

  AtlasExportResult export({required ClassReportData data, required AtlasTemplate template, required bool readyOnly}) {
    final validations = validate(data).students;
    final selected = readyOnly ? validations.where((e) => e.isReady).toList() : validations;
    final rows = selected.map((e) => template.columns.map((c) => _value(data, e.student, c, template.dateFormat)).toList(growable: false)).toList(growable: false);
    final csv = const AtlasCsvService().encode(headers: template.columns.map((e) => e.header).toList(growable: false), rows: rows);
    final safe = data.classHeader.className.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    final date = data.classHeader.classDate == null ? 'undated' : DateFormat('yyyy-MM-dd').format(data.classHeader.classDate!);
    return AtlasExportResult(csv: csv, filename: '${safe.isEmpty ? 'Class' : safe}_Atlas_Roster_$date.csv', exportedCount: selected.length);
  }

  String _value(ClassReportData data, ClassReportStudentRow s, AtlasColumnMapping c, String format) {
    final df = DateFormat(format);
    return switch (c.field) {
      AtlasField.firstName => s.firstName ?? '', AtlasField.lastName => s.lastName ?? '', AtlasField.fullName => s.displayName,
      AtlasField.email => s.email ?? '', AtlasField.writtenScore => s.writtenScore?.toString() ?? '',
      AtlasField.skillsCheckOffDate => s.effectiveSkillsCheckOffDate == null ? '' : df.format(s.effectiveSkillsCheckOffDate!),
      AtlasField.issueDate => s.effectiveIssueDate == null ? '' : df.format(s.effectiveIssueDate!),
      AtlasField.result => switch (s.finalResult) { OverallStudentResult.pass => 'Passed', OverallStudentResult.incomplete => 'Incomplete', OverallStudentResult.fail => 'Failed' },
      AtlasField.course => data.classHeader.courseType, AtlasField.classDate => data.classHeader.classDate == null ? '' : df.format(data.classHeader.classDate!),
      AtlasField.instructor => data.classHeader.leadInstructor ?? '', AtlasField.additionalInstructor => data.classHeader.additionalInstructor ?? '',
      AtlasField.location => data.classHeader.location ?? '', AtlasField.trainingCenter => data.classHeader.trainingCenter ?? '', AtlasField.trainingSite => data.classHeader.trainingSite ?? '',
      AtlasField.blank => '', AtlasField.fixedValue => c.fixedValue ?? '',
    };
  }
}
