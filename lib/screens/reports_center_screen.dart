import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';

class ReportsCenterScreen extends StatelessWidget {
  const ReportsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final course = appState.currentClass;
    final students = appState.studentsForCurrentClass();
    final summary = appState.currentClassSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Center'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const TemporaryDataBanner(),
            const SizedBox(height: 16),
            if (course == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No active class. Start a class to preview reports.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.className, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text('${course.courseType.label} • Students: ${students.length}'),
                      if (summary != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Completion: ${summary.overallStatus.label} (Complete: ${summary.completeCount}, Needs review: ${summary.needsReviewCount})',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Available in a later stage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...[
              'Master Class List',
              'Master Skills Checklist',
              'Adult Checklist Report',
              'Infant Checklist Report',
              'Test Score Report',
              'Class Summary',
              'Atlas Export',
            ].map((name) => _ReportTile(name: name)),
            const SizedBox(height: 10),
            Text(
              'PDF generation, printing, sharing, and file exports are disabled during restoration.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(name),
        subtitle: const Text('Unavailable during restoration'),
        trailing: const Icon(Icons.lock_outline),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reports are placeholders during restoration.')),
        ),
      ),
    );
  }
}
