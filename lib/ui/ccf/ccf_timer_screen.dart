import 'dart:async';

import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_controller.dart';
import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_state.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CcfTimerScreen extends StatefulWidget {
  const CcfTimerScreen({super.key, this.classId, this.studentId});

  final String? classId;
  final String? studentId;

  @override
  State<CcfTimerScreen> createState() => _CcfTimerScreenState();
}

class _CcfTimerScreenState extends State<CcfTimerScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final CcfTimerController _controller;
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

  int _bpm = 110;

  String? _sessionId;
  Object? _dbError;

  CcfTimerPhase? _lastPhase;
  DateTime? _lastSnapshotAt;
  bool _snapshotInFlight = false;
  Timer? _snapshotTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = CcfTimerController();
    _controller.addListener(_onTimerUpdate);
    _pulse = AnimationController(vsync: this, duration: Duration(milliseconds: _msPerBeat(_bpm)));
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.12).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.85).chain(CurveTween(curve: Curves.easeInCubic)), weight: 65),
    ]).animate(_pulse);
    _pulse.repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onTimerUpdate);
    _snapshotTimer?.cancel();
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      unawaited(_saveSnapshotNow(reason: 'lifecycle:$state'));
    }
  }

  void _onTimerUpdate() {
    if (!mounted) return;

    final phase = _controller.state.phase;
    final last = _lastPhase;
    _lastPhase = phase;
    if (last != phase) {
      // Phase transitions are meaningful moments to persist.
      if (phase == CcfTimerPhase.paused || phase == CcfTimerPhase.running) unawaited(_saveSnapshotNow(reason: 'phase:$phase'));
    }
    setState(() {});
  }

  int _msPerBeat(int bpm) => (60000 / bpm).round();

  void _setBpm(int bpm) {
    final clamped = bpm.clamp(100, 120).toInt();
    if (_bpm == clamped) return;
    setState(() => _bpm = clamped);
    _pulse.duration = Duration(milliseconds: _msPerBeat(_bpm));
    if (_pulse.isAnimating) _pulse
      ..reset()
      ..repeat();
  }

  void _startSnapshotTicker() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final phase = _controller.state.phase;
      if (phase == CcfTimerPhase.running || phase == CcfTimerPhase.paused) unawaited(_saveSnapshotNow(reason: 'throttle'));
    });
  }

  Future<void> _ensureSessionCreated() async {
    if (_sessionId != null) return;
    final services = AppScope.of(context);
    if (!services.hasClassData) {
      // Standalone timer works even without class data; saving is disabled.
      _sessionId = ''; // sentinel
      return;
    }
    try {
      final threshold = _controller.state.passingThreshold;
      final session = (widget.studentId != null && widget.classId != null)
          ? await services.ccfRepository.createStudentLinkedSession(classId: widget.classId!, studentId: widget.studentId!, passingThreshold: threshold)
          : await services.ccfRepository.createStandaloneSession(passingThreshold: threshold);
      _sessionId = session.id;
      _startSnapshotTicker();
    } catch (e, st) {
      debugPrint('Failed to create CCF session: $e\n$st');
      _dbError = e;
      setState(() {});
    }
  }

  Future<void> _saveSnapshotNow({required String reason}) async {
    final id = _sessionId;
    if (id == null || id.isEmpty) return;
    if (_snapshotInFlight) return;
    final last = _lastSnapshotAt;
    if (reason == 'throttle' && last != null && DateTime.now().difference(last) < const Duration(seconds: 6)) return;

    _snapshotInFlight = true;
    final services = AppScope.of(context);
    try {
      await services.ccfRepository.saveUnfinishedSession(
        sessionId: id,
        totalDurationMs: _controller.state.elapsed.inMilliseconds,
        compressionDurationMs: _controller.state.compression.inMilliseconds,
        pauseDurationMs: _controller.state.pause.inMilliseconds,
        ccfPercentage: _controller.state.ccfPercentage,
        passingThreshold: _controller.state.passingThreshold,
      );
      _lastSnapshotAt = DateTime.now();
    } catch (e, st) {
      debugPrint('Failed to save CCF snapshot ($reason): $e\n$st');
    } finally {
      _snapshotInFlight = false;
    }
  }

  Future<void> _start() async {
    await _ensureSessionCreated();
    if (_dbError != null) return;
    _controller.start();
    unawaited(_saveSnapshotNow(reason: 'start'));
  }

  Future<void> _resetWithConfirm() async {
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
              Text('Reset timer?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('This will discard the current attempt unless you save it first.'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => context.pop(false), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: () => context.pop(true), child: const Text('Reset'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    final id = _sessionId;
    if (id != null && _controller.state.phase != CcfTimerPhase.finished) {
      await _saveSnapshotNow(reason: 'before-reset');
      try {
        await AppScope.of(context).ccfRepository.deleteUnfinalizedSession(id);
      } catch (_) {}
    }
    _sessionId = null;
    _controller.reset();
  }

  Future<bool> _finalizeAndSave() async {
    final id = _sessionId;
    if (id == null || id.isEmpty) return false;
    try {
      final endedAt = DateTime.now();
      await AppScope.of(context).ccfRepository.finalizeSession(
        sessionId: id,
        endedAt: endedAt,
        totalDurationMs: _controller.state.elapsed.inMilliseconds,
        compressionDurationMs: _controller.state.compression.inMilliseconds,
        pauseDurationMs: _controller.state.pause.inMilliseconds,
        ccfPercentage: _controller.state.ccfPercentage,
        passingThreshold: _controller.state.passingThreshold,
      );
      return true;
    } catch (e, st) {
      debugPrint('Failed to finalize CCF session: $e\n$st');
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save failed'),
          content: const Text('The session could not be saved. Please retry.'),
          actions: [TextButton(onPressed: () => context.pop(), child: const Text('OK'))],
        ),
      );
      return false;
    }
  }

  Future<void> _assignToStudent() async {
    final services = AppScope.of(context);
    if (!services.hasClassData) return;
    final active = await services.classRepository.getActiveClass();
    if (active == null) return;
    final id = _sessionId;
    if (id == null || id.isEmpty) return;

    final reloaded = await services.ccfRepository.getById(id);
    if (reloaded == null) throw StateError('Saved session not found');
    if (!reloaded.finalized) throw StateError('Session must be finalized before assignment');

    final students = await services.studentRepository.watchStudentsForClass(active.id).first;
    if (!mounted) return;
    final chosen = await showModalBottomSheet<StudentRecord>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: students.length,
          itemBuilder: (context, index) {
            final s = students[index];
            return ListTile(
              title: Text(s.displayName),
              leading: const Icon(Icons.person_outline),
              onTap: () => context.pop(s),
            );
          },
        ),
      ),
    );
    if (chosen == null) return;
    await services.ccfRepository.assignSessionToStudent(sessionId: id, classId: active.id, studentId: chosen.id);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _controller.state;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('CCF Timer'),
        actions: [
          IconButton(onPressed: _resetWithConfirm, tooltip: 'Reset', icon: const Icon(Icons.restart_alt)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryHeader(state: s),
              const SizedBox(height: 14),
              _MetricsGrid(state: s),
              const SizedBox(height: 14),
              Container(
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
                    Text('Passing threshold: ${s.passingThreshold.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Slider(
                      value: s.passingThreshold,
                      min: 50,
                      max: 100,
                      divisions: 10,
                      label: s.passingThreshold.toStringAsFixed(0),
                      onChanged: (v) => setState(() => _controller.setPassingThreshold(v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _MetronomePanel(pulse: _pulseScale, bpm: _bpm, onBpmChanged: _setBpm),
              const Spacer(),
              if (s.phase != CcfTimerPhase.finished) _buildControls(context, s),
              if (s.phase == CcfTimerPhase.finished) _buildFinishedActions(context, s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, CcfTimerState s) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: s.phase == CcfTimerPhase.idle ? _start : (s.phase == CcfTimerPhase.running ? _controller.pause : _controller.resume),
            icon: Icon(s.phase == CcfTimerPhase.running ? Icons.pause : Icons.play_arrow),
            label: Text(s.phase == CcfTimerPhase.idle ? 'Start' : (s.phase == CcfTimerPhase.running ? 'Pause' : 'Resume')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: s.phase == CcfTimerPhase.idle ? null : _controller.finish,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Finish'),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedActions(BuildContext context, CcfTimerState s) {
    final hasDb = AppScope.of(context).hasClassData;
    final canAssign = widget.studentId == null && hasDb;
    final isStudentLinked = widget.studentId != null && widget.classId != null;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: hasDb
                ? () async {
                    final ok = await _finalizeAndSave();
                    if (!ok) return;
                    if (mounted) context.pop();
                  }
                : () => context.pop(),
            icon: const Icon(Icons.save_outlined),
            label: Text(hasDb ? (isStudentLinked ? 'Save Student Result' : 'Save Standalone Result') : 'Close (saving disabled)'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: canAssign
                ? () async {
                    final ok = await _finalizeAndSave();
                    if (!ok) return;
                    await _assignToStudent();
                  }
                : null,
            icon: const Icon(Icons.assignment_ind_outlined),
            label: Text(canAssign ? 'Assign to Student' : 'Assign to Student (requires active class)'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () async {
              final id = _sessionId;
              if (id != null && id.isNotEmpty) {
                try {
                  await AppScope.of(context).ccfRepository.deleteUnfinalizedSession(id);
                } catch (_) {}
              }
              if (mounted) context.pop();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Discard Result'),
          ),
        ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.state});
  final CcfTimerState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = state.ccfPercentage;
    final label = state.phase == CcfTimerPhase.finished
        ? (state.isPassing ? 'Passing' : 'Below threshold')
        : (state.phase == CcfTimerPhase.running ? 'Running' : (state.phase == CcfTimerPhase.paused ? 'Paused' : 'Ready'));

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
                Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75))),
                const SizedBox(height: 6),
                Text('${pct.toStringAsFixed(1)}% CCF', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
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
            child: Text(state.isPassing ? 'PASS' : 'IN PROGRESS', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.state});
  final CcfTimerState state;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: _MetricCard(title: 'Elapsed', value: _fmt(state.elapsed), icon: Icons.timer_outlined, scheme: scheme)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(title: 'Compression', value: _fmt(state.compression), icon: Icons.favorite_border, scheme: scheme)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(title: 'Pause', value: _fmt(state.pause), icon: Icons.pause_circle_outline, scheme: scheme)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon, required this.scheme});
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
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

class _MetronomePanel extends StatelessWidget {
  const _MetronomePanel({required this.pulse, required this.bpm, required this.onBpmChanged});
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
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              return Transform.scale(
                scale: pulse.value,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: 0.22), border: Border.all(color: scheme.primary.withValues(alpha: 0.5))),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visual metronome', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Rate: $bpm BPM', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Slider(
                  value: bpm.toDouble(),
                  min: 100,
                  max: 120,
                  divisions: 20,
                  label: bpm.toString(),
                  onChanged: (v) => onBpmChanged(v.round()),
                ),
                Text('Metronome sound disabled until approved WAV is added.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.74))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.volume_off_outlined), label: const Text('Audio')),
        ],
      ),
    );
  }
}
