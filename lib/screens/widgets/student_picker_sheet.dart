import 'package:flutter/material.dart';

import 'package:ccf_timer_low_risk_test/app/models.dart';

/// A simple, restoration-stage student picker used by Today actions.
///
/// This keeps navigation decisions explicit (no silently choosing the first
/// student when multiple exist).
class StudentPickerSheet extends StatelessWidget {
  const StudentPickerSheet({required this.title, required this.students, super.key});

  final String title;
  final List<Student> students;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Select a student:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ...students.map((s) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(s.fullName.isEmpty ? 'Unnamed student' : s.fullName),
                    subtitle: Text(s.email.isEmpty ? '—' : s.email),
                    onTap: () => Navigator.of(context).pop<Student>(s),
                  ),
                )),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop<Student?>(null), child: const Text('Cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
