import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/master_class_list_builder.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/master_skills_checklist_builder.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/pdf_filename_service.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/student_report_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';

enum ReportPaperSize { letter, a4 }

class PdfBuildResult {
  const PdfBuildResult({required this.filename, required this.bytes});
  final String filename;
  final Uint8List bytes;
}

class PdfReportService {
  PdfReportService({
    MasterSkillsChecklistBuilder? masterSkillsChecklistBuilder,
    MasterClassListBuilder? masterClassListBuilder,
    StudentReportBuilder? studentReportBuilder,
  })  : _masterSkillsChecklistBuilder = masterSkillsChecklistBuilder ?? const MasterSkillsChecklistBuilder(),
        _masterClassListBuilder = masterClassListBuilder ?? const MasterClassListBuilder(),
        _studentReportBuilder = studentReportBuilder ?? const StudentReportBuilder();

  final MasterSkillsChecklistBuilder _masterSkillsChecklistBuilder;
  final MasterClassListBuilder _masterClassListBuilder;
  final StudentReportBuilder _studentReportBuilder;

  PdfPageFormat pageFormatFor(ReportPaperSize size, {required bool landscape}) {
    final base = switch (size) {
      ReportPaperSize.letter => PdfPageFormat.letter,
      ReportPaperSize.a4 => PdfPageFormat.a4,
    };
    return landscape ? base.landscape : base;
  }

  Future<PdfBuildResult> buildMasterSkillsChecklist({required ClassReportData data, required ReportPaperSize paperSize}) async {
    final bytes = await _masterSkillsChecklistBuilder.build(
      data: data,
      pageFormat: pageFormatFor(paperSize, landscape: true),
    );
    final name = PdfFilenameService.sanitize(data.classHeader.className);
    final date = PdfFilenameService.classDateTag(data.classHeader.classDate);
    return PdfBuildResult(filename: PdfFilenameService.ensurePdfExtension('${name}_Master_Skills_Checklist_$date'), bytes: bytes);
  }

  Future<PdfBuildResult> buildMasterClassList({required ClassReportData data, required ReportPaperSize paperSize}) async {
    final bytes = await _masterClassListBuilder.build(
      data: data,
      pageFormat: pageFormatFor(paperSize, landscape: true),
    );
    final name = PdfFilenameService.sanitize(data.classHeader.className);
    final date = PdfFilenameService.classDateTag(data.classHeader.classDate);
    return PdfBuildResult(filename: PdfFilenameService.ensurePdfExtension('${name}_Master_Class_List_$date'), bytes: bytes);
  }

  Future<PdfBuildResult> buildStudentReports({
    required ClassReportData data,
    required List<String> studentIds,
    required ReportPaperSize paperSize,
  }) async {
    final bytes = await _studentReportBuilder.build(
      data: data,
      studentIds: studentIds,
      pageFormat: pageFormatFor(paperSize, landscape: false),
    );

    final selected = studentIds.length == 1
        ? (data.studentRows.where((e) => e.studentId == studentIds.first).map((e) => e.displayName).firstOrNull ?? 'Student')
        : 'Students_${studentIds.length}';
    final file = PdfFilenameService.ensurePdfExtension('${PdfFilenameService.sanitize(selected)}_${PdfFilenameService.sanitize(data.classHeader.className)}_Student_Report');
    return PdfBuildResult(filename: file, bytes: bytes);
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
