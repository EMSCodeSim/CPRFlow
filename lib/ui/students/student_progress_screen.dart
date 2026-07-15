import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
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
  bool _loading = true;
  Object? _error;
  ClassRecord? _clazz;
  StudentRecord? _student;
  StudentCompletionResult? _completion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final services = AppScope.of(context);
    if (!services.hasClassData) {
      setState(() {
        _loading = false;
        _error = StateError('Class data disabled');
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await services.classRepository.getActiveClass();
      if (active == null) throw StateError('No active class');
      final student = await services.studentRepository.getById(widget.studentId);
      if (student == null) throw StateError('Student not found');
      final completion = await services.studentCompletionService.computeForStudent(clazz: active, student: student);
      if (!mounted) return;
      setState(() {
        _clazz = active;
        _student = student;
        _completion = completion;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('StudentProgress load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Student Progress')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? DatabaseErrorPanel(
                    title: 'Student could not be loaded',
                    message: 'Please retry.',
                    error: _error,
                    onRetry: _load,
                    onOpenRecovery: null,
                  )
                : _buildLoaded(context, scheme),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, ColorScheme scheme) {
    final student = _student!;
    final clazz = _clazz!;
    final completion = _completion!;

    String overall;
    Color overallColor;
    switch (completion.overallResult) {
      case OverallStudentResult.pass:
        overall = 'PASS';
        overallColor = scheme.primary;
        break;
      case OverallStudentResult.incomplete:
        overall = 'INCOMPLETE';
        overallColor = scheme.onSurface.withValues(alpha: 0.75);
        break;
      case OverallStudentResult.fail:
        overall = 'FAIL';
        overallColor = scheme.error;
        break;
    }

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
        _StatusCard(title: 'Adult Checklist', value: completion.adultStatus.name, scheme: scheme),
        const SizedBox(height: 10),
        _StatusCard(title: 'Infant/Child Checklist', value: completion.infantChildStatus.name, scheme: scheme),
        const SizedBox(height: 10),
        _StatusCard(title: 'CCF', value: completion.ccfStatus.name, scheme: scheme),
        const SizedBox(height: 10),
        _StatusCard(
          title: 'Written',
          value: clazz.writtenTestRequired ? (student.writtenTestScore == null ? 'Not entered' : '${student.writtenTestScore}${student.writtenTestingFinalized ? '' : ' (unfinalized)'}') : 'N/A',
          scheme: scheme,
        ),
        const SizedBox(height: 14),
        if (completion.missingRequirements.isNotEmpty)
          _ListCard(title: 'Missing requirements', items: completion.missingRequirements, scheme: scheme, icon: Icons.flag_outlined),
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
          child: FilledButton.icon(
            onPressed: () => context.push('/student/edit/${Uri.encodeComponent(student.id)}'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Student'),
          ),
        ),
      ],
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
          Text(value.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
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
