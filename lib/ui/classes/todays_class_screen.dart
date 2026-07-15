import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _RosterFilter { all, missingAdult, missingInfant, missingCcf, missingScore, incomplete, failed, passed }

class TodaysClassScreen extends StatefulWidget {
  const TodaysClassScreen({super.key});

  @override
  State<TodaysClassScreen> createState() => _TodaysClassScreenState();
}

class _TodaysClassScreenState extends State<TodaysClassScreen> {
  _RosterFilter _filter = _RosterFilter.all;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!services.hasClassData) {
      return Scaffold(
        appBar: AppBar(title: const Text("Today's Class")),
        body: const SafeArea(
          child: Center(child: Text('Class data is disabled in recovery mode.')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Class")),
      body: SafeArea(
        child: StreamBuilder<ClassRecord?>(
          stream: services.classRepository.watchActiveClass(),
          builder: (context, classSnap) {
            if (classSnap.hasError) {
              return DatabaseErrorPanel(
                title: 'Class could not be loaded',
                message: 'Please retry. If this persists, restart into recovery mode.',
                error: classSnap.error,
                onRetry: () => context.go(AppRoutes.today),
                onOpenRecovery: null,
              );
            }
            final clazz = classSnap.data;
            if (clazz == null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 54, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text('No active class', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Return to Home to create or activate a class.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 14),
                    FilledButton.icon(onPressed: () => context.go(AppRoutes.home), icon: const Icon(Icons.home_outlined), label: const Text('Home')),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _ClassHeader(clazz: clazz),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _FilterChips(value: _filter, onChanged: (v) => setState(() => _filter = v)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<StudentRecord>>(
                    stream: services.studentRepository.watchStudentsForClass(clazz.id),
                    builder: (context, studentSnap) {
                      if (studentSnap.hasError) {
                        return DatabaseErrorPanel(
                          title: 'Students could not be loaded',
                          message: 'Please retry.',
                          error: studentSnap.error,
                          onRetry: () => context.go(AppRoutes.today),
                          onOpenRecovery: null,
                        );
                      }
                      final students = studentSnap.data ?? const [];
                      if (students.isEmpty) {
                        return Center(
                          child: Text('No students yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: students.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == students.length) {
                            return OutlinedButton.icon(
                              onPressed: () => context.push(AppRoutes.studentAdd),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Add Student'),
                            );
                          }
                          final s = students[index];
                          return FutureBuilder<StudentCompletionResult>(
                            future: services.studentCompletionService.computeForStudent(clazz: clazz, student: s),
                            builder: (context, completionSnap) {
                              if (completionSnap.hasError) {
                                debugPrint('Completion calc failed: ${completionSnap.error}');
                              }
                              final completion = completionSnap.data;
                              if (completion != null && !_matchesFilter(clazz, s, completion)) {
                                return const SizedBox.shrink();
                              }
                              return _StudentRow(
                                student: s,
                                completion: completion,
                                onTap: () => context.push('${AppRoutes.studentProgress}/${Uri.encodeComponent(s.id)}'),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openChecklistChooser(context),
                  icon: const Icon(Icons.checklist_outlined),
                  label: const Text('Checklists'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.ccfTimer),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('CCF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.scores),
                  icon: const Icon(Icons.score_outlined),
                  label: const Text('Scores'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(ClassRecord clazz, StudentRecord s, StudentCompletionResult r) {
    switch (_filter) {
      case _RosterFilter.all:
        return true;
      case _RosterFilter.missingAdult:
        return r.adultStatus != ChecklistStatus.passed;
      case _RosterFilter.missingInfant:
        return r.infantChildStatus != ChecklistStatus.passed;
      case _RosterFilter.missingCcf:
        return clazz.ccfRequired && r.ccfStatus != RequirementStatus.passed;
      case _RosterFilter.missingScore:
        return clazz.writtenTestRequired && r.writtenTestStatus != RequirementStatus.passed;
      case _RosterFilter.incomplete:
        return r.overallResult == OverallStudentResult.incomplete;
      case _RosterFilter.failed:
        return r.overallResult == OverallStudentResult.fail;
      case _RosterFilter.passed:
        return r.overallResult == OverallStudentResult.pass;
    }
  }

  Future<void> _openChecklistChooser(BuildContext context) async {
    final services = AppScope.of(context);
    final active = await services.classRepository.getActiveClass();
    if (active == null) return;
    final students = await services.studentRepository.watchStudentsForClass(active.id).first;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: students.length,
            itemBuilder: (context, index) {
              final s = students[index];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(s.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  context.pop();
                  final which = await showModalBottomSheet<ChecklistType>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.checklist_outlined),
                              title: const Text('Adult Checklist'),
                              onTap: () => context.pop(ChecklistType.adult),
                            ),
                            ListTile(
                              leading: const Icon(Icons.checklist_outlined),
                              title: const Text('Infant/Child Checklist'),
                              onTap: () => context.pop(ChecklistType.infantChild),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (which == null) return;
                  if (!mounted) return;
                  context.push('${AppRoutes.checklist}/${Uri.encodeComponent(s.id)}?type=${which.name}');
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.clazz});

  final ClassRecord clazz;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final date = clazz.classDate == null ? '—' : loc.formatMediumDate(clazz.classDate!);
    final time = (clazz.startTime == null || clazz.endTime == null) ? '—' : '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(clazz.startTime!))}–${loc.formatTimeOfDay(TimeOfDay.fromDateTime(clazz.endTime!))}';

    final rows = <String, String>{
      'Course': clazz.courseType == CourseType.blsProvider ? 'BLS Provider' : 'Course',
      'Date': date,
      'Time': time,
      if ((clazz.location ?? '').trim().isNotEmpty) 'Location': clazz.location!.trim(),
      if ((clazz.leadInstructor ?? '').trim().isNotEmpty) 'Lead': clazz.leadInstructor!.trim(),
      if ((clazz.additionalInstructor ?? '').trim().isNotEmpty) 'Additional': clazz.additionalInstructor!.trim(),
      if ((clazz.trainingCenter ?? '').trim().isNotEmpty) 'Training Center': clazz.trainingCenter!.trim(),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clazz.className, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...rows.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(e.key, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)))),
                  Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final _RosterFilter value;
  final ValueChanged<_RosterFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, _RosterFilter.all, 'All'),
          _chip(context, _RosterFilter.missingAdult, 'Missing Adult'),
          _chip(context, _RosterFilter.missingInfant, 'Missing Infant'),
          _chip(context, _RosterFilter.missingCcf, 'Missing CCF'),
          _chip(context, _RosterFilter.missingScore, 'Missing Score'),
          _chip(context, _RosterFilter.incomplete, 'Incomplete'),
          _chip(context, _RosterFilter.failed, 'Failed'),
          _chip(context, _RosterFilter.passed, 'Passed'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, _RosterFilter v, String label) {
    final selected = v == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: selected,
        label: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(label, overflow: TextOverflow.ellipsis)),
        onSelected: (_) => onChanged(v),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.completion, required this.onTap});

  final StudentRecord student;
  final StudentCompletionResult? completion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = completion;
    String statusText;
    Color statusColor;
    if (c == null) {
      statusText = 'Loading…';
      statusColor = scheme.onSurface.withValues(alpha: 0.65);
    } else {
      switch (c.overallResult) {
        case OverallStudentResult.pass:
          statusText = 'PASS';
          statusColor = scheme.primary;
          break;
        case OverallStudentResult.incomplete:
          statusText = 'INCOMPLETE';
          statusColor = scheme.onSurface.withValues(alpha: 0.75);
          break;
        case OverallStudentResult.fail:
          statusText = 'FAIL';
          statusColor = scheme.error;
          break;
      }
    }

    final scoreText = c == null
        ? '—'
        : (student.writtenTestScore == null
            ? 'Not entered'
            : '${student.writtenTestScore}${student.writtenTestingFinalized ? '' : ' (unfinalized)'}');

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      leading: const Icon(Icons.person_outline),
      title: Text(student.displayName),
      subtitle: Text('Score: $scoreText'),
      trailing: Text(statusText, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: statusColor)),
    );
  }
}
