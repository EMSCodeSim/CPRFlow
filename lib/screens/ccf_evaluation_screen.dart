import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';

class CcfEvaluationScreen extends StatefulWidget {
  const CcfEvaluationScreen({required this.studentId, super.key});

  final String studentId;

  @override
  State<CcfEvaluationScreen> createState() => _CcfEvaluationScreenState();
}

enum _CcfMode { idle, compressions, paused }

class _PauseRecord {
  const _PauseRecord({required this.reason, required this.startedAtSecond, required this.durationSeconds});

  final String reason;
  final int startedAtSecond;
  final int durationSeconds;
}

class _CcfEvaluationScreenState extends State<CcfEvaluationScreen> {
  Student? _student;
  final _formKey = GlobalKey<FormState>();

  Timer? _sessionTimer;
  Timer? _metronomeTimer;
  int _totalSeconds = 0;
  int _compressionSeconds = 0;
  int _guidedCompressionCount = 0;
  int? _savedFraction;
  int _bpm = 110;
  bool _metronomeEnabled = true;
  bool _soundEnabled = true;
  bool _hapticsEnabled = false;
  bool _beatPulse = false;
  _CcfMode _mode = _CcfMode.idle;

  int? _activePauseStartSecond;
  String _activePauseReason = 'Unspecified pause';
  final List<_PauseRecord> _pauseRecords = [];

  final _rate = TextEditingController();
  final _comments = TextEditingController();
  _AssessmentRating _pausesAssessment = _AssessmentRating.notSelected;
  ChecklistDecision _decision = ChecklistDecision.notDecided;
  _AssessmentRating _compressionQuality = _AssessmentRating.notSelected;
  _AssessmentRating _ventilationQuality = _AssessmentRating.notSelected;

  static const _pauseReasons = <String>[
    'Ventilations',
    'Rhythm / pulse check',
    'AED analysis',
    'Defibrillation / shock',
    'Airway management',
    'Compressor switch',
    'Equipment / positioning',
    'Other / avoidable delay',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_student != null) return;
    final appState = AppStateScope.of(context);
    final s = appState.getStudent(widget.studentId);
    _student = s;
    if (s == null) return;
    final e = s.ccf;
    _savedFraction = e.compressionFractionPercent;
    _rate.text = e.compressionRate?.toString() ?? '';
    _compressionQuality = assessmentRatingFromStored(e.compressionQuality);
    _ventilationQuality = assessmentRatingFromStored(e.ventilationQuality);
    _comments.text = e.instructorComments;
    _pausesAssessment = e.decision == ChecklistDecision.notDecided
        ? _AssessmentRating.notSelected
        : (e.pausesMinimized ? _AssessmentRating.meetsCriteria : _AssessmentRating.needsImprovement);
    _decision = e.decision;
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _metronomeTimer?.cancel();
    _rate.dispose();
    _comments.dispose();
    super.dispose();
  }

  double get _liveCcfPercent => _totalSeconds <= 0 ? 0 : (_compressionSeconds / _totalSeconds) * 100;

  int? get _fractionForSave {
    if (_totalSeconds > 0) return _liveCcfPercent.round().clamp(0, 100).toInt();
    return _savedFraction;
  }

  int get _pauseSeconds => (_totalSeconds - _compressionSeconds).clamp(0, _totalSeconds).toInt();

  void _ensureSessionTimer() {
    if (_sessionTimer != null) return;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _mode == _CcfMode.idle) return;
      setState(() {
        _totalSeconds++;
        if (_mode == _CcfMode.compressions) _compressionSeconds++;
      });
    });
  }

  void _restartMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    if (!_metronomeEnabled || _mode != _CcfMode.compressions) return;

    final intervalMs = (60000 / _bpm).round();
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _onMetronomeBeat());
    _onMetronomeBeat();
  }

  void _onMetronomeBeat() {
    if (!mounted || _mode != _CcfMode.compressions || !_metronomeEnabled) return;
    if (_soundEnabled) SystemSound.play(SystemSoundType.click);
    if (_hapticsEnabled) HapticFeedback.selectionClick();
    setState(() {
      _guidedCompressionCount++;
      _beatPulse = !_beatPulse;
    });
  }

  void _startOrResumeCompressions() {
    if (_mode == _CcfMode.paused) _finalizeActivePause();
    _ensureSessionTimer();
    setState(() => _mode = _CcfMode.compressions);
    _restartMetronome();
  }

  Future<void> _pauseCompressions() async {
    if (_mode == _CcfMode.idle) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start CPR before recording a pause.')));
      return;
    }
    if (_mode != _CcfMode.paused) {
      _metronomeTimer?.cancel();
      _metronomeTimer = null;
      setState(() {
        _mode = _CcfMode.paused;
        _activePauseStartSecond = _totalSeconds;
        _activePauseReason = 'Unspecified pause';
      });
    }
    await _choosePauseReason();
  }

  Future<void> _choosePauseReason() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are compressions paused?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Select the closest reason. The pause timer is already running.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pauseReasons
                    .map((r) => ActionChip(label: Text(r), onPressed: () => context.pop(r)))
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Keep as unspecified'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || reason == null) return;
    setState(() => _activePauseReason = reason);
  }

  void _finalizeActivePause() {
    final start = _activePauseStartSecond;
    if (start == null) return;
    final duration = (_totalSeconds - start).clamp(0, _totalSeconds).toInt();
    _pauseRecords.add(_PauseRecord(reason: _activePauseReason, startedAtSecond: start, durationSeconds: duration));
    _activePauseStartSecond = null;
    _activePauseReason = 'Unspecified pause';
  }

  Future<void> _resetTimer() async {
    if (_totalSeconds == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset CPR coaching session?'),
        content: const Text('This clears the current timer, compression count, CCF, and pause log. Saved evaluation data is unchanged until you save again.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _sessionTimer?.cancel();
    _metronomeTimer?.cancel();
    _sessionTimer = null;
    _metronomeTimer = null;
    setState(() {
      _mode = _CcfMode.idle;
      _totalSeconds = 0;
      _compressionSeconds = 0;
      _guidedCompressionCount = 0;
      _pauseRecords.clear();
      _activePauseStartSecond = null;
      _activePauseReason = 'Unspecified pause';
      _beatPulse = false;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  String _ccfCoachingLabel(int? ccf) {
    if (ccf == null || _totalSeconds == 0) return 'Start compressions to begin coaching';
    if (ccf >= 80) return 'High-performance CCF';
    if (ccf >= 60) return 'Minimum target met — shorten pauses';
    return 'CCF below target — focus on interruptions';
  }

  String _pauseSummaryForSave() {
    final records = [..._pauseRecords];
    if (_mode == _CcfMode.paused && _activePauseStartSecond != null) {
      records.add(_PauseRecord(
        reason: _activePauseReason,
        startedAtSecond: _activePauseStartSecond!,
        durationSeconds: (_totalSeconds - _activePauseStartSecond!).clamp(0, _totalSeconds).toInt(),
      ));
    }
    if (records.isEmpty) return '';
    final lines = records.map((p) => '${p.reason}: ${p.durationSeconds}s').join('; ');
    return 'Pause log — $lines';
  }

  void _save() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_decision == ChecklistDecision.notDecided) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Pass or Needs Remediation.')));
      return;
    }

    int? parseIntOrNull(String v) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }

    final fraction = _fractionForSave;
    final observedRate = parseIntOrNull(_rate.text);
    final rate = observedRate ?? (_totalSeconds > 0 ? _bpm : null);
    final instructorComments = _comments.text.trim();
    final pauseSummary = _pauseSummaryForSave();
    final comments = [instructorComments, pauseSummary].where((e) => e.isNotEmpty).join('\n\n');

    final anyAssessmentEntered = fraction != null ||
        rate != null ||
        _compressionQuality != _AssessmentRating.notSelected ||
        _ventilationQuality != _AssessmentRating.notSelected ||
        _pausesAssessment != _AssessmentRating.notSelected ||
        comments.isNotEmpty;

    if (_decision == ChecklistDecision.pass && !anyAssessmentEntered) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete the CPR session or enter assessment details before marking Pass.')));
      return;
    }
    if (_compressionQuality == _AssessmentRating.notSelected ||
        _ventilationQuality == _AssessmentRating.notSelected ||
        _pausesAssessment == _AssessmentRating.notSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select compression quality, ventilation quality, and pause assessment before saving.')),
      );
      return;
    }

    final anyNeedsImprovement = _compressionQuality == _AssessmentRating.needsImprovement ||
        _ventilationQuality == _AssessmentRating.needsImprovement ||
        _pausesAssessment == _AssessmentRating.needsImprovement;
    final allMeet = _compressionQuality == _AssessmentRating.meetsCriteria &&
        _ventilationQuality == _AssessmentRating.meetsCriteria &&
        _pausesAssessment == _AssessmentRating.meetsCriteria;

    if (_decision == ChecklistDecision.pass && anyNeedsImprovement && instructorComments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructor comment required when passing with any Needs Improvement assessment.')),
      );
      return;
    }
    if (_decision == ChecklistDecision.needsReview && allMeet && instructorComments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructor comment required when selecting Needs Remediation while all assessments meet criteria.')),
      );
      return;
    }

    final evaluation = CcfEvaluation(
      compressionFractionPercent: fraction,
      compressionRate: rate,
      compressionQuality: _compressionQuality.storedValue,
      ventilationQuality: _ventilationQuality.storedValue,
      pausesMinimized: _pausesAssessment == _AssessmentRating.meetsCriteria,
      instructorComments: comments,
      decision: _decision,
      createdAt: _student!.ccf.createdAt,
      updatedAt: DateTime.now(),
    );

    AppStateScope.of(context).updateCcfEvaluation(studentId: widget.studentId, evaluation: evaluation);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CCF evaluation saved.')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _student;
    if (s == null) {
      return SafeErrorScreen(
        title: 'Student not found',
        message: 'The student identifier is invalid or the student was removed.',
        primaryActionLabel: "Back to Today's Class",
        onPrimaryAction: () => context.go('/today-class'),
      );
    }

    final displayFraction = _totalSeconds > 0 ? _liveCcfPercent.round() : _savedFraction;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CPR Coach • CCF'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
              children: [
                Text(s.fullName.isEmpty ? 'Student' : s.fullName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _buildCoachCard(context, displayFraction),
                const SizedBox(height: 12),
                if (_pauseRecords.isNotEmpty || _mode == _CcfMode.paused) _buildPauseLogCard(context),
                const SizedBox(height: 12),
                _buildInstructorCard(context),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save CCF Evaluation'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoachCard(BuildContext context, int? displayFraction) {
    final cs = Theme.of(context).colorScheme;
    final active = _mode == _CcfMode.compressions;
    final paused = _mode == _CcfMode.paused;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIVE CPR COACH', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text(_ccfCoachingLabel(displayFraction), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(displayFraction == null ? '—' : '$displayFraction%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _startOrResumeCompressions,
              child: AnimatedScale(
                scale: active && _beatPulse ? 1.04 : 0.94,
                duration: Duration(milliseconds: (60000 / _bpm / 2).round()),
                curve: Curves.easeInOut,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? cs.primaryContainer : (paused ? cs.errorContainer : cs.surfaceContainerHighest),
                    border: Border.all(color: active ? cs.primary : (paused ? cs.error : cs.outline), width: 8),
                    boxShadow: active
                        ? [BoxShadow(color: cs.primary.withOpacity(0.18), blurRadius: 28, spreadRadius: 5)]
                        : const [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(active ? Icons.favorite_rounded : (paused ? Icons.pause_rounded : Icons.play_arrow_rounded), size: 52),
                      const SizedBox(height: 4),
                      Text(active ? 'COMPRESS' : (paused ? 'PAUSED' : 'START CPR'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('$_guidedCompressionCount', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('guided compressions', style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _TimeMetric(label: 'Session', value: _formatDuration(_totalSeconds))),
                const SizedBox(width: 8),
                Expanded(child: _TimeMetric(label: 'CPR', value: _formatDuration(_compressionSeconds))),
                const SizedBox(width: 8),
                Expanded(child: _TimeMetric(label: 'Paused', value: _formatDuration(_pauseSeconds))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: FilledButton.icon(
                      onPressed: _startOrResumeCompressions,
                      icon: const Icon(Icons.favorite_rounded, size: 30),
                      label: Text(_mode == _CcfMode.idle ? 'START CPR' : 'CPR', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: OutlinedButton.icon(
                      onPressed: _pauseCompressions,
                      icon: const Icon(Icons.pause_rounded, size: 30),
                      label: const Text('PAUSE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Metronome pace', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 100, label: Text('100')),
                ButtonSegment(value: 110, label: Text('110')),
                ButtonSegment(value: 120, label: Text('120')),
              ],
              selected: {_bpm},
              onSelectionChanged: (v) {
                setState(() => _bpm = v.first);
                _restartMetronome();
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                FilterChip(
                  selected: _metronomeEnabled,
                  onSelected: (v) {
                    setState(() => _metronomeEnabled = v);
                    _restartMetronome();
                  },
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('Metronome'),
                ),
                FilterChip(
                  selected: _soundEnabled,
                  onSelected: (v) => setState(() => _soundEnabled = v),
                  avatar: Icon(_soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 18),
                  label: const Text('Sound'),
                ),
                FilterChip(
                  selected: _hapticsEnabled,
                  onSelected: (v) => setState(() => _hapticsEnabled = v),
                  avatar: const Icon(Icons.vibration_rounded, size: 18),
                  label: const Text('Haptic'),
                ),
              ],
            ),
            if (paused) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_outline_rounded),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Pause reason: $_activePauseReason')),
                    TextButton(onPressed: _choosePauseReason, child: const Text('Change')),
                  ],
                ),
              ),
            ],
            TextButton.icon(onPressed: _resetTimer, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset session')),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseLogCard(BuildContext context) {
    final records = [..._pauseRecords];
    if (_mode == _CcfMode.paused && _activePauseStartSecond != null) {
      records.add(_PauseRecord(
        reason: _activePauseReason,
        startedAtSecond: _activePauseStartSecond!,
        durationSeconds: (_totalSeconds - _activePauseStartSecond!).clamp(0, _totalSeconds).toInt(),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Interruption log', style: Theme.of(context).textTheme.titleMedium)),
                Text('${records.length} pause${records.length == 1 ? '' : 's'}'),
              ],
            ),
            const SizedBox(height: 8),
            ...records.reversed.take(6).map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pause_circle_outline_rounded),
                    title: Text(p.reason),
                    subtitle: Text('Started ${_formatDuration(p.startedAtSecond)}'),
                    trailing: Text('${p.durationSeconds}s', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Instructor evaluation', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rate,
              decoration: InputDecoration(
                labelText: 'Observed compression rate (optional)',
                helperText: 'Leave blank to save the selected metronome pace ($_bpm cpm).',
                suffixText: 'cpm',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                if (n == null) return 'Enter a number';
                if (n < 40 || n > 200) return 'Use a realistic rate (40–200)';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _ratingSelector('Compression quality', _compressionQuality, (v) => setState(() => _compressionQuality = v)),
            const SizedBox(height: 12),
            _ratingSelector('Ventilation quality', _ventilationQuality, (v) => setState(() => _ventilationQuality = v)),
            const SizedBox(height: 12),
            _ratingSelector('Pauses minimized', _pausesAssessment, (v) => setState(() => _pausesAssessment = v)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _comments,
              decoration: const InputDecoration(labelText: 'Instructor comments', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ChecklistDecision>(
              segments: const [
                ButtonSegment(value: ChecklistDecision.pass, label: Text('Pass'), icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(value: ChecklistDecision.needsReview, label: Text('Needs Remediation'), icon: Icon(Icons.error_outline)),
              ],
              selected: {_decision}.where((d) => d != ChecklistDecision.notDecided).toSet(),
              onSelectionChanged: (set) => setState(() => _decision = set.isEmpty ? ChecklistDecision.notDecided : set.first),
              emptySelectionAllowed: true,
              multiSelectionEnabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingSelector(String label, _AssessmentRating value, ValueChanged<_AssessmentRating> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<_AssessmentRating>(
          segments: const [
            ButtonSegment(value: _AssessmentRating.meetsCriteria, label: Text('Meets Criteria')),
            ButtonSegment(value: _AssessmentRating.needsImprovement, label: Text('Needs Improvement')),
          ],
          selected: {value}.where((v) => v != _AssessmentRating.notSelected).toSet(),
          onSelectionChanged: (set) => onChanged(set.isEmpty ? _AssessmentRating.notSelected : set.first),
          emptySelectionAllowed: true,
          multiSelectionEnabled: false,
        ),
      ],
    );
  }
}

class _TimeMetric extends StatelessWidget {
  const _TimeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

enum _AssessmentRating { notSelected, meetsCriteria, needsImprovement }

extension on _AssessmentRating {
  String get storedValue => switch (this) {
        _AssessmentRating.notSelected => '',
        _AssessmentRating.meetsCriteria => 'Meets Criteria',
        _AssessmentRating.needsImprovement => 'Needs Improvement',
      };
}

_AssessmentRating assessmentRatingFromStored(String v) {
  final t = v.trim();
  if (t == 'Meets Criteria') return _AssessmentRating.meetsCriteria;
  if (t == 'Needs Improvement') return _AssessmentRating.needsImprovement;
  return _AssessmentRating.notSelected;
}
