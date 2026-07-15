import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/pdf_report_service.dart';

enum PdfReportKind { masterSkillsChecklist, masterClassList, studentReports }

class PdfPreviewRequest {
  const PdfPreviewRequest({
    required this.kind,
    required this.data,
    this.studentIds = const [],
    this.paperSize = ReportPaperSize.letter,
  });

  final PdfReportKind kind;
  final ClassReportData data;
  final List<String> studentIds;
  final ReportPaperSize paperSize;
}
