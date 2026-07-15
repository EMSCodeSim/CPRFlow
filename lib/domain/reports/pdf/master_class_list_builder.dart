import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MasterClassListBuilder {
  const MasterClassListBuilder();

  Future<Uint8List> build({required ClassReportData data, required PdfPageFormat pageFormat}) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(data: data, generatedAt: now),
          pw.SizedBox(height: 10),
          _rosterTable(data: data),
          pw.SizedBox(height: 12),
          _summary(data: data),
        ],
        footer: (context) => _footer(generatedAt: now, pageNumber: context.pageNumber, pageCount: context.pagesCount),
      ),
    );

    return doc.save();
  }

  pw.Widget _header({required ClassReportData data, required DateTime generatedAt}) {
    final h = data.classHeader;
    final dateFmt = DateFormat('MMM d, y');
    final timeFmt = DateFormat('h:mm a');

    final classDate = h.classDate == null ? '—' : dateFmt.format(h.classDate!);
    final timeRange = (h.startTime == null && h.endTime == null)
        ? '—'
        : '${h.startTime == null ? '—' : timeFmt.format(h.startTime!)} – ${h.endTime == null ? '—' : timeFmt.format(h.endTime!)}';
    final sourceLabel = switch (data.source) {
      ReportSource.liveClass => 'Live Class Data',
      ReportSource.finalizedSnapshot => 'Finalized Snapshot — Read Only',
      ReportSource.legacySnapshotWarning => 'Snapshot Integrity Warning',
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('CCF Timer', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Master Class List', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Course: ${h.courseType}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Class: ${h.className}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Date: $classDate', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Time: $timeRange', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Location: ${h.location ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Lead Instructor: ${h.leadInstructor ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Additional Instructor: ${h.additionalInstructor ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Training Center: ${h.trainingCenter ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Training Site: ${h.trainingSite ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Class ID: ${h.classId}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Total students: ${h.studentCount}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Generated: ${DateFormat('MMM d, y h:mm a').format(generatedAt)}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Source: $sourceLabel', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (data.snapshotMetadata != null) ...[
          pw.Text('Finalized: ${DateFormat('MMM d, y h:mm a').format(data.snapshotMetadata!.finalizedAt)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Snapshot #: ${data.snapshotMetadata!.snapshotNumber}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ],
    );
  }

  pw.Widget _rosterTable({required ClassReportData data}) {
    String checklistCell(ChecklistStatus s) => s.label;

    String ccfCell(ClassReportStudentRow r) {
      if (!data.classHeader.ccfRequired) return 'N/A';
      return r.ccfStatus.label;
    }

    String writtenCell(ClassReportStudentRow r) {
      if (!data.classHeader.writtenTestRequired) return 'N/A';
      if (r.scoreResult.score == null) return 'Not Entered';
      if (!r.scoreResult.finalized) return 'Unfinalized';
      return '${r.scoreResult.score}%';
    }

    final dateFmt = DateFormat('MMM d, y');
    final rows = <List<String>>[];
    for (final s in data.studentRows) {
      rows.add([
        s.displayName,
        s.email ?? '—',
        checklistCell(s.adultStatus),
        checklistCell(s.infantChildStatus),
        ccfCell(s),
        writtenCell(s),
        s.effectiveSkillsCheckOffDate == null ? '—' : dateFmt.format(s.effectiveSkillsCheckOffDate!),
        s.effectiveIssueDate == null ? '—' : dateFmt.format(s.effectiveIssueDate!),
        s.finalResult.name.toUpperCase(),
      ]);
    }

    return pw.Table.fromTextArray(
      headers: const [
        'Student Name',
        'Email',
        'Adult Checklist',
        'Infant/Child Checklist',
        'CCF',
        'Written Test Score',
        'Skills Check-Off Date',
        'Issue Date',
        'Overall Result',
      ],
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(2.0),
      },
    );
  }

  pw.Widget _summary({required ClassReportData data}) {
    final t = data.totals;
    final avg = t.averageFinalizedWrittenScore == null
        ? 'Average Written Score: —'
        : 'Average Written Score: ${t.averageFinalizedWrittenScore!.toStringAsFixed(0)}% — ${t.averageFinalizedWrittenScoreCount} scores included';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Total students: ${t.totalStudents}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Passed: ${t.passedCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Incomplete: ${t.incompleteCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Failed: ${t.failedCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text('Adult completed: ${t.adultCompleteCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Infant/Child completed: ${t.infantCompleteCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Required CCF completed: ${t.requiredCcfCompleteCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Written scores entered: ${t.writtenScoresEnteredCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(avg, style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Manual override count: ${t.manualOverrideCount}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.Text('Instructor signature: ______________________________', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text('Date signed: ______________', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _footer({required DateTime generatedAt, required int pageNumber, required int pageCount}) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text('Generated: ${DateFormat('MMM d, y h:mm a').format(generatedAt)}', style: const pw.TextStyle(fontSize: 8))),
            pw.Text('Page $pageNumber / $pageCount', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );
}
