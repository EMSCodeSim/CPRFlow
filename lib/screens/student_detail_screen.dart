import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state.dart';
import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
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
    if (s == null) {
      return SafeErrorScreen(
        title: 'Student not found',
        message: 'The student identifier is invalid or the student was removed.',
        primaryActionLabel: "Back to Today's Class",
        onPrimaryAction: () => context.go('/today-class'),
      );
    }

    final status = appState.completionForStudent(s);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.push('/students/$studentId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
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
                        Expanded(
                          child: Text(
                            s.fullName.isEmpty ? 'Unnamed student' : s.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Email', value: s.email),
                    _InfoRow(label: 'Phone', value: s.phone),
                    _InfoRow(label: 'Student ID', value: s.studentId),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _ProgressRow(title: 'Adult checklist', status: _checklistStatus(s.adultChecklist)),
                    const SizedBox(height: 8),
                    _ProgressRow(title: 'Infant checklist', status: _checklistStatus(s.infantChecklist)),
                    const SizedBox(height: 8),
                    _ProgressRow(title: 'CCF evaluation', status: _decisionStatus(s.ccf.decision)),
                    const SizedBox(height: 8),
                    _ProgressRow(
                      title: 'Written test',
                      status: s.testScore.scorePercent == null
                          ? CompletionStatus.notStarted
                          : (s.testScore.decision == ChecklistDecision.notDecided
                              ? CompletionStatus.inProgress
                              : (s.testScore.isPass ? CompletionStatus.complete : CompletionStatus.needsReview)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Instructor notes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      s.notes.trim().isEmpty ? '—' : s.notes.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/students/$studentId/adult-checklist'),
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('Open Adult Checklist'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.push('/students/$studentId/infant-checklist'),
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('Open Infant Checklist'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/students/$studentId/ccf'),
              icon: const Icon(Icons.timer_rounded),
              label: const Text('Open CCF Evaluation'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/students/$studentId/test-score'),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Enter Test Score'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/students/$studentId/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Student'),
            ),
            const SizedBox(height: 10),
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

  CompletionStatus _decisionStatus(ChecklistDecision d) => switch (d) {
        ChecklistDecision.notDecided => CompletionStatus.notStarted,
        ChecklistDecision.pass => CompletionStatus.complete,
        ChecklistDecision.needsReview => CompletionStatus.needsReview,
      };

  CompletionStatus _checklistStatus(ChecklistAttempt a) {
    if (a.decision == ChecklistDecision.pass && a.reviewed) return CompletionStatus.complete;
    if (a.decision == ChecklistDecision.needsReview && a.reviewed) return CompletionStatus.needsReview;
    final anyTouched = a.ratings.values.any((r) => r != ChecklistRating.notEvaluated);
    return anyTouched ? CompletionStatus.inProgress : CompletionStatus.notStarted;
  }

  Future<void> _confirmRemove({required BuildContext context, required AppState appState, required Student student}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text('This removes ${student.fullName.isEmpty ? 'this student' : student.fullName} from the current class (temporary).'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    appState.removeStudent(student.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student removed (temporary).')));
    context.go('/today-class');
  }
}

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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.title, required this.status});

  final String title;
  final CompletionStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        StatusPill(status: status),
      ],
    );
  }
}
