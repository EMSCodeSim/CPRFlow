import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';

class ClassSelectionScreen extends StatelessWidget {
  const ClassSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final classes = appState.activeClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Class'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const TemporaryDataBanner(),
            const SizedBox(height: 16),
            Text(
              'Active in-memory classes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (classes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No active classes found.', style: Theme.of(context).textTheme.bodyMedium),
                ),
              )
            else
              ...classes.map((c) {
                final date = '${c.classDate.month}/${c.classDate.day}/${c.classDate.year}';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
                    title: Text(c.className),
                    subtitle: Text('${c.courseType.label} • $date'),
                    onTap: () {
                      final ok = appState.selectActiveClass(c.id);
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not select class.')));
                        return;
                      }
                      context.go('/today-class');
                    },
                  ),
                );
              }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
