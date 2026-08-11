import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/completion_evaluator.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/status_pill.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/student_picker_sheet.dart';

class TodayClassScreen extends StatefulWidget {
  const TodayClassScreen({super.key});

  @override
  State<TodayClassScreen> createState() => _TodayClassScreenState();
}

enum _RosterFilter { all, incomplete, remediation, complete }

class _TodayClassScreenState extends State<TodayClassScreen> {
  _RosterFilter _filter = _RosterFilter.all;

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

    final allStudents = appState.studentsForCurrentClass();
    final summary = appState.currentClassSummary();
    final readyCount = allStudents.where((s) => CompletionEvaluator.evaluateStudent(s: s, course: course) == CompletionStatus.complete).length;
    final remediationCount = allStudents.where((s) => CompletionEvaluator.evaluateStudent(s: s, course: course) == CompletionStatus.needsReview).length;
    final students = allStudents.where((s) {
      final status = CompletionEvaluator.evaluateStudent(s: s, course: course);
      return switch (_filter) {
        _RosterFilter.all => true,
        _RosterFilter.incomplete => status != CompletionStatus.complete,
        _RosterFilter.remediation => status == CompletionStatus.needsReview,
        _RosterFilter.complete => status == CompletionStatus.complete,
      };
    }).toList(growable: false);

    final date = '${course.classDate.month}/${course.classDate.day}/${course.classDate.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Class"),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/')),
        actions: [
          IconButton(tooltip: 'Reports', onPressed: () => context.push('/reports'), icon: const Icon(Icons.assessment_outlined)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TemporaryDataBanner(),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(course.className, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 2),
                                    Text('${course.courseType.label} • $date', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (summary != null) StatusPill(status: summary.overallStatus),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _ClassMetric(label: 'Ready', value: '$readyCount / ${allStudents.length}', icon: Icons.check_circle_outline_rounded)),
                              const SizedBox(width: 10),
                              Expanded(child: _ClassMetric(label: 'Remediation', value: '$remediationCount', icon: Icons.warning_amber_rounded)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: allStudents.isEmpty ? 0 : readyCount / allStudents.length),
                          const SizedBox(height: 6),
                          Text(
                            allStudents.isEmpty ? 'Add students to begin.' : '$readyCount of ${allStudents.length} students ready to complete.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: FilledButton.icon(onPressed: () => context.push('/students/new'), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Student'))),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/timer'), icon: const Icon(Icons.timer_rounded), label: const Text('Practice CCF'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_RosterFilter>(
                      segments: const [
                        ButtonSegment(value: _RosterFilter.all, label: Text('All')),
                        ButtonSegment(value: _RosterFilter.incomplete, label: Text('Incomplete')),
                        ButtonSegment(value: _RosterFilter.remediation, label: Text('Remediation')),
                        ButtonSegment(value: _RosterFilter.complete, label: Text('Complete')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) => setState(() => _filter = value.first),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: allStudents.isEmpty
                  ? _EmptyRoster(onAdd: () => context.push('/students/new'))
                  : students.isEmpty
                      ? const Center(child: Text('No students match this filter.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _StudentRow(student: students[index], course: course),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _TodayActionsBar(
        onChecklists: () => _openStudentAction(
          context: context,
          students: allStudents,
          emptyMessage: 'Add a student first to open checklists.',
          onEmptyAddStudent: () => context.push('/students/new'),
          title: 'Select student for checklists',
          onSelected: (s) => context.push('/students/${s.id}'),
        ),
        onCcfTimer: () => context.go('/timer'),
        onScores: () => _openStudentAction(
          context: context,
          students: allStudents,
          emptyMessage: 'Add a student first to enter written-test scores.',
          onEmptyAddStudent: () => context.push('/students/new'),
          title: 'Select student for written test',
          onSelected: (s) => context.push('/students/${s.id}/test-score'),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emptyMessage), action: SnackBarAction(label: 'Add student', onPressed: onEmptyAddStudent)));
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

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.course});

  final Student student;
  final CourseClass course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = CompletionEvaluator.evaluateStudent(s: student, course: course);
    final statuses = CompletionEvaluator.requirementStatuses(student: student, course: course);
    final total = statuses.length;
    final complete = statuses.values.where((s) => s == CompletionStatus.complete).length;
    final remaining = total - complete;
    final next = CompletionEvaluator.nextRequiredComponent(student: student, course: course);
    final remediations = CompletionEvaluator.remediationRequirements(student: student, course: course);

    final headline = status == CompletionStatus.complete
        ? 'Ready to Complete'
        : remediations.isNotEmpty
            ? 'Needs Remediation'
            : '$remaining ${remaining == 1 ? 'Item' : 'Items'} Remaining';

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
                  CircleAvatar(backgroundColor: cs.surfaceContainerHighest, child: Icon(Icons.person_outline, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.fullName.isEmpty ? 'Unnamed student' : student.fullName, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(headline, style: theme.textTheme.labelLarge?.copyWith(color: status == CompletionStatus.needsReview ? cs.error : cs.primary)),
                      ],
                    ),
                  ),
                  StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: total == 0 ? 0 : complete / total),
              const SizedBox(height: 6),
              Text('$complete of $total required items complete', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: statuses.entries.map((entry) => _MiniStatus(label: _shortLabel(entry.key), status: entry.value)).toList(growable: false),
              ),
              if (next != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push(_routeFor(student.id, next)),
                    icon: Icon(status == CompletionStatus.needsReview ? Icons.build_circle_outlined : Icons.arrow_forward_rounded),
                    label: Text(status == CompletionStatus.needsReview ? 'Open Remediation: ${next.label}' : 'Next Required: ${next.label}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortLabel(RequiredComponent c) => switch (c) {
        RequiredComponent.adultChecklist => 'Adult CPR',
        RequiredComponent.infantChecklist => 'Infant CPR',
        RequiredComponent.ccfEvaluation => 'CCF',
        RequiredComponent.writtenTest => 'Test',
      };

  String _routeFor(String id, RequiredComponent c) => switch (c) {
        RequiredComponent.adultChecklist => '/students/$id/adult-checklist',
        RequiredComponent.infantChecklist => '/students/$id/infant-checklist',
        RequiredComponent.ccfEvaluation => '/students/$id/ccf',
        RequiredComponent.writtenTest => '/students/$id/test-score',
      };
}

class _ClassMetric extends StatelessWidget {
  const _ClassMetric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.titleMedium), Text(label, style: Theme.of(context).textTheme.labelSmall)]))]),
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
            Text('Add students to track checklists, CCF evaluation, and test scores.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Student')),
          ],
        ),
      ),
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
              OutlinedButton.icon(onPressed: onChecklists, icon: const Icon(Icons.checklist_rounded), label: const Text('Checklists')),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: onCcfTimer, icon: const Icon(Icons.timer_rounded), label: const Text('Practice CCF')),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: onScores, icon: const Icon(Icons.score_rounded), label: const Text('Scores')),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: onReports, icon: const Icon(Icons.assessment_outlined), label: const Text('Reports')),
            ],
          ),
        ),
      ),
    );
  }
}
