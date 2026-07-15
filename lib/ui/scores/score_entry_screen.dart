import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/score_repository.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:cpr_instructor_doc/domain/scores/score_edit_state.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_dismiss.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_safe_save_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScoreEntryScreen extends StatefulWidget {
  const ScoreEntryScreen({super.key});

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  bool _savingAll = false;
  Object? _saveAllError;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, ScoreEditState> _states = {};

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
    return int.tryParse(t);
  }

  String? _validateScore(int? v) {
    if (v == null) return null;
    if (v < 0 || v > 100) return '0–100 only';
    return null;
  }

  ScoreEditState _stateFor(StudentRecord s) {
    return _states.putIfAbsent(
      s.id,
      () {
        final raw = s.writtenTestScore?.toString() ?? '';
        return ScoreEditState(
          studentId: s.id,
          originalScore: s.writtenTestScore,
          draftScore: s.writtenTestScore,
          originalFinalized: s.writtenTestingFinalized,
          draftFinalized: s.writtenTestingFinalized,
          rawDraft: raw,
          validationError: _validateScore(s.writtenTestScore),
          isDirty: false,
          isSaving: false,
          saveError: null,
        );
      },
    );
  }

  void _reconcileFromDb(List<StudentRecord> students) {
    for (final s in students) {
      final controller = _controllerFor(s);
      final existing = _states[s.id];
      if (existing == null) {
        _stateFor(s);
        continue;
      }
      if (existing.isDirty || existing.isSaving) continue;

      final raw = s.writtenTestScore?.toString() ?? '';
      if (controller.text != raw) controller.text = raw;
      _states[s.id] = existing.copyWith(
        originalScore: s.writtenTestScore,
        draftScore: s.writtenTestScore,
        originalFinalized: s.writtenTestingFinalized,
        draftFinalized: s.writtenTestingFinalized,
        rawDraft: raw,
        validationError: _validateScore(s.writtenTestScore),
        isDirty: false,
        isSaving: false,
        saveError: null,
      );
    }
  }

  String _statusLabel({required bool required, required int? draftScore, required bool draftFinalized, required int threshold}) {
    if (!required) return 'N/A';
    if (draftScore == null) return 'INCOMPLETE';
    if (!draftFinalized) return 'INCOMPLETE';
    return draftScore >= threshold ? 'PASSED' : 'FAILED';
  }

  Color _statusColor(ColorScheme scheme, String status) {
    switch (status) {
      case 'PASSED':
        return scheme.primary;
      case 'FAILED':
        return scheme.error;
      default:
        return scheme.onSurface.withValues(alpha: 0.75);
    }
  }

  Future<void> _saveAll(ClassRecord clazz, List<StudentRecord> students) async {
    final services = AppScope.of(context);
    setState(() {
      _savingAll = true;
      _saveAllError = null;
    });

    try {
      final updates = <ScoreStateUpdate>[];
      for (final s in students) {
        final st = _stateFor(s);
        if (clazz.writtenTestRequired) {
          final err = _validateScore(st.draftScore);
          if (err != null) throw StateError('Invalid score for ${s.displayName}: $err');
        }
        updates.add(ScoreStateUpdate(studentId: s.id, score: st.draftScore, finalized: st.draftFinalized));
      }
      await services.scoreRepository.saveClassScoreStates(updates: updates);

      if (!mounted) return;
      setState(() {
        for (final u in updates) {
          final cur = _states[u.studentId];
          if (cur == null) continue;
          _states[u.studentId] = cur.copyWith(
            originalScore: u.score,
            draftScore: u.score,
            originalFinalized: u.finalized,
            draftFinalized: u.finalized,
            isDirty: false,
            isSaving: false,
            saveError: null,
          );
        }
        _savingAll = false;
      });
    } catch (e, st) {
      debugPrint('Save scores failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _savingAll = false;
        _saveAllError = e;
      });
    }
  }

  Future<void> _markEnteredFinalized(ClassRecord clazz, List<StudentRecord> students) async {
    if (!clazz.writtenTestRequired) return;
    final services = AppScope.of(context);

    for (final s in students) {
      final st = _stateFor(s);
      if (st.rawDraft.trim().isEmpty) continue;
      final err = _validateScore(st.draftScore);
      if (err != null) {
        setState(() => _states[s.id] = st.copyWith(validationError: err));
        return;
      }
    }

    final updates = <ScoreStateUpdate>[];
    for (final s in students) {
      final st = _stateFor(s);
      final hasScore = st.draftScore != null;
      updates.add(ScoreStateUpdate(studentId: s.id, score: st.draftScore, finalized: hasScore));
    }

    try {
      await services.scoreRepository.saveClassScoreStates(updates: updates);
      if (!mounted) return;
      setState(() {
        for (final u in updates) {
          final cur = _states[u.studentId];
          if (cur == null) continue;
          _states[u.studentId] = cur.copyWith(
            originalScore: u.score,
            draftScore: u.score,
            originalFinalized: u.finalized,
            draftFinalized: u.finalized,
            isDirty: false,
            isSaving: false,
            saveError: null,
          );
        }
      });
    } catch (e, st) {
      debugPrint('Finalize entered scores failed: $e\n$st');
      if (!mounted) return;
      setState(() => _saveAllError = e);
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

    final services = AppScope.of(context);
    final st = _stateFor(s);
    setState(() => _states[s.id] = st.copyWith(isSaving: true, saveError: null));
    try {
      await services.scoreRepository.saveScoreState(studentId: s.id, score: null, finalized: false);
      if (!mounted) return;
      _controllerFor(s).text = '';
      setState(() {
        _states[s.id] = st.copyWith(
          originalScore: null,
          draftScore: null,
          originalFinalized: false,
          draftFinalized: false,
          rawDraft: '',
          validationError: null,
          isDirty: false,
          isSaving: false,
          saveError: null,
        );
      });
    } catch (e, st2) {
      debugPrint('Clear score failed: $e\n$st2');
      if (!mounted) return;
      setState(() => _states[s.id] = st.copyWith(isSaving: false, saveError: e));
    }
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
        appBar: AppBar(
          title: const Text('Scores'),
          actions: [
            IconButton(onPressed: () => FocusManager.instance.primaryFocus?.unfocus(), tooltip: 'Hide keyboard', icon: const Icon(Icons.keyboard_hide_outlined)),
          ],
        ),
        body: SafeArea(
          child: StreamBuilder<ClassRecord?>(
            stream: services.classRepository.watchActiveClass(),
            builder: (context, classSnap) {
              if (classSnap.hasError) {
                return DatabaseErrorPanel(title: 'Class could not be loaded', message: 'Please retry.', error: classSnap.error, onRetry: () {}, onOpenRecovery: null);
              }
              final clazz = classSnap.data;
              if (clazz == null) return const Center(child: Text('No active class.'));

              final required = clazz.writtenTestRequired;
              final threshold = required ? (clazz.passingScore ?? StudentCompletionService.safeDefaultWrittenPassingScore) : 0;

              return StreamBuilder<List<StudentRecord>>(
                stream: services.scoreRepository.watchClassScores(clazz.id),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return DatabaseErrorPanel(title: 'Scores could not be loaded', message: 'Please retry.', error: snap.error, onRetry: () {}, onOpenRecovery: null);
                  }
                  final students = snap.data ?? const [];
                  _reconcileFromDb(students);

                  return Stack(
                    children: [
                      ListView.separated(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final s = students[index];
                          final controller = _controllerFor(s);
                          final st = _stateFor(s);
                          final status = _statusLabel(required: required, draftScore: st.draftScore, draftFinalized: st.draftFinalized, threshold: threshold);
                          final statusColor = _statusColor(scheme, status);

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
                                        enabled: required,
                                        keyboardType: TextInputType.number,
                                        textInputAction: index == students.length - 1 ? TextInputAction.done : TextInputAction.next,
                                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                        decoration: InputDecoration(
                                          labelText: required ? 'Score (0–100)' : 'Score (N/A)',
                                          errorText: required ? st.validationError : null,
                                        ),
                                        onChanged: (raw) {
                                          final parsed = _parseScore(raw);
                                          final err = required ? _validateScore(parsed) : null;
                                          final valueChanged = parsed != st.originalScore;
                                          final shouldUnfinalize = st.draftFinalized && (valueChanged || parsed == null);
                                          setState(() {
                                            _states[s.id] = st.copyWith(
                                              rawDraft: raw,
                                              draftScore: parsed,
                                              draftFinalized: shouldUnfinalize ? false : st.draftFinalized,
                                              validationError: err,
                                              isDirty: true,
                                              saveError: null,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      children: [
                                        Switch(
                                          value: st.draftFinalized,
                                          onChanged: (!required)
                                              ? null
                                              : (v) async {
                                                  final latest = _stateFor(s);
                                                  if (latest.draftScore == null) {
                                                    setState(() => _states[s.id] = latest.copyWith(validationError: 'Enter a score to finalize'));
                                                    return;
                                                  }
                                                  final err = _validateScore(latest.draftScore);
                                                  if (err != null) {
                                                    setState(() => _states[s.id] = latest.copyWith(validationError: err));
                                                    return;
                                                  }

                                                  setState(() => _states[s.id] = latest.copyWith(isSaving: true, saveError: null));
                                                  try {
                                                    await services.scoreRepository.saveScoreState(studentId: s.id, score: latest.draftScore, finalized: v);
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _states[s.id] = latest.copyWith(
                                                        originalScore: latest.draftScore,
                                                        draftScore: latest.draftScore,
                                                        originalFinalized: v,
                                                        draftFinalized: v,
                                                        isDirty: false,
                                                        isSaving: false,
                                                        saveError: null,
                                                      );
                                                    });
                                                  } catch (e, st2) {
                                                    debugPrint('Finalize toggle save failed: $e\n$st2');
                                                    if (!mounted) return;
                                                    setState(() => _states[s.id] = latest.copyWith(isSaving: false, saveError: e));
                                                  }
                                                },
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
                                    onPressed: required ? () => _clearScoreWithConfirm(s) : null,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Clear'),
                                  ),
                                ),
                                if (st.saveError != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.sync_problem_outlined, color: scheme.error, size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(child: Text('This score could not be saved.')),
                                      TextButton(onPressed: () => _clearScoreWithConfirm(s), child: const Text('Retry')),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      if (_saveAllError != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 92,
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
                                      onPressed: required ? () => _markEnteredFinalized(clazz, students) : null,
                                      icon: const Icon(Icons.verified_outlined),
                                      label: const Text('Mark Entered Scores Finalized'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            KeyboardSafeSaveBar(
                              isSaving: _savingAll,
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
