import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/pdf_report_service.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/pdf_filename_service.dart';
import 'package:cpr_instructor_doc/ui/reports/pdf_preview_request.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key, required this.request});

  final Object? request;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final _service = PdfReportService();
  Object? _lastError;

  PdfPreviewRequest? get _req => widget.request is PdfPreviewRequest ? widget.request as PdfPreviewRequest : null;

  String get _title => switch (_req?.kind) {
        PdfReportKind.masterSkillsChecklist => 'Master Skills Checklist',
        PdfReportKind.masterClassList => 'Master Class List',
        PdfReportKind.studentReports => 'Student Reports',
        _ => 'PDF Preview',
      };

  Future<PdfBuildResult> _build() async {
    final req = _req;
    if (req == null) throw StateError('Invalid PDF request');

    try {
      setState(() => _lastError = null);
      return switch (req.kind) {
        PdfReportKind.masterSkillsChecklist => _service.buildMasterSkillsChecklist(data: req.data, paperSize: req.paperSize),
        PdfReportKind.masterClassList => _service.buildMasterClassList(data: req.data, paperSize: req.paperSize),
        PdfReportKind.studentReports => _service.buildStudentReports(data: req.data, studentIds: req.studentIds, paperSize: req.paperSize),
      };
    } catch (e) {
      debugPrint('PDF build failed: $e');
      setState(() => _lastError = e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;
    if (req == null) {
      return const SafeErrorScreen(
        title: 'Missing report request',
        message: 'No report request was provided.',
        onRetryLocation: AppRoutes.today,
      );
    }

    final safeClass = PdfFilenameService.sanitize(req.data.classHeader.className);
    final dateTag = PdfFilenameService.classDateTag(req.data.classHeader.classDate);
    final fileName = switch (req.kind) {
      PdfReportKind.masterSkillsChecklist => '${safeClass}_Master_Skills_Checklist_$dateTag.pdf',
      PdfReportKind.masterClassList => '${safeClass}_Master_Class_List_$dateTag.pdf',
      PdfReportKind.studentReports => '${safeClass}_Student_Reports_$dateTag.pdf',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          if (req.data.source == ReportSource.liveClass)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'This report uses current live class data and may change as records are updated.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                req.data.source == ReportSource.finalizedSnapshot
                    ? 'This report was generated from the finalized class snapshot and is read only.'
                    : 'Snapshot integrity warning: this is a legacy data preview and is not an official finalized report.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: PdfPreview(
              canChangePageFormat: true,
              canChangeOrientation: false,
              allowPrinting: true,
              allowSharing: true,
              pdfFileName: fileName,
              onError: (context, error) {
                _lastError = error;
                return _FailurePanel(
                  error: error,
                  onRetry: () => setState(() {}),
                  onReturn: () => context.pop(),
                );
              },
              build: (format) async {
                final built = await _build();
                return built.bytes;
              },
              onPrinted: (context) {},
              onShared: (context) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.error, required this.onRetry, required this.onReturn});
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 10),
              Text('PDF generation failed', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(onPressed: onReturn, child: const Text('Return')),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
