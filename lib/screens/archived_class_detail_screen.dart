import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/status_pill.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';

class ArchivedClassDetailScreen extends StatelessWidget {
  const ArchivedClassDetailScreen({required this.archivedId, super.key});

  final String archivedId;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final archived = appState.archivedClasses.where((a) => a.archivedId == archivedId).cast<ArchivedClass?>().firstOrNull;

    if (archived == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Archived Class'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Archived class not found.'),
          ),
        ),
      );
    }

    final c = archived.classSnapshot;
    final date = '${c.classDate.month}/${c.classDate.day}/${c.classDate.year}';
    final archivedDate = '${archived.archivedAt.month}/${archived.archivedAt.day}/${archived.archivedAt.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Class (read-only)'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const TemporaryDataBanner(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.className, style: Theme.of(context).textTheme.titleLarge)),
                        StatusPill(status: archived.summarySnapshot.overallStatus),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${c.courseType.label} • $date'),
                    const SizedBox(height: 6),
                    Text('Archived: $archivedDate', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Frozen roster snapshot', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (archived.rosterSnapshot.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No students were archived.')))
            else
              ...archived.rosterSnapshot.map((s) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(s.fullName, style: Theme.of(context).textTheme.titleMedium)),
                              StatusPill(status: s.overallStatus),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SnapshotChip(label: 'Adult', status: s.adultChecklistStatus),
                              _SnapshotChip(label: 'Infant', status: s.infantChecklistStatus),
                              _SnapshotChip(label: 'CCF', status: s.ccfStatus),
                              _SnapshotChip(label: 'Test', status: s.writtenTestStatus),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _createWorkingCopy(context: context, archivedId: archived.archivedId),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Create Working Copy'),
            ),
            const SizedBox(height: 8),
            Text(
              'Working copies copy only class setup fields. They do not copy students, contact info, notes, checklists, CCF, or test results.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWorkingCopy({required BuildContext context, required String archivedId}) async {
    final appState = AppStateScope.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      helpText: 'Select a new class date',
    );
    if (picked == null) return;

    try {
      appState.createWorkingCopyFromArchive(archivedId: archivedId, classDate: picked);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Working copy created (temporary).')));
      context.go('/today-class');
    } catch (e) {
      debugPrint('Failed to create working copy: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create working copy.')));
    }
  }
}

class _SnapshotChip extends StatelessWidget {
  const _SnapshotChip({required this.label, required this.status});

  final String label;
  final CompletionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = switch (status) {
      CompletionStatus.complete => cs.primaryContainer,
      CompletionStatus.needsReview => cs.errorContainer,
      CompletionStatus.inProgress => cs.tertiaryContainer,
      CompletionStatus.notStarted => cs.surfaceContainerHighest,
    };
    final fg = switch (status) {
      CompletionStatus.complete => cs.onPrimaryContainer,
      CompletionStatus.needsReview => cs.onErrorContainer,
      CompletionStatus.inProgress => cs.onTertiaryContainer,
      CompletionStatus.notStarted => cs.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$label: ${status.label}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
