import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentReportBuilder {
  const StudentReportBuilder();

  Future<Uint8List> build({required ClassReportData data, required List<String> studentIds, required PdfPageFormat pageFormat}) async {
    final doc = pw.Document();
    final now = DateTime.now();

    final ids = studentIds.isEmpty ? data.studentRows.map((e) => e.studentId).toList() : studentIds;
    final selected = [
      for (final id in ids)
        data.studentRows.firstWhere(
          (s) => s.studentId == id,
          orElse: () => data.studentRows.first,
        ),
    ];

    for (final student in selected) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            _header(data: data, student: student, generatedAt: now),
            pw.SizedBox(height: 12),
            _resultBlock(data: data, student: student),
            pw.SizedBox(height: 12),
            _skillsBlock(title: 'Adult Checklist Skills', skills: student.adultSkillResults, definitions: data.adultSkillDefinitions),
            pw.SizedBox(height: 12),
            _skillsBlock(title: 'Infant/Child Checklist Skills', skills: student.infantChildSkillResults, definitions: data.infantChildSkillDefinitions),
            pw.SizedBox(height: 12),
            _signatureBlock(),
          ],
          footer: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text('Generated: ${DateFormat('MMM d, y h:mm a').format(now)}', style: const pw.TextStyle(fontSize: 8))),
                pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _header({required ClassReportData data, required ClassReportStudentRow student, required DateTime generatedAt}) {
    final h = data.classHeader;
    final dateFmt = DateFormat('MMM d, y');
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
        pw.Text('Student Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Source: $sourceLabel', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Class: ${h.className}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Course: ${h.courseType}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Date: ${h.classDate == null ? '—' : dateFmt.format(h.classDate!)}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Location: ${h.location ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.Text('Student: ${student.displayName}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text('Email: ${student.email ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Phone: ${student.phone ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Generated: ${DateFormat('MMM d, y h:mm a').format(generatedAt)}', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _resultBlock({required ClassReportData data, required ClassReportStudentRow student}) {
    final dateFmt = DateFormat('MMM d, y');
    String written() {
      if (!data.classHeader.writtenTestRequired) return 'N/A';
      if (student.scoreResult.score == null) return 'Not Entered';
      if (!student.scoreResult.finalized) return 'Unfinalized';
      return '${student.scoreResult.score}%';
    }

    final ccf = student.ccfResult;
    final ccfPct = ccf?.ccfPercentage == null ? '—' : '${ccf!.ccfPercentage!.toStringAsFixed(0)}%';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Results', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Adult checklist: ${student.adultStatus.label}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Infant/Child checklist: ${student.infantChildStatus.label}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('CCF: ${student.ccfStatus.label}  (CCF %: $ccfPct)', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Compression time: ${ccf?.compressionTimeSeconds ?? '—'} sec', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Pause time: ${ccf?.pauseTimeSeconds ?? '—'} sec', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Written score: ${written()}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 6),
          pw.Text('Automatic result: ${student.automaticResult.name.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Manual override: ${student.manualOverride}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Final result: ${student.finalResult.name.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Skills check-off date: ${student.effectiveSkillsCheckOffDate == null ? '—' : dateFmt.format(student.effectiveSkillsCheckOffDate!)}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Issue date: ${student.effectiveIssueDate == null ? '—' : dateFmt.format(student.effectiveIssueDate!)}', style: const pw.TextStyle(fontSize: 9)),
          if (student.missingRequirements.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Missing requirements:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            for (final m in student.missingRequirements) pw.Text('• $m', style: const pw.TextStyle(fontSize: 9)),
          ],
          if (student.failureReasons.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Failure reasons:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            for (final f in student.failureReasons) pw.Text('• $f', style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
  }

  pw.Widget _skillsBlock({required String title, required List<SkillReportResult> skills, required List<SkillReportColumn> definitions}) {
    final byId = {for (final s in skills) s.skillId: s};
    final rows = <List<String>>[];
    for (final d in definitions) {
      final r = byId[d.skillId];
      rows.add([
        d.shortLabel,
        d.fullTitle,
        _symbol(r?.result),
        (r?.notes == null || r!.notes!.trim().isEmpty) ? '—' : r.notes!,
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table.fromTextArray(
          headers: const ['Key', 'Skill', 'Result', 'Notes'],
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            2: const pw.FixedColumnWidth(44),
            3: const pw.FlexColumnWidth(2),
          },
        ),
      ],
    );
  }

  pw.Widget _signatureBlock() => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.6)),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text('Instructor signature: ______________________________', style: const pw.TextStyle(fontSize: 10))),
            pw.Text('Date signed: ______________', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

  String _symbol(SkillResultValue? v) => switch (v) {
        SkillResultValue.passed => '✓',
        SkillResultValue.failed => 'X',
        SkillResultValue.notEvaluated => '—',
        SkillResultValue.notRequired => 'N/A',
        null => '—',
      };
}
