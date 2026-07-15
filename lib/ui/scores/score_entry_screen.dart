import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_dismiss.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_safe_save_bar.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScoreEntryScreen extends StatefulWidget {
  const ScoreEntryScreen({super.key});

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  bool _saving = false;
  Object? _saveError;

  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(StudentRecord s) {
    return _controllers.putIfAbsent(s.id, () => TextEditingController(text: s.writtenTestScore?.toString() ?? ''));
  }

  int? _parseScore(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return v;
  }

  String? _validateScore(int? v) {
    if (v == null) return null;
    if (v < 0 || v > 100) return '0–100 only';
    return null;
  }

  Future<void> _saveAll(ClassRecord clazz, List<StudentRecord> students) async {
    final services = AppScope.of(context);
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final updates = <String, int?>{};
      for (final s in students) {
        final parsed = _parseScore(_controllerFor(s).text);
        final err = _validateScore(parsed);
        if (err != null) throw StateError('Invalid score for ${s.displayName}: $err');
        updates[s.id] = parsed;
      }
      await services.scoreRepository.saveMultipleScores(scoresByStudentId: updates);
    } catch (e, st) {
      debugPrint('Save scores failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = null;
    });
  }

  Future<void> _markEnteredFinalized(ClassRecord clazz) async {
    final services = AppScope.of(context);
    try {
      await services.scoreRepository.markEnteredScoresFinalizedForClass(clazz.id);
    } catch (e, st) {
      debugPrint('Finalize scores failed: $e\n$st');
    }
  }

  Future<void> _clearScoreWithConfirm(StudentRecord s) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clear score?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('This will remove the written score for ${s.displayName}.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => context.pop(false), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: () => context.pop(true), child: const Text('Clear'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await AppScope.of(context).scoreRepository.clearScore(studentId: s.id);
    _controllerFor(s).text = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!services.hasClassData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scores')),
        body: const SafeArea(child: Center(child: Text('Class data is disabled in recovery mode.'))),
      );
    }

    return KeyboardDismiss(
      child: Scaffold(
        appBar: AppBar(title: const Text('Scores')),
        body: SafeArea(
          child: StreamBuilder<ClassRecord?>(
            stream: services.classRepository.watchActiveClass(),
            builder: (context, classSnap) {
              if (classSnap.hasError) {
                return DatabaseErrorPanel(title: 'Class could not be loaded', message: 'Please retry.', error: classSnap.error, onRetry: () {}, onOpenRecovery: null);
              }
              final clazz = classSnap.data;
              if (clazz == null) return const Center(child: Text('No active class.'));

              return StreamBuilder<List<StudentRecord>>(
                stream: services.scoreRepository.watchClassScores(clazz.id),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return DatabaseErrorPanel(title: 'Scores could not be loaded', message: 'Please retry.', error: snap.error, onRetry: () {}, onOpenRecovery: null);
                  }
                  final students = snap.data ?? const [];
                  final required = clazz.writtenTestRequired;
                  final threshold = clazz.passingScore ?? 0;

                  return Stack(
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final s = students[index];
                          final controller = _controllerFor(s);
                          final score = _parseScore(controller.text);
                          final validation = _validateScore(score);
                          String status;
                          Color statusColor;

                          if (!required) {
                            status = 'N/A';
                            statusColor = scheme.onSurface.withValues(alpha: 0.7);
                          } else if (score == null) {
                            status = 'INCOMPLETE';
                            statusColor = scheme.onSurface.withValues(alpha: 0.75);
                          } else if (!s.writtenTestingFinalized) {
                            status = 'INCOMPLETE';
                            statusColor = scheme.onSurface.withValues(alpha: 0.75);
                          } else if (score >= threshold) {
                            status = 'PASSED';
                            statusColor = scheme.primary;
                          } else {
                            status = 'FAILED';
                            statusColor = scheme.error;
                          }

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
                                    Expanded(child: Text(s.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                                    Text(status, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: statusColor)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Score (0–100)',
                                          errorText: validation,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      children: [
                                        Switch(
                                          value: s.writtenTestingFinalized,
                                          onChanged: required && score != null
                                              ? (v) => services.scoreRepository.markScoreFinalized(studentId: s.id, finalized: v)
                                              : null,
                                        ),
                                        Text('Finalized', style: Theme.of(context).textTheme.labelMedium),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _clearScoreWithConfirm(s),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Clear'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_saveError != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 84,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: scheme.errorContainer.withValues(alpha: 0.35),
                              border: Border.all(color: scheme.error.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sync_problem_outlined, color: scheme.error),
                                const SizedBox(width: 10),
                                const Expanded(child: Text('Save failed. You can retry.')),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: required ? () => _markEnteredFinalized(clazz) : null,
                                      icon: const Icon(Icons.verified_outlined),
                                      label: const Text('Mark Entered Scores Finalized'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            KeyboardSafeSaveBar(
                              isSaving: _saving,
                              saveLabel: 'Save All',
                              onSave: () => _saveAll(clazz, students),
                              isEnabled: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
