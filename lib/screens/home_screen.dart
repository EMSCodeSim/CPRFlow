import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state.dart';
import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/restoration_prefs_controller.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/status_pill.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.prefsController, super.key});

  final RestorationPrefsController prefsController;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final summary = appState.currentClassSummary();
    final currentClass = appState.currentClass;

    final instructorName = prefsController.instructorName;
    final trimmedName = instructorName.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CPR Instructor'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const TemporaryDataBanner(),
            if (prefsController.showPrefsLoadError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Saved settings could not be loaded. Using defaults (this does not block the app).'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              trimmedName.isEmpty ? 'Welcome' : 'Welcome, $trimmedName',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              currentClass == null ? "No active class yet." : 'Here is your current class overview.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _TodayClassCard(course: currentClass, summary: summary),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: currentClass == null ? null : () => context.go('/today-class'),
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text("Open Today's Class"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startNewClassFlow(context: context, appState: appState),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Start New Class'),
                  ),
                ),
              ],
            ),
            if (currentClass == null && appState.hasAnyActiveClasses) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/classes'),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('Select an existing class'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/timer'),
                    icon: const Icon(Icons.timer_rounded),
                    label: const Text('CCF Timer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/archive'),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNewClassFlow({required BuildContext context, required AppState appState}) async {
    final current = appState.currentClass;
    if (current == null) {
      context.go('/new-class');
      return;
    }

    final selected = await showDialog<_NewClassChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new class?'),
        content: const Text(
          'A class is already active. During this restoration stage, current class, student, checklist, CCF, and score data is temporary and may reset when Preview restarts.\n\nChoose what to do with the current class before continuing.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(_NewClassChoice.cancel), child: const Text('Cancel')),
          TextButton.icon(
            onPressed: () => context.pop(_NewClassChoice.archive),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive Current Class'),
          ),
          FilledButton.icon(
            onPressed: () => context.pop(_NewClassChoice.discard),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Discard & Continue'),
          ),
        ],
      ),
    );

    if (selected == null || selected == _NewClassChoice.cancel) return;

    if (selected == _NewClassChoice.archive) {
      appState.archiveCurrentClass();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current class archived (temporary).')));
      context.go('/new-class');
      return;
    }

    // Discard flow
    final needsSecondConfirm = appState.currentClassHasStudentsOrEvaluations();
    if (needsSecondConfirm) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard current class data?'),
          content: const Text(
            'This class has students and/or evaluations. Discarding will permanently clear the active in-memory class, roster, and any entered evaluations for this restoration stage.',
          ),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => context.pop(true), child: const Text('Discard')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    appState.discardCurrentClassAndData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current class discarded (temporary).')));
    context.go('/new-class');
  }
}

enum _NewClassChoice { cancel, archive, discard }

class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({required this.course, required this.summary});

  final CourseClass? course;
  final CourseSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (course == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text("Today's Class", style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Create a class to begin roster, checklists, CCF, and test scoring.',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final c = course!;
    final date = '${c.classDate.month}/${c.classDate.day}/${c.classDate.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(child: Text("Today's Class", style: theme.textTheme.titleMedium)),
                if (summary != null) StatusPill(status: summary!.overallStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(c.className, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${c.courseType.label} • $date',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KeyValue(icon: Icons.place_outlined, label: 'Location', value: c.location),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KeyValue(
                    icon: Icons.groups_outlined,
                    label: 'Students',
                    value: (summary?.totalStudents ?? 0).toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
