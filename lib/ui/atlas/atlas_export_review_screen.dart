import 'dart:convert';

import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_export_service.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_template.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_template_service.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_validation.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class AtlasExportReviewScreen extends StatefulWidget {
  const AtlasExportReviewScreen.live({super.key, required this.classId}) : snapshotId = null, isLive = true;
  const AtlasExportReviewScreen.snapshot({super.key, required this.snapshotId}) : classId = null, isLive = false;

  final String? classId;
  final String? snapshotId;
  final bool isLive;

  @override
  State<AtlasExportReviewScreen> createState() => _AtlasExportReviewScreenState();
}

class _AtlasExportReviewScreenState extends State<AtlasExportReviewScreen> {
  final _exportService = const AtlasExportService();
  final _templateService = AtlasTemplateService();
  Future<_AtlasScreenData>? _future;
  bool _didLoad = false;
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _future = _load();
  }

  Future<_AtlasScreenData> _load() async {
    final reportService = AppScope.of(context).classReportService;
    if (reportService == null) throw StateError('Atlas export unavailable in recovery mode');
    final report = widget.isLive
        ? await reportService.buildForLiveClass(classId: widget.classId!)
        : await reportService.buildForFinalizedSnapshot(snapshotId: widget.snapshotId!);
    final template = await _templateService.load();
    return _AtlasScreenData(report: report, template: template, validation: _exportService.validate(report));
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _share(_AtlasScreenData data, {required bool readyOnly}) async {
    if (_sharing) return;
    if (readyOnly && data.validation.ready == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students are ready for Atlas export.')));
      return;
    }
    if (!readyOnly) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export full roster?'),
          content: const Text('This export includes all students and records Result as Passed, Incomplete, or Failed. Students with missing required fields may be rejected by Atlas.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Export')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _sharing = true);
    try {
      final result = _exportService.export(data: data.report, template: data.template, readyOnly: readyOnly);
      final bytes = utf8.encode(result.csv);
      final file = XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: result.filename,
      );
      await Share.shareXFiles([file], subject: 'Atlas roster export');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.exportedCount} students exported.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Atlas export failed: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive && (widget.snapshotId == null || widget.snapshotId!.isEmpty)) {
      return const SafeErrorScreen(title: 'Missing snapshot', message: 'No snapshot ID provided.', onRetryLocation: AppRoutes.archive);
    }
    if (widget.isLive && (widget.classId == null || widget.classId!.isEmpty)) {
      return const SafeErrorScreen(title: 'Missing class', message: 'No class ID provided.', onRetryLocation: AppRoutes.today);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas Export Review'),
        actions: [
          IconButton(
            tooltip: 'Template settings',
            onPressed: () async {
              await context.push(AppRoutes.atlasTemplateSettings);
              if (mounted) _reload();
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: FutureBuilder<_AtlasScreenData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Atlas data could not be prepared.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Retry')),
            ])));
          }
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final readOnly = data.report.source != ReportSource.liveClass;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(data.report.classHeader.className, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(readOnly ? 'Finalized Snapshot — Read Only' : 'Live Class Data'),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _CountChip(label: 'Total', value: data.validation.total),
                    _CountChip(label: 'Ready', value: data.validation.ready),
                    _CountChip(label: 'Needs Fix', value: data.validation.needsFix),
                    Chip(label: Text(data.template.name)),
                  ]),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: data.validation.students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = data.validation.students[index];
                    return Card(
                      child: ExpansionTile(
                        leading: Icon(row.isReady ? Icons.check_circle : Icons.warning_amber, color: row.isReady ? Colors.green : Theme.of(context).colorScheme.error),
                        title: Text(row.student.displayName),
                        subtitle: Text(row.isReady ? 'Ready to export as Passed' : '${row.student.finalResult.name.toUpperCase()} • ${row.problems.length} issue(s)'),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          if (row.problems.isEmpty) const Align(alignment: Alignment.centerLeft, child: Text('All required Atlas fields are complete.')),
                          for (final problem in row.problems) Align(alignment: Alignment.centerLeft, child: Text('• $problem')),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<_AtlasScreenData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return const SizedBox.shrink();
          return SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: _sharing ? null : () => _share(data, readyOnly: false), child: const Text('Export Full Roster'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: _sharing ? null : () => _share(data, readyOnly: true), child: Text(_sharing ? 'Preparing…' : 'Export Ready Students'))),
            ]),
          );
        },
      ),
    );
  }
}

class _AtlasScreenData {
  const _AtlasScreenData({required this.report, required this.template, required this.validation});
  final ClassReportData report;
  final AtlasTemplate template;
  final AtlasValidationSummary validation;
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}
