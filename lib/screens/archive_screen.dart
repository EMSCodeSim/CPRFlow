import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/status_pill.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final currentSummary = appState.currentClassSummary();
    final currentClass = appState.currentClass;
    final archived = appState.archivedClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const TemporaryDataBanner(),
            const SizedBox(height: 16),
            if (currentClass != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Active class', style: Theme.of(context).textTheme.titleMedium)),
                          if (currentSummary != null) StatusPill(status: currentSummary.overallStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(currentClass.className, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('${currentClass.courseType.label} • ${currentSummary?.totalStudents ?? 0} students'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Archive current class?'),
                              content: const Text(
                                'This will store a frozen, read-only snapshot in the temporary archive and clear the active editable class data.\n\nDuring this restoration stage, class, student, checklist, CCF, and score data may reset when Preview restarts.',
                              ),
                              actions: [
                                TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                                FilledButton.icon(
                                  onPressed: () {
                                    appState.archiveCurrentClass();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class archived (temporary).')));
                                    context.pop();
                                  },
                                  icon: const Icon(Icons.archive_outlined),
                                  label: const Text('Archive'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Move to Temporary Archive'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Archived classes are read-only. Creating a working copy does not copy student results, checklists, test scores, or private notes.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Temporary archive', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (archived.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No archived classes yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...archived.map((a) => _ArchivedClassTile(archivedClass: a)),
          ],
        ),
      ),
    );
  }
}

class _ArchivedClassTile extends StatelessWidget {
  const _ArchivedClassTile({required this.archivedClass});

  final ArchivedClass archivedClass;

  @override
  Widget build(BuildContext context) {
    final c = archivedClass.classSnapshot;
    final date = '${c.classDate.month}/${c.classDate.day}/${c.classDate.year}';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
        title: Text(c.className),
        subtitle: Text('${c.courseType.label} • $date • ${archivedClass.summarySnapshot.totalStudents} students'),
        trailing: const Icon(Icons.lock_outline),
        onTap: () => context.push('/archive/${archivedClass.archivedId}'),
      ),
    );
  }
}
