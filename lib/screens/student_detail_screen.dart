import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state.dart';
import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/completion_evaluator.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/status_pill.dart';

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({required this.studentId, super.key});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final s = appState.getStudent(studentId);
    final course = appState.currentClass;
    if (s == null || course == null) {
      return SafeErrorScreen(
        title: s == null ? 'Student not found' : 'No active class',
        message: s == null
            ? 'The student identifier is invalid or the student was removed.'
            : 'Open an active class to review student requirements.',
        primaryActionLabel: "Back to Today's Class",
        onPrimaryAction: () => context.go('/today-class'),
      );
    }

    final status = CompletionEvaluator.evaluateStudent(s: s, course: course);
    final statuses = CompletionEvaluator.requirementStatuses(student: s, course: course);
    final total = statuses.length;
    final completed = statuses.values.where((value) => value == CompletionStatus.complete).length;
    final remaining = total - completed;
    final remediations = CompletionEvaluator.remediationRequirements(student: s, course: course);
    final next = CompletionEvaluator.nextRequiredComponent(student: s, course: course);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        actions: [
          IconButton(tooltip: 'Edit', onPressed: () => context.push('/students/$studentId/edit'), icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.fullName.isEmpty ? 'Unnamed student' : s.fullName, style: Theme.of(context).textTheme.titleLarge)),
                        StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(course.courseType.label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: total == 0 ? 0 : completed / total),
                    const SizedBox(height: 8),
                    Text('$completed of $total required items complete', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PriorityCard(
              status: status,
              remaining: remaining,
              remediationCount: remediations.length,
              next: next,
              studentId: studentId,
            ),
            const SizedBox(height: 12),
            Text('Requirements', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...statuses.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequirementTile(
                    component: entry.key,
                    status: entry.value,
                    onTap: () => context.push(_routeFor(studentId, entry.key)),
                  ),
                )),
            if (status == CompletionStatus.complete) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: () => _completeStudent(context, s),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Complete Student', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: const Text('Student details & notes'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _InfoRow(label: 'Email', value: s.email),
                  _InfoRow(label: 'Phone', value: s.phone),
                  _InfoRow(label: 'Student ID', value: s.studentId),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: Text('Instructor notes', style: Theme.of(context).textTheme.labelLarge)),
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerLeft, child: Text(s.notes.trim().isEmpty ? '—' : s.notes.trim())),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: () => context.push('/students/$studentId/edit'), icon: const Icon(Icons.edit_outlined), label: const Text('Edit Student')),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _confirmRemove(context: context, appState: appState, student: s),
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              label: Text('Remove Student', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeStudent(BuildContext context, Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student requirements complete'),
        content: Text('${student.fullName.isEmpty ? 'This student' : student.fullName} has completed every required component for this class.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Stay Here')),
          FilledButton(onPressed: () => context.pop(true), child: const Text("Return to Today's Class")),
        ],
      ),
    );
    if (confirmed == true && context.mounted) context.go('/today-class');
  }

  Future<void> _confirmRemove({required BuildContext context, required AppState appState, required Student student}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text('This removes ${student.fullName.isEmpty ? 'this student' : student.fullName} from the current class.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    appState.removeStudent(student.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student removed.')));
    context.go('/today-class');
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.status, required this.remaining, required this.remediationCount, required this.next, required this.studentId});
  final CompletionStatus status;
  final int remaining;
  final int remediationCount;
  final RequiredComponent? next;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = status == CompletionStatus.complete
        ? 'All requirements complete'
        : remediationCount > 0
            ? 'Remediation needed'
            : '$remaining ${remaining == 1 ? 'requirement' : 'requirements'} remaining';
    final subtitle = status == CompletionStatus.complete
        ? 'This student is ready to complete the class workflow.'
        : remediationCount > 0
            ? '$remediationCount required ${remediationCount == 1 ? 'item needs' : 'items need'} instructor follow-up.'
            : 'Continue with the next required item below.';

    return Card(
      color: status == CompletionStatus.needsReview ? cs.errorContainer : (status == CompletionStatus.complete ? cs.primaryContainer : null),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
            if (next != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(_routeFor(studentId, next!)),
                  icon: Icon(remediationCount > 0 ? Icons.build_circle_outlined : Icons.arrow_forward_rounded),
                  label: Text(remediationCount > 0 ? 'Open Remediation: ${next!.label}' : 'Next Required: ${next!.label}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({required this.component, required this.status, required this.onTap});
  final RequiredComponent component;
  final CompletionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (status) {
      CompletionStatus.complete => Icons.check_circle_rounded,
      CompletionStatus.needsReview => Icons.error_rounded,
      CompletionStatus.inProgress => Icons.timelapse_rounded,
      CompletionStatus.notStarted => Icons.radio_button_unchecked_rounded,
    };
    final iconColor = switch (status) {
      CompletionStatus.complete => cs.primary,
      CompletionStatus.needsReview => cs.error,
      CompletionStatus.inProgress => cs.tertiary,
      CompletionStatus.notStarted => cs.onSurfaceVariant,
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(_displayLabel(component)),
        subtitle: Text(status == CompletionStatus.needsReview ? 'Needs remediation' : status.label),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  String _displayLabel(RequiredComponent c) => switch (c) {
        RequiredComponent.adultChecklist => 'Adult CPR Checklist',
        RequiredComponent.infantChecklist => 'Infant CPR Checklist',
        RequiredComponent.ccfEvaluation => 'CCF Evaluation',
        RequiredComponent.writtenTest => 'Written Test',
      };
}

String _routeFor(String id, RequiredComponent c) => switch (c) {
      RequiredComponent.adultChecklist => '/students/$id/adult-checklist',
      RequiredComponent.infantChecklist => '/students/$id/infant-checklist',
      RequiredComponent.ccfEvaluation => '/students/$id/ccf',
      RequiredComponent.writtenTest => '/students/$id/test-score',
    };

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.trim().isEmpty ? '—' : value.trim())),
        ],
      ),
    );
  }
}
