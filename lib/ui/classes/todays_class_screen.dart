import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/coordinators/todays_class_coordinator.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/classes/todays_class_view_model.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
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
  TodaysClassCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_coordinator != null) return;

    final services = AppScope.of(context);
    final db = services.database;
    if (db == null) return;
    _coordinator = TodaysClassCoordinator(db: db, completionService: services.studentCompletionService)..startWatching();
  }

  @override
  void dispose() {
    _coordinator?.dispose();
    super.dispose();
  }

  bool _matchesFilter(ClassRecord clazz, StudentProgressRow row) {
    final r = row.completion;
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
        return r.overallResult == OverallStudentResult.incomplete || row.calculationError != null;
      case _RosterFilter.failed:
        return r.overallResult == OverallStudentResult.fail;
      case _RosterFilter.passed:
        return row.calculationError == null && r.overallResult == OverallStudentResult.pass;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!services.hasClassData) {
      return Scaffold(
        appBar: AppBar(title: const Text("Today's Class")),
        body: const SafeArea(child: Center(child: Text('Class data is disabled in recovery mode.'))),
      );
    }

    final coordinator = _coordinator;
    if (coordinator == null) {
      return const Scaffold(body: SafeArea(child: Center(child: CircularProgressIndicator())));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Class")),
      body: SafeArea(
        child: StreamBuilder<TodaysClassViewModel?>(
          stream: coordinator.stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return DatabaseErrorPanel(
                title: 'Today\'s Class could not be loaded',
                message: 'Please retry. If this persists, restart into recovery mode.',
                error: snap.error,
                onRetry: () => coordinator.requestRecompute(),
                onOpenRecovery: null,
              );
            }

            final vm = snap.data;
            if (vm == null) {
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

            final clazz = vm.classRecord;
            final allRows = vm.students;
            final filtered = allRows.where((r) => _matchesFilter(clazz, r)).toList(growable: false);

            return Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _ClassHeader(clazz: clazz, totalStudents: vm.totalStudents)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _SummaryCards(passed: vm.passedCount, incomplete: vm.incompleteCount, failed: vm.failedCount)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _FilterChips(value: _filter, onChanged: (v) => setState(() => _filter = v))),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('No students match this filter', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == filtered.length) {
                              return OutlinedButton.icon(
                                onPressed: () => context.push(AppRoutes.studentAdd),
                                icon: const Icon(Icons.person_add_alt_1_outlined),
                                label: const Text('Add Student'),
                              );
                            }
                            final row = filtered[index];
                            return _StudentProgressCard(
                              clazz: clazz,
                              row: row,
                              onTap: () => context.push('${AppRoutes.studentProgress}/${Uri.encodeComponent(row.student.id)}'),
                              onRetryCalc: coordinator.requestRecompute,
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
              Expanded(child: OutlinedButton.icon(onPressed: () => context.push(AppRoutes.ccfTimer), icon: const Icon(Icons.timer_outlined), label: const Text('CCF'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => context.push(AppRoutes.scores), icon: const Icon(Icons.score_outlined), label: const Text('Scores'))),
            ],
          ),
        ),
      ),
    );
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
                            ListTile(leading: const Icon(Icons.checklist_outlined), title: const Text('Adult Checklist'), onTap: () => context.pop(ChecklistType.adult)),
                            ListTile(leading: const Icon(Icons.checklist_outlined), title: const Text('Infant/Child Checklist'), onTap: () => context.pop(ChecklistType.infantChild)),
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
  const _ClassHeader({required this.clazz, required this.totalStudents});

  final ClassRecord clazz;
  final int totalStudents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final date = clazz.classDate == null ? '—' : loc.formatMediumDate(clazz.classDate!);
    final time = (clazz.startTime == null || clazz.endTime == null)
        ? '—'
        : '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(clazz.startTime!))}–${loc.formatTimeOfDay(TimeOfDay.fromDateTime(clazz.endTime!))}';

    final rows = <String, String>{
      'Course': clazz.courseType == CourseType.blsProvider ? 'BLS Provider' : 'Course',
      'Date': date,
      'Time': time,
      if ((clazz.location ?? '').trim().isNotEmpty) 'Location': clazz.location!.trim(),
      if ((clazz.leadInstructor ?? '').trim().isNotEmpty) 'Lead': clazz.leadInstructor!.trim(),
      if ((clazz.additionalInstructor ?? '').trim().isNotEmpty) 'Additional': clazz.additionalInstructor!.trim(),
      if ((clazz.trainingCenter ?? '').trim().isNotEmpty) 'Training Center': clazz.trainingCenter!.trim(),
      'Students': '$totalStudents',
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
                  SizedBox(width: 130, child: Text(e.key, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)))),
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

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.passed, required this.incomplete, required this.failed});
  final int passed;
  final int incomplete;
  final int failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: _SummaryCard(title: 'Passed', value: '$passed', icon: Icons.verified_outlined, scheme: scheme, tone: scheme.primary)),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Incomplete', value: '$incomplete', icon: Icons.more_horiz, scheme: scheme, tone: scheme.onSurface.withValues(alpha: 0.75))),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Failed', value: '$failed', icon: Icons.error_outline, scheme: scheme, tone: scheme.error)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.scheme, required this.tone});
  final String title;
  final String value;
  final IconData icon;
  final ColorScheme scheme;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75))),
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
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: v == value,
        label: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(label, overflow: TextOverflow.ellipsis)),
        onSelected: (_) => onChanged(v),
      ),
    );
  }
}

class _StudentProgressCard extends StatelessWidget {
  const _StudentProgressCard({required this.clazz, required this.row, required this.onTap, required this.onRetryCalc});
  final ClassRecord clazz;
  final StudentProgressRow row;
  final VoidCallback onTap;
  final VoidCallback onRetryCalc;

  String _overallLabel(OverallStudentResult r) {
    switch (r) {
      case OverallStudentResult.pass:
        return 'PASS';
      case OverallStudentResult.incomplete:
        return 'INCOMPLETE';
      case OverallStudentResult.fail:
        return 'FAIL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completion = row.completion;

    final overall = row.calculationError != null ? 'INCOMPLETE' : _overallLabel(completion.overallResult);
    final overallColor = overall == 'PASS'
        ? scheme.primary
        : (overall == 'FAIL' ? scheme.error : scheme.onSurface.withValues(alpha: 0.75));

    String ccfLabel;
    if (!clazz.ccfRequired) {
      ccfLabel = completion.ccfStatus == RequirementStatus.notRequired ? 'N/A' : completion.ccfStatus.label;
    } else {
      ccfLabel = completion.ccfStatus.label;
    }

    String writtenLabel;
    if (!clazz.writtenTestRequired) {
      writtenLabel = 'N/A';
    } else {
      writtenLabel = row.writtenScoreDisplay;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(row.student.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                Text(overall, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: overallColor)),
              ],
            ),
            const SizedBox(height: 10),
            _MiniStatusRow(label: 'Adult', value: completion.adultStatus.label),
            _MiniStatusRow(label: 'Infant/Child', value: completion.infantChildStatus.label),
            _MiniStatusRow(label: 'CCF', value: ccfLabel),
            _MiniStatusRow(label: 'Written', value: writtenLabel),
            if (row.calculationError != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: scheme.error, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Progress could not be calculated')),
                  TextButton(onPressed: onRetryCalc, child: const Text('Retry')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStatusRow extends StatelessWidget {
  const _MiniStatusRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
