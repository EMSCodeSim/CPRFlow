import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_data.dart';
import 'package:cpr_instructor_doc/domain/reports/report_source.dart';
import 'package:cpr_instructor_doc/ui/reports/pdf_preview_request.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ReportsCenterScreen extends StatefulWidget {
  const ReportsCenterScreen.live({super.key, required this.classId})
      : snapshotId = null,
        isLive = true;

  const ReportsCenterScreen.snapshot({super.key, required this.snapshotId})
      : classId = null,
        isLive = false;

  final String? classId;
  final String? snapshotId;
  final bool isLive;

  @override
  State<ReportsCenterScreen> createState() => _ReportsCenterScreenState();
}

class _ReportsCenterScreenState extends State<ReportsCenterScreen> {
  Future<ClassReportData>? _future;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _future = _load();
  }

  Future<ClassReportData> _load() async {
    final services = AppScope.of(context);
    final reportService = services.classReportService;
    if (reportService == null) throw StateError('Reports unavailable in recovery mode');

    if (widget.isLive) {
      return reportService.buildForLiveClass(classId: widget.classId!);
    }
    return reportService.buildForFinalizedSnapshot(snapshotId: widget.snapshotId!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClassReportData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return SafeErrorScreen(
            title: 'Reports could not be opened',
            message: 'Report data could not be prepared.',
            onRetryLocation: widget.isLive ? AppRoutes.today : AppRoutes.archive,
          );
        }
        final data = snap.data;
        if (data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final dateFmt = DateFormat('MMM d, y');
        final classDate = data.classHeader.classDate == null ? '—' : dateFmt.format(data.classHeader.classDate!);
        final statusLabel = switch (data.source) {
          ReportSource.liveClass => 'Live Class Data',
          ReportSource.finalizedSnapshot => 'Finalized Snapshot — Read Only',
          ReportSource.legacySnapshotWarning => 'Snapshot Integrity Warning',
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reports Center'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportHeaderCard(
                className: data.classHeader.className,
                course: data.classHeader.courseType,
                date: classDate,
                location: data.classHeader.location,
                instructor: data.classHeader.leadInstructor,
                studentCount: data.classHeader.studentCount,
                lifecycleStatus: data.classHeader.lifecycleStatus,
                statusLabel: statusLabel,
                warnings: data.warnings,
              ),
              const SizedBox(height: 12),
              _ReportActionCard(
                title: 'Attached Documents',
                subtitle: widget.isLive ? 'View, attach, and export local files' : 'View and export (read-only)',
                icon: Icons.folder_open,
                primaryLabel: 'Open',
                onPrimary: () {
                  final loc = widget.isLive ? '${AppRoutes.classDocuments}?classId=${widget.classId}' : '/archive/${widget.snapshotId}/documents';
                  context.push(loc);
                },
              ),
              const SizedBox(height: 12),
              _ReportActionCard(
                title: 'Master Skills Checklist',
                subtitle: 'Adult + Infant/Child master matrix',
                icon: Icons.grid_on,
                primaryLabel: 'Preview',
                onPrimary: () => context.push(AppRoutes.pdfPreview, extra: PdfPreviewRequest(kind: PdfReportKind.masterSkillsChecklist, data: data)),
              ),
              const SizedBox(height: 12),
              _ReportActionCard(
                title: 'Master Class List',
                subtitle: 'Roster + key statuses + totals',
                icon: Icons.list_alt,
                primaryLabel: 'Preview',
                onPrimary: () => context.push(AppRoutes.pdfPreview, extra: PdfPreviewRequest(kind: PdfReportKind.masterClassList, data: data)),
              ),
              const SizedBox(height: 12),
              _ReportActionCard(
                title: 'Individual Student Reports',
                subtitle: 'One PDF per student (selectable)',
                icon: Icons.person,
                primaryLabel: 'Open',
                onPrimary: () => context.push(AppRoutes.pdfPreview, extra: PdfPreviewRequest(kind: PdfReportKind.studentReports, data: data, studentIds: const [])),
              ),
              const SizedBox(height: 12),
              _ReportActionCard(
                title: 'Atlas Export',
                subtitle: 'Validate + export CSV roster',
                icon: Icons.table_view,
                primaryLabel: 'Open',
                onPrimary: () {
                  final loc = widget.isLive ? '${AppRoutes.todayAtlas}?classId=${widget.classId}' : '/archive/${widget.snapshotId}/atlas';
                  context.push(loc);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportHeaderCard extends StatelessWidget {
  const _ReportHeaderCard({
    required this.className,
    required this.course,
    required this.date,
    required this.location,
    required this.instructor,
    required this.studentCount,
    required this.lifecycleStatus,
    required this.statusLabel,
    required this.warnings,
  });

  final String className;
  final String course;
  final String date;
  final String? location;
  final String? instructor;
  final int studentCount;
  final String lifecycleStatus;
  final String statusLabel;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(className.isEmpty ? '(Unnamed class)' : className, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.school, label: course),
              _MetaChip(icon: Icons.event, label: date),
              _MetaChip(icon: Icons.place, label: (location == null || location!.trim().isEmpty) ? '—' : location!),
              _MetaChip(icon: Icons.person, label: (instructor == null || instructor!.trim().isEmpty) ? '—' : instructor!),
              _MetaChip(icon: Icons.group, label: '$studentCount students'),
              _MetaChip(icon: Icons.flag, label: lifecycleStatus),
            ],
          ),
          const SizedBox(height: 12),
          Text(statusLabel, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(w, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ReportActionCard extends StatelessWidget {
  const _ReportActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}
