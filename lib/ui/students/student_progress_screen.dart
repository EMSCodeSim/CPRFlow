import 'dart:async';

import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/coordinators/student_progress_coordinator.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({super.key, required this.studentId});
  final String studentId;

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  StudentProgressCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_coordinator != null) return;
    final services = AppScope.of(context);
    if (!services.hasClassData) return;
    _coordinator = StudentProgressCoordinator(
      db: services.database!,
      completionService: services.studentCompletionService,
      studentId: widget.studentId,
    )..startWatching();
  }

  @override
  void dispose() {
    unawaited(_coordinator?.dispose());
    super.dispose();
  }

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
    final services = AppScope.of(context);

    if (!services.hasClassData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Progress')),
        body: const SafeArea(child: Center(child: Text('Class data is disabled in recovery mode.'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Student Progress')),
      body: SafeArea(
        child: StreamBuilder<StudentProgressViewModel>(
          stream: _coordinator?.stream,
          initialData: _coordinator?.latest,
          builder: (context, snap) {
            final vm = snap.data;
            if (snap.hasError) {
              return DatabaseErrorPanel(title: 'Progress could not be loaded', message: 'Please retry.', error: snap.error, onRetry: () => context.go('${AppRoutes.studentProgress}/${Uri.encodeComponent(widget.studentId)}'), onOpenRecovery: null);
            }
            if (vm == null) return const Center(child: CircularProgressIndicator());
            if (vm.calculationError != null) {
              if (vm.calculationError is StateError && vm.calculationError.toString().contains('does not belong')) {
                return SafeErrorScreen(
                  title: 'Student mismatch',
                  message: 'This student does not belong to the active class.',
                  details: vm.calculationError.toString(),
                  onRetryLocation: AppRoutes.today,
                );
              }
              return DatabaseErrorPanel(title: 'Progress could not be calculated', message: 'Please retry.', error: vm.calculationError, onRetry: () => context.go('${AppRoutes.studentProgress}/${Uri.encodeComponent(widget.studentId)}'), onOpenRecovery: null);
            }

            final clazz = vm.classRecord;
            final student = vm.student;
            final completion = vm.completion;
            if (clazz == null || student == null || completion == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final scheme = Theme.of(context).colorScheme;
            final overall = _overallLabel(completion.overallResult);
            final overallColor = completion.overallResult == OverallStudentResult.pass
                ? scheme.primary
                : (completion.overallResult == OverallStudentResult.fail ? scheme.error : scheme.onSurface.withValues(alpha: 0.75));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      if ((student.email ?? '').trim().isNotEmpty) Text(student.email!.trim()),
                      if ((student.phone ?? '').trim().isNotEmpty) Text(student.phone!.trim()),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Overall:', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75))),
                          const SizedBox(width: 10),
                          Text(overall, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: overallColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StatusCard(title: 'Adult Checklist', value: completion.adultStatus.label, scheme: scheme),
                const SizedBox(height: 10),
                _StatusCard(title: 'Infant/Child Checklist', value: completion.infantChildStatus.label, scheme: scheme),
                const SizedBox(height: 10),
                _StatusCard(title: 'CCF', value: completion.ccfStatus.label, scheme: scheme),
                const SizedBox(height: 10),
                _StatusCard(
                  title: 'Written',
                  value: clazz.writtenTestRequired
                      ? (student.writtenTestScore == null
                          ? 'Not Entered'
                          : (student.writtenTestingFinalized ? '${student.writtenTestScore}' : '${student.writtenTestScore} (Unfinalized)'))
                      : 'N/A',
                  scheme: scheme,
                ),
                if (completion.validationWarnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ListCard(title: 'Validation warnings', items: completion.validationWarnings, scheme: scheme, icon: Icons.warning_amber_outlined),
                ],
                const SizedBox(height: 14),
                if (completion.missingRequirements.isNotEmpty) _ListCard(title: 'Missing requirements', items: completion.missingRequirements, scheme: scheme, icon: Icons.flag_outlined),
                if (completion.failureReasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ListCard(title: 'Failure reasons', items: completion.failureReasons, scheme: scheme, icon: Icons.error_outline),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push('${AppRoutes.checklist}/${Uri.encodeComponent(student.id)}?type=${ChecklistType.adult.name}'),
                        icon: const Icon(Icons.checklist_outlined),
                        label: const Text('Adult Checklist'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('${AppRoutes.checklist}/${Uri.encodeComponent(student.id)}?type=${ChecklistType.infantChild.name}'),
                        icon: const Icon(Icons.checklist_outlined),
                        label: const Text('Infant/Child'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('${AppRoutes.studentCcf}/${Uri.encodeComponent(student.id)}'),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Start / View CCF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.scores),
                        icon: const Icon(Icons.score_outlined),
                        label: const Text('Enter Score'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('${AppRoutes.classDocuments}?classId=${Uri.encodeComponent(clazz.id)}&studentId=${Uri.encodeComponent(student.id)}'),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Student Documents'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/student/edit/${Uri.encodeComponent(student.id)}'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Student'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.value, required this.scheme});
  final String title;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.items, required this.scheme, required this.icon});
  final String title;
  final List<String> items;
  final ColorScheme scheme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e', style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
              )),
        ],
      ),
    );
  }
}
