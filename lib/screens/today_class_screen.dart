import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/status_pill.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/student_picker_sheet.dart';

class TodayClassScreen extends StatelessWidget {
  const TodayClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final course = appState.currentClass;
    if (course == null) {
      return SafeErrorScreen(
        title: 'No active class',
        message: 'Create a class to manage students, checklists, CCF evaluation, and test scores.',
        primaryActionLabel: 'Start New Class',
        onPrimaryAction: () => context.go('/new-class'),
      );
    }

    final students = appState.studentsForCurrentClass();
    final summary = appState.currentClassSummary();
    final date = '${course.classDate.month}/${course.classDate.day}/${course.classDate.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Class"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            tooltip: 'Reports',
            onPressed: () => context.push('/reports'),
            icon: const Icon(Icons.assessment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TemporaryDataBanner(),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(course.className, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  '${course.courseType.label} • $date',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Location: ${course.location.isEmpty ? '—' : course.location}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (summary != null) StatusPill(status: summary.overallStatus),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/students/new'),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Add Student'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/timer'),
                          icon: const Icon(Icons.timer_rounded),
                          label: const Text('Practice CCF Timer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? _EmptyRoster(onAdd: () => context.push('/students/new'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = students[index];
                        final status = appState.completionForStudent(s);
                        return _StudentRow(student: s, status: status);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _TodayActionsBar(
        onChecklists: () {
          _openStudentAction(
            context: context,
            students: students,
            emptyMessage: 'Add a student first to open checklists.',
            onEmptyAddStudent: () => context.push('/students/new'),
            title: 'Select student for checklists',
            onSelected: (s) => context.push('/students/${s.id}'),
          );
        },
        onCcfTimer: () => context.go('/timer'),
        onScores: () {
          _openStudentAction(
            context: context,
            students: students,
            emptyMessage: 'Add a student first to enter written-test scores.',
            onEmptyAddStudent: () => context.push('/students/new'),
            title: 'Select student for written test',
            onSelected: (s) => context.push('/students/${s.id}/test-score'),
          );
        },
        onReports: () => context.push('/reports'),
      ),
    );
  }

  Future<void> _openStudentAction({
    required BuildContext context,
    required List<Student> students,
    required String emptyMessage,
    required VoidCallback onEmptyAddStudent,
    required String title,
    required void Function(Student s) onSelected,
  }) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emptyMessage),
          action: SnackBarAction(label: 'Add student', onPressed: onEmptyAddStudent),
        ),
      );
      return;
    }

    if (students.length == 1) {
      onSelected(students.first);
      return;
    }

    final selected = await showModalBottomSheet<Student?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StudentPickerSheet(title: title, students: students),
    );
    if (selected == null || !context.mounted) return;
    onSelected(selected);
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('No students yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Add students to track checklists, CCF evaluation, and test scores.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Student'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.status});

  final Student student;
  final CompletionStatus status;

  CompletionStatus _statusFromDecision(ChecklistDecision d) => switch (d) {
        ChecklistDecision.notDecided => CompletionStatus.notStarted,
        ChecklistDecision.pass => CompletionStatus.complete,
        ChecklistDecision.needsReview => CompletionStatus.needsReview,
      };

  CompletionStatus _checklistProgress(ChecklistAttempt a) {
    if (a.decision == ChecklistDecision.pass && a.reviewed) return CompletionStatus.complete;
    if (a.decision == ChecklistDecision.needsReview && a.reviewed) return CompletionStatus.needsReview;
    final anyTouched = a.ratings.values.any((r) => r != ChecklistRating.notEvaluated);
    return anyTouched ? CompletionStatus.inProgress : CompletionStatus.notStarted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/students/${student.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.fullName.isEmpty ? 'Unnamed student' : student.fullName, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          student.email.isEmpty ? '—' : student.email,
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStatus(label: 'Adult', status: _checklistProgress(student.adultChecklist)),
                  _MiniStatus(label: 'Infant', status: _checklistProgress(student.infantChecklist)),
                  _MiniStatus(label: 'CCF', status: _statusFromDecision(student.ccf.decision)),
                  _MiniStatus(
                    label: 'Test',
                    status: student.testScore.scorePercent == null
                        ? CompletionStatus.notStarted
                        : (student.testScore.decision == ChecklistDecision.notDecided
                            ? CompletionStatus.inProgress
                            : (student.testScore.isPass ? CompletionStatus.complete : CompletionStatus.needsReview)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label, required this.status});

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
      child: Text('$label: ${status.label}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

class _TodayActionsBar extends StatelessWidget {
  const _TodayActionsBar({required this.onChecklists, required this.onCcfTimer, required this.onScores, required this.onReports});

  final VoidCallback onChecklists;
  final VoidCallback onCcfTimer;
  final VoidCallback onScores;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: onChecklists,
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Checklists'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onCcfTimer,
                icon: const Icon(Icons.timer_rounded),
                label: const Text('Practice CCF Timer'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onScores,
                icon: const Icon(Icons.score_rounded),
                label: const Text('Scores'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onReports,
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Reports'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
