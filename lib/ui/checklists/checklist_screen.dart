import 'dart:async';

import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_notes_save_queue.dart';
import 'package:cpr_instructor_doc/ui/checklists/checklist_image.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_dismiss.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.studentId, required this.checklistType});

  final String studentId;
  final ChecklistType checklistType;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  ChecklistDefinition get _definition => ChecklistRegistry.definitionFor(widget.checklistType);

  bool _loading = true;
  bool _didStartInitialLoad = false;
  Object? _loadError;
  String? _attemptId;
  StudentRecord? _student;
  ClassRecord? _clazz;

  int _index = 0;

  ChecklistItemResultValue? _selected;
  String _notesDraft = '';
  late final TextEditingController _notesController;
  bool _saving = false;
  Object? _saveError;

  ChecklistSaveState _resultSaveState = ChecklistSaveState.idle;
  ChecklistItemResultValue? _unsavedSelected;

  late final ChecklistNotesSaveQueue _notesQueue;
  Object? _notesSaveError;
  Timer? _notesDebounce;

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();

    _notesQueue = ChecklistNotesSaveQueue(
      saver: ({required attemptId, required itemId, required notes}) async {
        final services = AppScope.of(context);
        await services.checklistRepository.saveNotes(attemptId: attemptId, itemId: itemId, notes: notes);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStartInitialLoad) {
      _didStartInitialLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    final services = AppScope.of(context);
    if (!services.hasClassData) {
      setState(() {
        _loading = false;
        _loadError = StateError('Class data disabled');
      });
      return;
    }

    try {
      final active = await services.classRepository.getActiveClass();
      if (active == null) throw StateError('No active class');
      final student = await services.studentRepository.getById(widget.studentId);
      if (student == null) throw StateError('Student not found');
      if (student.classId != active.id) throw StateError('Student does not belong to active class');

      final attempt = await services.checklistRepository.createOrGetUnfinalizedAttempt(
        classId: active.id,
        studentId: widget.studentId,
        checklistType: widget.checklistType,
      );

      final firstMissing = await services.checklistRepository.findFirstMissingRequiredItem(attemptId: attempt.id, definition: _definition);
      final initialIndex = firstMissing == null ? 0 : _definition.items.indexWhere((i) => i.id == firstMissing).clamp(0, _definition.items.length - 1);
      if (!mounted) return;
      _index = initialIndex;

      setState(() {
        _clazz = active;
        _student = student;
        _attemptId = attempt.id;
        _loading = false;
      });

      await _loadItemState();
    } catch (e, st) {
      debugPrint('ChecklistScreen load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _loadItemState() async {
    final services = AppScope.of(context);
    final attemptId = _attemptId;
    if (attemptId == null) return;
    final item = _definition.items[_index];
    final existing = await services.checklistRepository.getItemResult(attemptId: attemptId, itemId: item.id);
    if (!mounted) return;
    // Pending notes are per-item; switching items discards any queued notes for
    // the previous item once flushed.
    setState(() {
      final existingValue = (existing?.result == ChecklistItemResultValue.notEvaluated) ? null : existing?.result;
      _selected = existingValue;
      _notesDraft = existing?.notes ?? '';
      _notesController.text = _notesDraft;
      _saveError = null;
      _notesSaveError = null;
      _resultSaveState = existingValue == null ? ChecklistSaveState.idle : ChecklistSaveState.saved;
      _unsavedSelected = null;
    });
  }

  Future<void> _saveSelection(ChecklistItemResultValue value) async {
    final services = AppScope.of(context);
    final attemptId = _attemptId;
    if (attemptId == null) return;

    // Flush any notes pending for this item first so item results + notes remain
    // consistent even when the instructor taps quickly.
    await _flushPendingNotes();
    if (!mounted) return;

    setState(() {
      _unsavedSelected = value;
      _selected = value;
      _saving = true;
      _saveError = null;
      _resultSaveState = ChecklistSaveState.saving;
    });
    try {
      final item = _definition.items[_index];
      await services.checklistRepository.saveItemResult(attemptId: attemptId, itemId: item.id, value: value);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _resultSaveState = ChecklistSaveState.saved;
        _saveError = null;
      });
    } catch (e, st) {
      debugPrint('Failed to save item result: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e;
        _resultSaveState = ChecklistSaveState.failed;
      });
    }
  }

  void _queueNotesSave(String text) {
    _notesDraft = text;
    _notesDebounce?.cancel();
    final attemptId = _attemptId;
    if (attemptId == null) return;
    final itemId = _definition.items[_index].id;
    _notesQueue.enqueue(ChecklistNotesSaveRequest(attemptId: attemptId, itemId: itemId, notes: text));
    _notesDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_flushPendingNotes());
    });
  }

  Future<bool> _flushPendingNotes() async {
    _notesDebounce?.cancel();
    _notesDebounce = null;
    try {
      await _notesQueue.flush();
    } catch (e, st) {
      debugPrint('Notes flush failed: $e\n$st');
    }
    if (!mounted) return false;

    final err = _notesQueue.lastError;
    setState(() => _notesSaveError = err);
    return err == null;
  }

  Future<void> _goPrevious() async {
    if (_index == 0) return;
    final ok = await _flushPendingNotes();
    if (!ok) return;
    if (!mounted) return;
    setState(() => _index -= 1);
    await _loadItemState();
  }

  Future<void> _goNext() async {
    if (_index >= _definition.items.length - 1) return;
    final ok = await _flushPendingNotes();
    if (!ok) return;
    if (!mounted) return;
    setState(() => _index += 1);
    await _loadItemState();
  }

  Future<void> _finish() async {
    final services = AppScope.of(context);
    final attemptId = _attemptId;
    if (attemptId == null) return;

    final ok = await _flushPendingNotes();
    if (!ok) return;
    if (!mounted) return;

    try {
      final firstMissing = await services.checklistRepository.findFirstMissingRequiredItem(attemptId: attemptId, definition: _definition);
      if (firstMissing != null) {
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Checklist incomplete', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'One or more required skills are missing a saved result.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          context.pop();
                          final i = _definition.items.indexWhere((it) => it.id == firstMissing);
                          setState(() => _index = i.clamp(0, _definition.items.length - 1));
                          _loadItemState();
                        },
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Go to First Missing Skill'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: TextButton(onPressed: () => context.pop(), child: const Text('Close'))),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      setState(() {
        _saving = true;
        _saveError = null;
      });
      await services.checklistRepository.finalizeAttempt(attemptId: attemptId, definition: _definition);
      if (!mounted) return;
      setState(() => _saving = false);
      context.pop();
    } catch (e, st) {
      debugPrint('Finalize checklist failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e;
      });
    }
  }

  Future<bool> _handleWillPop() async {
    final ok = await _flushPendingNotes();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = _student;

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_definition.title),
              if (student != null)
                Text(
                  student.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _flushPendingNotes();
              if (!ok) return;
              if (mounted) context.pop();
            },
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: DatabaseErrorPanel(
                        title: 'Checklist could not be opened',
                        message: 'Please try again. If this persists, restart into recovery mode.',
                        error: _loadError,
                        onRetry: _load,
                        onOpenRecovery: null,
                      ),
                    )
                  : _buildLoaded(context, scheme),
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, ColorScheme scheme) {
    final item = _definition.items[_index];
    final progressText = '${_index + 1} / ${_definition.items.length}';

    final size = MediaQuery.sizeOf(context);
    final imageHeight = (size.height * 0.28).clamp(240.0, 360.0);

    return KeyboardDismiss(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
                        ),
                        child: Text('Step $progressText', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      if (item.required)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
                          ),
                          child: Text('Required', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
                          ),
                          child: Text('Optional', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(item.instructorPrompt, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: scheme.onSurface.withValues(alpha: 0.82))),
                  if ((item.optionalTeachingNote ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: scheme.secondaryContainer.withValues(alpha: 0.35),
                        border: Border.all(color: scheme.secondary.withValues(alpha: 0.16)),
                      ),
                      child: Text(item.optionalTeachingNote!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: ChecklistImage(assetPath: item.imageAssetPath, title: item.title),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _saveSelection(ChecklistItemResultValue.passed),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Passed'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _saveSelection(ChecklistItemResultValue.needsRemediation),
                          icon: Icon(Icons.error_outline, color: scheme.error),
                          label: Text('Needs Work', style: TextStyle(color: scheme.onSurface)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('checklistNotesField'),
                    controller: _notesController,
                    onChanged: _queueNotesSave,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional notes for this skill…',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.16))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.16))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.7))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ChecklistSaveStatusRow(
                    selected: _selected,
                    unsavedSelected: _unsavedSelected,
                    state: _resultSaveState,
                    error: _saveError,
                    onRetry: _unsavedSelected == null ? null : () => _saveSelection(_unsavedSelected!),
                  ),
                  if (_notesSaveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
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
                            const Expanded(child: Text('Notes not saved.')),
                            TextButton(
                              onPressed: _notesQueue.pending == null
                                  ? null
                                  : () async {
                                      await _notesQueue.retry();
                                      if (!mounted) return;
                                      setState(() => _notesSaveError = _notesQueue.lastError);
                                    },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ChecklistBottomBar(
            isBusy: _saving,
            canGoPrevious: _index > 0,
            canGoNext: _index < _definition.items.length - 1,
            onPrevious: _goPrevious,
            onNext: _goNext,
            onFinish: _finish,
          ),
        ],
      ),
    );
  }
}

enum ChecklistSaveState { idle, saving, saved, failed }

/// Phone-safe, keyboard-safe bottom controls.
class ChecklistBottomBar extends StatelessWidget {
  const ChecklistBottomBar({
    super.key,
    required this.isBusy,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final bool isBusy;
  final bool canGoPrevious;
  final bool canGoNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (keyboardOpen)
                    OutlinedButton.icon(
                      onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                      icon: const Icon(Icons.keyboard_hide_outlined),
                      label: const Text('Hide'),
                    ),
                  if (keyboardOpen) const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (isBusy || !canGoPrevious) ? null : () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await onPrevious();
                            },
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Previous'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (isBusy || !canGoNext) ? null : () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await onNext();
                            },
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          await onFinish();
                        },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Finish Checklist'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChecklistSaveStatusRow extends StatelessWidget {
  const ChecklistSaveStatusRow({
    super.key,
    required this.selected,
    required this.unsavedSelected,
    required this.state,
    required this.error,
    required this.onRetry,
  });

  final ChecklistItemResultValue? selected;
  final ChecklistItemResultValue? unsavedSelected;
  final ChecklistSaveState state;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = unsavedSelected ?? selected;
    if (effective == null && state == ChecklistSaveState.idle) return const SizedBox.shrink();

    String label;
    IconData icon;
    Color iconColor;

    switch (state) {
      case ChecklistSaveState.saving:
        label = 'Saving…';
        icon = Icons.sync;
        iconColor = scheme.primary;
        break;
      case ChecklistSaveState.saved:
        label = effective == ChecklistItemResultValue.passed ? 'Saved as Passed' : 'Saved as Needs Work';
        icon = effective == ChecklistItemResultValue.passed ? Icons.check_circle : Icons.error;
        iconColor = effective == ChecklistItemResultValue.passed ? scheme.primary : scheme.error;
        break;
      case ChecklistSaveState.failed:
        label = 'Not saved';
        icon = Icons.sync_problem_outlined;
        iconColor = scheme.error;
        break;
      case ChecklistSaveState.idle:
        // Unsaved selection exists but no save yet.
        label = 'Not saved';
        icon = Icons.info_outline;
        iconColor = scheme.onSurface.withValues(alpha: 0.6);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: (state == ChecklistSaveState.failed ? scheme.errorContainer : scheme.surfaceContainerHighest).withValues(alpha: 0.35),
        border: Border.all(color: (state == ChecklistSaveState.failed ? scheme.error : scheme.outline).withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          if (state == ChecklistSaveState.failed && onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (state == ChecklistSaveState.failed && error != null)
            Tooltip(message: error.toString(), child: Icon(Icons.info_outline, color: scheme.onSurface.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}
