import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MasterSkillsChecklistBuilder {
  const MasterSkillsChecklistBuilder();

  Future<Uint8List> build({required ClassReportData data, required PdfPageFormat pageFormat}) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildSkillsPage(
            data: data,
            title: 'Adult BLS Master Skills Checklist',
            subtitle: 'Adult BLS Skills',
            columns: data.adultSkillDefinitions,
            skills: (r) => r.adultSkillResults,
            resultLabel: (r) => _adultResultLabel(data: data, row: r),
            includeWrittenScore: true,
            includeCcf: false,
            includeOverall: false,
            generatedAt: now,
          ),
          pw.SizedBox(height: 18),
          _buildSkillsPage(
            data: data,
            title: 'Infant/Child BLS Master Skills Checklist',
            subtitle: 'Infant/Child BLS Skills',
            columns: data.infantChildSkillDefinitions,
            skills: (r) => r.infantChildSkillResults,
            resultLabel: (r) => r.finalResult.name.toUpperCase(),
            includeWrittenScore: false,
            includeCcf: true,
            includeOverall: true,
            generatedAt: now,
          ),
        ],
        footer: (context) => _footer(data: data, generatedAt: now, pageNumber: context.pageNumber, pageCount: context.pagesCount),
      ),
    );

    return doc.save();
  }

  pw.Widget _buildSkillsPage({
    required ClassReportData data,
    required String title,
    required String subtitle,
    required List<SkillReportColumn> columns,
    required List<SkillReportResult> Function(ClassReportStudentRow row) skills,
    required String Function(ClassReportStudentRow row) resultLabel,
    required bool includeWrittenScore,
    required bool includeCcf,
    required bool includeOverall,
    required DateTime generatedAt,
  }) {
    final header = data.classHeader;
    final dateFmt = DateFormat('MMM d, y');
    final timeFmt = DateFormat('h:mm a');

    final classDate = header.classDate == null ? '—' : dateFmt.format(header.classDate!);
    final timeRange = (header.startTime == null && header.endTime == null)
        ? '—'
        : '${header.startTime == null ? '—' : timeFmt.format(header.startTime!)} – ${header.endTime == null ? '—' : timeFmt.format(header.endTime!)}';

    final sourceLabel = switch (data.source) {
      ReportSource.liveClass => 'Live Class Data',
      ReportSource.finalizedSnapshot => 'Finalized Snapshot — Read Only',
      ReportSource.legacySnapshotWarning => 'Snapshot Integrity Warning',
    };

    final tableHeaders = <String>['Student Name', ...columns.map((c) => c.shortLabel)];
    if (includeWrittenScore) tableHeaders.add('Written');
    tableHeaders.add(subtitle.contains('Adult') ? 'Adult Complete' : 'Inf/Ch Complete');
    if (includeCcf) tableHeaders.add('CCF');
    if (includeOverall) tableHeaders.add('Overall');
    tableHeaders.add(subtitle.contains('Adult') ? 'Adult Result' : 'Course Result');

    final rows = <List<String>>[];
    for (final s in data.studentRows) {
      final skillResults = {for (final r in skills(s)) r.skillId: r};
      final cells = <String>[s.displayName];
      for (final col in columns) {
        final r = skillResults[col.skillId];
        cells.add(_symbol(r?.result));
      }
      if (includeWrittenScore) {
        cells.add(_writtenScoreCell(data: data, row: s));
      }
      cells.add(_checklistStatusCell(subtitle.contains('Adult') ? s.adultStatus : s.infantChildStatus));
      if (includeCcf) cells.add(_ccfCell(data: data, row: s));
      if (includeOverall) cells.add(s.finalResult.name.toUpperCase());
      cells.add(resultLabel(s));
      rows.add(cells);
    }

    final keyLines = <String>[];
    for (final col in columns) {
      keyLines.add('${col.shortLabel}: ${col.fullTitle}');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CCF Timer', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Course: ${header.courseType}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Class: ${header.className}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: $classDate', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Time: $timeRange', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Location: ${header.location ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Lead Instructor: ${header.leadInstructor ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Additional Instructor: ${header.additionalInstructor ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Training Center: ${header.trainingCenter ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Training Site: ${header.trainingSite ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Class ID: ${header.classId}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Student count: ${header.studentCount}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Generated: ${DateFormat('MMM d, y h:mm a').format(generatedAt)}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Source: $sourceLabel', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  if (data.snapshotMetadata != null) ...[
                    pw.Text('Finalized: ${DateFormat('MMM d, y h:mm a').format(data.snapshotMetadata!.finalizedAt)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Snapshot #: ${data.snapshotMetadata!.snapshotNumber}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: tableHeaders,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.center,
          headerAlignment: pw.Alignment.center,
          columnWidths: {
            0: const pw.FlexColumnWidth(2.4),
          },
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
          },
        ),
        if (columns.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Skill Key', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final line in keyLines) pw.Container(width: 260, child: pw.Text(line, style: const pw.TextStyle(fontSize: 8))),
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _footer({required ClassReportData data, required DateTime generatedAt, required int pageNumber, required int pageCount}) {
    final legend = 'Legend: ✓ Passed   X Needs remediation/failed   — Not evaluated   N/A Not required';
    final totals = data.totals;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(legend, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('Passed: ${totals.passedCount}   Incomplete: ${totals.incompleteCount}   Failed: ${totals.failedCount}', style: const pw.TextStyle(fontSize: 8))),
              pw.Text('Page $pageNumber / $pageCount', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('Instructor signature: ______________________________', style: const pw.TextStyle(fontSize: 9))),
              pw.Text('Date signed: ______________', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text('Generated: ${DateFormat('MMM d, y h:mm a').format(generatedAt)}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  String _symbol(SkillResultValue? v) => switch (v) {
        SkillResultValue.passed => '✓',
        SkillResultValue.failed => 'X',
        SkillResultValue.notEvaluated => '—',
        SkillResultValue.notRequired => 'N/A',
        null => '—',
      };

  String _checklistStatusCell(ChecklistStatus status) => status.label;

  String _ccfCell({required ClassReportData data, required ClassReportStudentRow row}) {
    if (!data.classHeader.ccfRequired) {
      final status = row.ccfResult?.status ?? RequirementStatus.notRequired;
      return status == RequirementStatus.notRequired ? 'N/A' : status.label;
    }
    return row.ccfResult?.status.label ?? 'Not Started';
  }

  String _writtenScoreCell({required ClassReportData data, required ClassReportStudentRow row}) {
    if (!data.classHeader.writtenTestRequired) return 'N/A';
    final score = row.scoreResult.score;
    if (score == null) return 'Not Entered';
    if (!row.scoreResult.finalized) return 'Unfinalized';
    return '$score%';
  }

  String _adultResultLabel({required ClassReportData data, required ClassReportStudentRow row}) {
    // PASS: adult passed AND written passed or not required.
    // FAIL: adult failed OR written failed.
    // INCOMPLETE: adult not started/incomplete OR written missing/unfinalized.
    final adult = row.adultStatus;
    final written = row.scoreResult;

    if (adult == ChecklistStatus.failed) return 'FAIL';
    if (adult == ChecklistStatus.notStarted || adult == ChecklistStatus.incomplete) return 'INCOMPLETE';

    if (!data.classHeader.writtenTestRequired) return adult == ChecklistStatus.passed ? 'PASS' : 'INCOMPLETE';
    if (written.score == null) return 'INCOMPLETE';
    if (!written.finalized) return 'INCOMPLETE';
    if (written.score! < written.writtenPassingScore) return 'FAIL';
    return adult == ChecklistStatus.passed ? 'PASS' : 'INCOMPLETE';
  }
}
