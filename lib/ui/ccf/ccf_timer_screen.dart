import 'dart:async';

import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/ccf/ccf_snapshot_save_queue.dart';
import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_controller.dart';
import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_state.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _ExitDecision { retry, stay, discard }
enum _FinishedExitDecision { save, stay, discard }

class CcfTimerScreen extends StatefulWidget {
  const CcfTimerScreen({super.key, this.classId, this.studentId});

  final String? classId;
  final String? studentId;

  @override
  State<CcfTimerScreen> createState() => _CcfTimerScreenState();
}

class _CcfTimerScreenState extends State<CcfTimerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final CcfTimerController _controller;
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;
  late final AppServices _services;

  bool _didCaptureServices = false;
  int _bpm = 110;

  String? _sessionId;
  Object? _dbError;

  CcfTimerPhase? _lastPhase;
  DateTime? _lastSnapshotAt;
  Timer? _snapshotTimer;
  CcfSnapshotSaveQueue? _snapshotSaveQueue;
  int _snapshotRevision = 0;
  Object? _snapshotSaveError;
  bool _snapshotSavePending = false;
  DateTime? _lastSuccessfulSnapshotAt;
  bool _hasUnsavedTimerChanges = false;
  bool _allowPop = false;

  bool _loadingLinkedContext = false;
  Object? _linkedContextError;
  ClassRecord? _linkedClass;
  StudentRecord? _linkedStudent;
  List<CcfSession> _previousAttempts = const [];

  bool get _isStudentLinked => widget.classId != null && widget.studentId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = CcfTimerController();
    _controller.addListener(_onTimerUpdate);
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _msPerBeat(_bpm)),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 0.85)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 65,
      ),
    ]).animate(_pulse);
    _pulse.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCaptureServices) return;
    _didCaptureServices = true;
    _services = AppScope.of(context);
    _snapshotSaveQueue = CcfSnapshotSaveQueue(
      writer: _writeSnapshotRequest,
      onStateChanged: _onSnapshotQueueStateChanged,
    );
    if (_isStudentLinked) {
      _loadingLinkedContext = true;
      unawaited(_loadLinkedContext());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onTimerUpdate);
    _snapshotTimer?.cancel();
    _snapshotSaveQueue?.dispose();
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refresh();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_saveSnapshotNow(reason: 'lifecycle:$state'));
    }
  }

  Future<void> _loadLinkedContext() async {
    try {
      if (!_services.hasClassData) {
        throw StateError('Class data is unavailable');
      }
      final classId = widget.classId!;
      final studentId = widget.studentId!;
      final clazz = await _services.classRepository.getById(classId);
      if (clazz == null) throw StateError('Class not found');
      final student = await _services.studentRepository.getById(studentId);
      if (student == null) throw StateError('Student not found');
      if (student.classId != clazz.id) {
        throw StateError('Student does not belong to this class');
      }
      final attempts = await _services.ccfRepository
          .watchSessionsForStudent(studentId)
          .first;
      final finalized = attempts.where((session) => session.finalized).toList()
        ..sort((a, b) {
          final aDate = a.endedAt ?? a.startedAt;
          final bDate = b.endedAt ?? b.startedAt;
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;
      if (finalized.isNotEmpty && _controller.state.phase == CcfTimerPhase.idle) {
        _controller.setPassingThreshold(finalized.first.passingThreshold);
      }
      setState(() {
        _linkedClass = clazz;
        _linkedStudent = student;
        _previousAttempts = finalized;
        _linkedContextError = null;
        _loadingLinkedContext = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load linked CCF context: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _linkedContextError = error;
        _loadingLinkedContext = false;
      });
    }
  }

  void _onTimerUpdate() {
    if (!mounted) return;

    final phase = _controller.state.phase;
    final last = _lastPhase;
    _lastPhase = phase;

    if (_sessionId != null &&
        _sessionId!.isNotEmpty &&
        phase != CcfTimerPhase.idle) {
      _markTimerDirty();
    }

    if (last != phase) {
      if (phase == CcfTimerPhase.paused ||
          phase == CcfTimerPhase.running ||
          phase == CcfTimerPhase.finished) {
        unawaited(_saveSnapshotNow(reason: 'phase:$phase'));
      }
    }
    setState(() {});
  }

  int _msPerBeat(int bpm) => (60000 / bpm).round();

  void _setBpm(int bpm) {
    final clamped = bpm.clamp(100, 120).toInt();
    if (_bpm == clamped) return;
    setState(() => _bpm = clamped);
    _pulse.duration = Duration(milliseconds: _msPerBeat(_bpm));
    if (_pulse.isAnimating) {
      _pulse
        ..reset()
        ..repeat();
    }
  }

  void _startSnapshotTicker() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final phase = _controller.state.phase;
      if (phase == CcfTimerPhase.running || phase == CcfTimerPhase.paused) {
        unawaited(_saveSnapshotNow(reason: 'throttle'));
      }
    });
  }

  Future<void> _ensureSessionCreated() async {
    if (_sessionId != null) return;
    if (!_services.hasClassData) {
      _sessionId = '';
      return;
    }
    if (_isStudentLinked) {
      if (_loadingLinkedContext) {
        throw StateError('Student information is still loading');
      }
      if (_linkedContextError != null ||
          _linkedClass == null ||
          _linkedStudent == null) {
        throw StateError('Student-linked CCF information is unavailable');
      }
    }

    try {
      final threshold = _controller.state.passingThreshold;
      final session = _isStudentLinked
          ? await _services.ccfRepository.createStudentLinkedSession(
              classId: widget.classId!,
              studentId: widget.studentId!,
              passingThreshold: threshold,
            )
          : await _services.ccfRepository.createStandaloneSession(
              passingThreshold: threshold,
            );
      _sessionId = session.id;
      _snapshotRevision = 0;
      _snapshotSaveQueue?.reset();
      _syncSnapshotQueueState();
      _startSnapshotTicker();
    } catch (error, stackTrace) {
      debugPrint('Failed to create CCF session: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _dbError = error);
    }
  }

  void _markTimerDirty() {
    _snapshotRevision += 1;
    _snapshotSaveQueue?.markDirty(_snapshotRevision);
    _hasUnsavedTimerChanges = true;
  }

  CcfSnapshotSaveRequest _captureSnapshotRequest({required String reason}) {
    final id = _sessionId;
    if (id == null || id.isEmpty) {
      throw StateError('CCF session has not been created');
    }
    return CcfSnapshotSaveRequest(
      sessionId: id,
      totalDurationMs: _controller.state.elapsed.inMilliseconds,
      compressionDurationMs: _controller.state.compression.inMilliseconds,
      pauseDurationMs: _controller.state.pause.inMilliseconds,
      ccfPercentage: _controller.state.ccfPercentage,
      passingThreshold: _controller.state.passingThreshold,
      revision: _snapshotRevision,
      reason: reason,
      capturedAt: DateTime.now(),
    );
  }

  void _onSnapshotQueueStateChanged() {
    if (!mounted) return;
    setState(_syncSnapshotQueueState);
  }

  void _syncSnapshotQueueState() {
    final queue = _snapshotSaveQueue;
    if (queue == null) return;
    _snapshotSavePending = queue.isSaving || queue.hasPending;
    _snapshotSaveError = queue.lastError;
    _lastSuccessfulSnapshotAt = queue.lastSuccessfulSaveAt;
    _hasUnsavedTimerChanges = queue.hasUnsavedChanges;
  }

  Future<bool> _saveSnapshotNow({required String reason}) async {
    final id = _sessionId;
    final queue = _snapshotSaveQueue;
    if (id == null || id.isEmpty || !_services.hasClassData || queue == null) {
      return true;
    }

    final last = _lastSnapshotAt;
    if (reason == 'throttle' &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 6)) {
      return queue.lastError == null;
    }

    final request = _captureSnapshotRequest(reason: reason);
    final success = await queue.enqueue(request);
    _lastSnapshotAt = queue.lastSuccessfulSaveAt ?? _lastSnapshotAt;
    if (mounted) {
      setState(_syncSnapshotQueueState);
    } else {
      _syncSnapshotQueueState();
    }
    return success;
  }

  Future<void> _writeSnapshotRequest(CcfSnapshotSaveRequest request) async {
    await _services.ccfRepository.saveUnfinishedSession(
      sessionId: request.sessionId,
      totalDurationMs: request.totalDurationMs,
      compressionDurationMs: request.compressionDurationMs,
      pauseDurationMs: request.pauseDurationMs,
      ccfPercentage: request.ccfPercentage,
      passingThreshold: request.passingThreshold,
    );
  }

  Future<void> _start() async {
    await _ensureSessionCreated();
    if (_dbError != null || _linkedContextError != null) return;
    _controller.start();
    _markTimerDirty();
    unawaited(_saveSnapshotNow(reason: 'start'));
  }

  Future<void> _resetWithConfirm() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset timer?',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('This will discard the current unfinished attempt.'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => sheetContext.pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => sheetContext.pop(true),
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    if (!await _discardUnfinalizedSession()) return;
    _sessionId = null;
    _snapshotSaveQueue?.reset();
    _syncSnapshotQueueState();
    _controller.reset();
    if (mounted) setState(() {});
  }

  Future<bool> _discardUnfinalizedSession() async {
    final id = _sessionId;
    if (id == null || id.isEmpty || !_services.hasClassData) return true;
    try {
      await _services.ccfRepository.deleteUnfinalizedSession(id);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to discard unfinished CCF session: $error\n$stackTrace');
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard failed'),
          content: const Text(
            'The unfinished session could not be removed. Please retry.',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
  }

  Future<bool> _finalizeAndSave() async {
    final id = _sessionId;
    if (id == null || id.isEmpty) return false;
    try {
      _snapshotTimer?.cancel();
      await _snapshotSaveQueue?.waitForInFlight();
      await _services.ccfRepository.finalizeSession(
        sessionId: id,
        endedAt: DateTime.now(),
        totalDurationMs: _controller.state.elapsed.inMilliseconds,
        compressionDurationMs: _controller.state.compression.inMilliseconds,
        pauseDurationMs: _controller.state.pause.inMilliseconds,
        ccfPercentage: _controller.state.ccfPercentage,
        passingThreshold: _controller.state.passingThreshold,
      );
      _snapshotSaveQueue?.markSavedThrough(_snapshotRevision);
      _syncSnapshotQueueState();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to finalize CCF session: $error\n$stackTrace');
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save failed'),
          content: const Text('The session could not be saved. Please retry.'),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
  }

  Future<void> _assignToStudent() async {
    if (!_services.hasClassData) return;
    final active = await _services.classRepository.getActiveClass();
    if (active == null) return;
    final id = _sessionId;
    if (id == null || id.isEmpty) return;

    final reloaded = await _services.ccfRepository.getById(id);
    if (reloaded == null) throw StateError('Saved session not found');
    if (!reloaded.finalized) {
      throw StateError('Session must be finalized before assignment');
    }

    final students =
        await _services.studentRepository.watchStudentsForClass(active.id).first;
    if (!mounted) return;
    final chosen = await showModalBottomSheet<StudentRecord>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              title: Text(student.displayName),
              leading: const Icon(Icons.person_outline),
              onTap: () => sheetContext.pop(student),
            );
          },
        ),
      ),
    );
    if (chosen == null) return;
    await _services.ccfRepository.assignSessionToStudent(
      sessionId: id,
      classId: active.id,
      studentId: chosen.id,
    );
    if (!mounted) return;
    _allowPop = true;
    context.pop();
  }

  Future<bool> _handleFinishedExit() async {
    if (!_services.hasClassData || _sessionId == null || _sessionId!.isEmpty) {
      final close = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Close unsaved result?'),
          content: const Text(
            'Class data is unavailable, so this finished result cannot be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: const Text('Stay on Timer'),
            ),
            FilledButton(
              onPressed: () => dialogContext.pop(true),
              child: const Text('Close Without Saving'),
            ),
          ],
        ),
      );
      return close == true;
    }

    final decision = await showModalBottomSheet<_FinishedExitDecision>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save finished CCF result?',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'This test reached its finish point. Save the final result, stay on the timer, or intentionally discard it.',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => sheetContext.pop(_FinishedExitDecision.save),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _isStudentLinked
                        ? 'Save Student Result'
                        : 'Save Standalone Result',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => sheetContext.pop(_FinishedExitDecision.stay),
                  child: const Text('Stay on Timer'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => sheetContext.pop(_FinishedExitDecision.discard),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard Result'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    switch (decision) {
      case _FinishedExitDecision.save:
        return _finalizeAndSave();
      case _FinishedExitDecision.discard:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard finished result?'),
            content: const Text(
              'This removes only the current unfinalized result. Previously finalized CCF results are not affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => dialogContext.pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => dialogContext.pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (confirm != true) return false;
        final discarded = await _discardUnfinalizedSession();
        if (discarded) {
          _sessionId = null;
          _snapshotSaveQueue?.reset();
          _syncSnapshotQueueState();
        }
        return discarded;
      case _FinishedExitDecision.stay:
      case null:
        return false;
    }
  }

  Future<bool> _handleExitRequested() async {
    if (_allowPop) return true;
    final phase = _controller.state.phase;
    if (phase == CcfTimerPhase.finished) {
      return _handleFinishedExit();
    }
    final needsSave = _hasUnsavedTimerChanges ||
        phase == CcfTimerPhase.running ||
        phase == CcfTimerPhase.paused ||
        phase == CcfTimerPhase.finished;
    if (!needsSave || _sessionId == null || _sessionId!.isEmpty) return true;

    if (await _saveSnapshotNow(reason: 'before-exit')) return true;

    while (mounted) {
      final decision = await showModalBottomSheet<_ExitDecision>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timer progress is not saved',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Retry saving, stay on the timer, or intentionally discard the unfinished attempt.',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => sheetContext.pop(_ExitDecision.retry),
                    icon: const Icon(Icons.sync),
                    label: const Text('Retry Save'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => sheetContext.pop(_ExitDecision.stay),
                    child: const Text('Stay on Timer'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => sheetContext.pop(_ExitDecision.discard),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Discard Unsaved Attempt'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      switch (decision) {
        case _ExitDecision.retry:
          if (await _saveSnapshotNow(reason: 'exit-retry')) return true;
          continue;
        case _ExitDecision.discard:
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Discard unfinished attempt?'),
              content: const Text(
                'This removes only the current unfinalized CCF attempt. Finalized results are not affected.',
              ),
              actions: [
                TextButton(
                  onPressed: () => dialogContext.pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => dialogContext.pop(true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (confirm == true && await _discardUnfinalizedSession()) {
            _sessionId = null;
            _snapshotSaveQueue?.reset();
            _syncSnapshotQueueState();
            return true;
          }
          continue;
        case _ExitDecision.stay:
        case null:
          return false;
      }
    }
    return false;
  }

  Future<void> _requestBack() async {
    if (!await _handleExitRequested()) return;
    if (!mounted) return;
    _allowPop = true;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = _controller.state;

    if (_dbError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('CCF Timer')),
        body: SafeArea(
          child: DatabaseErrorPanel(
            title: 'CCF session could not be created',
            message: 'Please retry. If this persists, restart into recovery mode.',
            error: _dbError,
            onRetry: () {
              setState(() => _dbError = null);
              _sessionId = null;
            },
            onOpenRecovery: null,
          ),
        ),
      );
    }

    if (_isStudentLinked && _loadingLinkedContext) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_isStudentLinked && _linkedContextError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student CCF')),
        body: SafeArea(
          child: DatabaseErrorPanel(
            title: 'Student CCF could not be opened',
            message: 'The student or class information could not be validated.',
            error: _linkedContextError,
            onRetry: () {
              setState(() {
                _loadingLinkedContext = true;
                _linkedContextError = null;
              });
              unawaited(_loadLinkedContext());
            },
            onOpenRecovery: null,
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _handleExitRequested,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _requestBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          title: Text(_isStudentLinked ? 'Student CCF Test' : 'CCF Timer'),
          actions: [
            IconButton(
              onPressed: _resetWithConfirm,
              tooltip: 'Reset',
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isStudentLinked)
                  _StudentCcfContextCard(
                    clazz: _linkedClass!,
                    student: _linkedStudent!,
                    attempts: _previousAttempts,
                  ),
                if (_isStudentLinked) const SizedBox(height: 14),
                _SummaryHeader(state: state),
                const SizedBox(height: 14),
                _MetricsGrid(state: state),
                const SizedBox(height: 14),
                _ThresholdPanel(
                  threshold: state.passingThreshold,
                  onChanged: (value) {
                    _controller.setPassingThreshold(value);
                    _markTimerDirty();
                  },
                ),
                const SizedBox(height: 14),
                _MetronomePanel(
                  pulse: _pulseScale,
                  bpm: _bpm,
                  onBpmChanged: _setBpm,
                ),
                const SizedBox(height: 14),
                if (_snapshotSavePending ||
                    _snapshotSaveError != null ||
                    _lastSuccessfulSnapshotAt != null)
                  _SnapshotStatusCard(
                    isPending: _snapshotSavePending,
                    error: _snapshotSaveError,
                    lastSavedAt: _lastSuccessfulSnapshotAt,
                    onRetry: _snapshotSaveError == null
                        ? null
                        : () => _saveSnapshotNow(reason: 'manual-retry'),
                  ),
                if (_snapshotSavePending ||
                    _snapshotSaveError != null ||
                    _lastSuccessfulSnapshotAt != null)
                  const SizedBox(height: 14),
                if (state.phase != CcfTimerPhase.finished)
                  _buildControls(context, state),
                if (state.phase == CcfTimerPhase.finished)
                  _buildFinishedActions(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, CcfTimerState state) {
    final primaryLabel = state.phase == CcfTimerPhase.idle
        ? (_isStudentLinked ? 'Start New Test' : 'Start')
        : state.phase == CcfTimerPhase.running
            ? 'Pause'
            : 'Resume';
    final primaryIcon =
        state.phase == CcfTimerPhase.running ? Icons.pause : Icons.play_arrow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 390;
        final buttons = [
          FilledButton.icon(
            onPressed: state.phase == CcfTimerPhase.idle
                ? _start
                : state.phase == CcfTimerPhase.running
                    ? _controller.pause
                    : _controller.resume,
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
          OutlinedButton.icon(
            onPressed:
                state.phase == CcfTimerPhase.idle ? null : _controller.finish,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Finish'),
          ),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buttons[0],
              const SizedBox(height: 10),
              buttons[1],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 10),
            Expanded(child: buttons[1]),
          ],
        );
      },
    );
  }

  Widget _buildFinishedActions(BuildContext context, CcfTimerState state) {
    final hasDatabase = _services.hasClassData;
    final canAssign = !_isStudentLinked && hasDatabase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: hasDatabase
              ? () async {
                  final saved = await _finalizeAndSave();
                  if (!saved || !mounted) return;
                  _allowPop = true;
                  context.pop();
                }
              : () {
                  _allowPop = true;
                  context.pop();
                },
          icon: const Icon(Icons.save_outlined),
          label: Text(
            hasDatabase
                ? (_isStudentLinked
                    ? 'Save Student Result'
                    : 'Save Standalone Result')
                : 'Close (saving disabled)',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canAssign
              ? () async {
                  final saved = await _finalizeAndSave();
                  if (!saved) return;
                  await _assignToStudent();
                }
              : null,
          icon: const Icon(Icons.assignment_ind_outlined),
          label: Text(
            canAssign
                ? 'Assign to Student'
                : 'Assign to Student (requires standalone result)',
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Discard result?'),
                content: const Text(
                  'This removes only the current unfinalized result.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => dialogContext.pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => dialogContext.pop(true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            if (!await _discardUnfinalizedSession() || !mounted) return;
            _allowPop = true;
            context.pop();
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Discard Result'),
        ),
      ],
    );
  }
}

class _StudentCcfContextCard extends StatelessWidget {
  const _StudentCcfContextCard({
    required this.clazz,
    required this.student,
    required this.attempts,
  });

  final ClassRecord clazz;
  final StudentRecord student;
  final List<CcfSession> attempts;

  String _date(DateTime? value) {
    if (value == null) return 'Not entered';
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _duration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = attempts.isEmpty ? null : attempts.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.secondaryContainer.withValues(alpha: 0.35),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student.displayName,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('${clazz.className} • ${_date(clazz.classDate)}'),
          const SizedBox(height: 10),
          if (latest == null)
            const Text('No finalized CCF attempts yet.')
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Latest: ${latest.ccfPercentage.toStringAsFixed(1)}% • ${latest.result == CcfResultValue.passed ? 'Passed' : 'Failed'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(_date(latest.endedAt ?? latest.startedAt)),
              ],
            ),
          if (attempts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('Previous attempts (${attempts.length})'),
              children: [
                for (final attempt in attempts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${attempt.ccfPercentage.toStringAsFixed(1)}% • ${attempt.result == CcfResultValue.passed ? 'Passed' : 'Failed'}',
                    ),
                    subtitle: Text(
                      '${_date(attempt.endedAt ?? attempt.startedAt)} • Compressions ${_duration(attempt.compressionDurationMilliseconds)} • Pauses ${_duration(attempt.pauseDurationMilliseconds)}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapshotStatusCard extends StatelessWidget {
  const _SnapshotStatusCard({
    required this.isPending,
    required this.error,
    required this.lastSavedAt,
    required this.onRetry,
  });

  final bool isPending;
  final Object? error;
  final DateTime? lastSavedAt;
  final Future<bool> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = error != null;
    final background = hasError
        ? scheme.errorContainer.withValues(alpha: 0.45)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? scheme.error.withValues(alpha: 0.25)
              : scheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasError
                ? Icons.sync_problem_outlined
                : isPending
                    ? Icons.sync
                    : Icons.cloud_done_outlined,
            color: hasError ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasError
                  ? 'Current timer progress has not been saved.'
                  : isPending
                      ? 'Saving timer progress…'
                      : 'Progress saved${lastSavedAt == null ? '' : ' at ${_clockTime(lastSavedAt!)}'}.',
            ),
          ),
          if (hasError && onRetry != null)
            TextButton(
              onPressed: () => onRetry!(),
              child: const Text('Retry Save'),
            ),
        ],
      ),
    );
  }

  static String _clockTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _ThresholdPanel extends StatelessWidget {
  const _ThresholdPanel({required this.threshold, required this.onChanged});

  final double threshold;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passing threshold: ${threshold.toStringAsFixed(0)}%',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Slider(
            value: threshold,
            min: 50,
            max: 100,
            divisions: 10,
            label: threshold.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.state});
  final CcfTimerState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = state.phase == CcfTimerPhase.finished
        ? (state.isPassing ? 'Passing' : 'Below threshold')
        : state.phase == CcfTimerPhase.running
            ? 'Running'
            : state.phase == CcfTimerPhase.paused
                ? 'Paused'
                : 'Ready';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${state.ccfPercentage.toStringAsFixed(1)}% CCF',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
            ),
            child: Text(
              state.phase == CcfTimerPhase.finished
                  ? (state.isPassing ? 'PASS' : 'FAIL')
                  : 'IN PROGRESS',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.state});
  final CcfTimerState state;

  String _format(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 330
                ? 2
                : 1;
        final spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = [
          _MetricCard(
            title: 'Elapsed',
            value: _format(state.elapsed),
            icon: Icons.timer_outlined,
            scheme: scheme,
          ),
          _MetricCard(
            title: 'Compression',
            value: _format(state.compression),
            icon: Icons.favorite_border,
            scheme: scheme,
          ),
          _MetricCard(
            title: 'Pause',
            value: _format(state.pause),
            icon: Icons.pause_circle_outline,
            scheme: scheme,
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final card in cards) SizedBox(width: width, child: card)],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.scheme,
  });

  final String title;
  final String value;
  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetronomePanel extends StatelessWidget {
  const _MetronomePanel({
    required this.pulse,
    required this.bpm,
    required this.onBpmChanged,
  });

  final Animation<double> pulse;
  final int bpm;
  final ValueChanged<int> onBpmChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) => Transform.scale(
                  scale: pulse.value,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.22),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visual metronome',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Rate: $bpm BPM',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: Icon(Icons.volume_off_outlined),
                label: Text('Audio'),
              ),
            ],
          ),
          Slider(
            value: bpm.toDouble(),
            min: 100,
            max: 120,
            divisions: 20,
            label: bpm.toString(),
            onChanged: (value) => onBpmChanged(value.round()),
          ),
          Text(
            'Metronome sound disabled until an approved WAV is added.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.74),
                ),
          ),
        ],
      ),
    );
  }
}
