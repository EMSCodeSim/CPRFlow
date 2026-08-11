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

class _CcfEvaluationScreenState extends State<CcfEvaluationScreen> {
  Student? _student;

  final _formKey = GlobalKey<FormState>();

  Timer? _timer;
  int _totalSeconds = 0;
  int _compressionSeconds = 0;
  int? _savedFraction;
  _CcfMode _mode = _CcfMode.idle;

  final _rate = TextEditingController();
  final _comments = TextEditingController();
  _AssessmentRating _pausesAssessment = _AssessmentRating.notSelected;
  ChecklistDecision _decision = ChecklistDecision.notDecided;

  _AssessmentRating _compressionQuality = _AssessmentRating.notSelected;
  _AssessmentRating _ventilationQuality = _AssessmentRating.notSelected;

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
    _timer?.cancel();
    _rate.dispose();
    _comments.dispose();
    super.dispose();
  }

  double get _liveCcfPercent {
    if (_totalSeconds <= 0) return 0;
    return (_compressionSeconds / _totalSeconds) * 100;
  }

  int? get _fractionForSave {
    if (_totalSeconds > 0) return _liveCcfPercent.round().clamp(0, 100);
    return _savedFraction;
  }

  void _ensureTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _mode == _CcfMode.idle) return;
      setState(() {
        _totalSeconds++;
        if (_mode == _CcfMode.compressions) {
          _compressionSeconds++;
        }
      });
    });
  }

  void _startOrResumeCompressions() {
    _ensureTimer();
    setState(() => _mode = _CcfMode.compressions);
  }

  void _pauseCompressions() {
    if (_mode == _CcfMode.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start CPR before recording a pause.')),
      );
      return;
    }
    setState(() => _mode = _CcfMode.paused);
  }

  Future<void> _resetTimer() async {
    if (_totalSeconds == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset CCF session?'),
        content: const Text('This clears the current CPR and pause timing data. Saved evaluation data is not changed until you save.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _mode = _CcfMode.idle;
      _totalSeconds = 0;
      _compressionSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
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
    final rate = parseIntOrNull(_rate.text);
    final comments = _comments.text.trim();

    final anyAssessmentEntered = fraction != null ||
        rate != null ||
        _compressionQuality != _AssessmentRating.notSelected ||
        _ventilationQuality != _AssessmentRating.notSelected ||
        _pausesAssessment != _AssessmentRating.notSelected ||
        comments.isNotEmpty;

    if (_decision == ChecklistDecision.pass && !anyAssessmentEntered) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete the CCF session or enter assessment details before marking Pass.')));
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

    if (_decision == ChecklistDecision.pass && anyNeedsImprovement && comments.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Instructor comment required when passing with any Needs Improvement assessment.')));
      return;
    }
    if (_decision == ChecklistDecision.needsReview && allMeet && comments.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Instructor comment required when selecting Needs Remediation while all assessments meet criteria.')));
      return;
    }
    if (_decision != ChecklistDecision.notDecided && fraction == null && comments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run a CCF session or add an instructor comment before entering a final decision.')),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CCF evaluation saved (temporary).')));
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
    final pauseSeconds = (_totalSeconds - _compressionSeconds).clamp(0, _totalSeconds);
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CCF Evaluation'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
              children: [
                Text(s.fullName.isEmpty ? 'Student' : s.fullName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Compression Fraction', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          displayFraction == null ? '—' : '$displayFraction%',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mode == _CcfMode.compressions
                              ? 'CPR ACTIVE'
                              : (_mode == _CcfMode.paused ? 'CPR PAUSED' : 'READY'),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: _mode == _CcfMode.compressions ? cs.primary : cs.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _TimeMetric(label: 'Session', value: _formatDuration(_totalSeconds))),
                            const SizedBox(width: 8),
                            Expanded(child: _TimeMetric(label: 'CPR', value: _formatDuration(_compressionSeconds))),
                            const SizedBox(width: 8),
                            Expanded(child: _TimeMetric(label: 'Paused', value: _formatDuration(pauseSeconds))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 72,
                                child: FilledButton.icon(
                                  onPressed: _startOrResumeCompressions,
                                  icon: const Icon(Icons.favorite_rounded, size: 30),
                                  label: Text(
                                    _mode == _CcfMode.idle ? 'START CPR' : 'CPR',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 72,
                                child: OutlinedButton.icon(
                                  onPressed: _pauseCompressions,
                                  icon: const Icon(Icons.pause_rounded, size: 30),
                                  label: const Text(
                                    'PAUSE',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _resetTimer,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset CCF session'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compression fraction is calculated automatically from CPR time ÷ total session time. Use PAUSE whenever compressions stop, then tap CPR when compressions resume.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instructor evaluation', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _rate,
                          decoration: const InputDecoration(
                            labelText: 'Observed compression rate (optional)',
                            suffixText: 'cpm',
                            border: OutlineInputBorder(),
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
                        Text('Compression quality', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SegmentedButton<_AssessmentRating>(
                          segments: const [
                            ButtonSegment(value: _AssessmentRating.meetsCriteria, label: Text('Meets Criteria')),
                            ButtonSegment(value: _AssessmentRating.needsImprovement, label: Text('Needs Improvement')),
                          ],
                          selected: {_compressionQuality}.where((v) => v != _AssessmentRating.notSelected).toSet(),
                          onSelectionChanged: (set) => setState(
                            () => _compressionQuality = set.isEmpty ? _AssessmentRating.notSelected : set.first,
                          ),
                          emptySelectionAllowed: true,
                          multiSelectionEnabled: false,
                        ),
                        const SizedBox(height: 12),
                        Text('Ventilation quality', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SegmentedButton<_AssessmentRating>(
                          segments: const [
                            ButtonSegment(value: _AssessmentRating.meetsCriteria, label: Text('Meets Criteria')),
                            ButtonSegment(value: _AssessmentRating.needsImprovement, label: Text('Needs Improvement')),
                          ],
                          selected: {_ventilationQuality}.where((v) => v != _AssessmentRating.notSelected).toSet(),
                          onSelectionChanged: (set) => setState(
                            () => _ventilationQuality = set.isEmpty ? _AssessmentRating.notSelected : set.first,
                          ),
                          emptySelectionAllowed: true,
                          multiSelectionEnabled: false,
                        ),
                        const SizedBox(height: 12),
                        Text('Pauses minimized', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SegmentedButton<_AssessmentRating>(
                          segments: const [
                            ButtonSegment(value: _AssessmentRating.meetsCriteria, label: Text('Meets Criteria')),
                            ButtonSegment(value: _AssessmentRating.needsImprovement, label: Text('Needs Improvement')),
                          ],
                          selected: {_pausesAssessment}.where((v) => v != _AssessmentRating.notSelected).toSet(),
                          onSelectionChanged: (set) => setState(
                            () => _pausesAssessment = set.isEmpty ? _AssessmentRating.notSelected : set.first,
                          ),
                          emptySelectionAllowed: true,
                          multiSelectionEnabled: false,
                        ),
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
                          onSelectionChanged: (set) {
                            if (set.isEmpty) {
                              setState(() => _decision = ChecklistDecision.notDecided);
                            } else {
                              setState(() => _decision = set.first);
                            }
                          },
                          emptySelectionAllowed: true,
                          multiSelectionEnabled: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 90),
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
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
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
