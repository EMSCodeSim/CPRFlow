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

class _CcfEvaluationScreenState extends State<CcfEvaluationScreen> {
  Student? _student;

  final _formKey = GlobalKey<FormState>();

  Timer? _timer;
  int _seconds = 0;
  bool _running = false;

  final _fraction = TextEditingController();
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
    _fraction.text = e.compressionFractionPercent?.toString() ?? '';
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
    _fraction.dispose();
    _rate.dispose();
    _comments.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }

    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _seconds = 0;
    });
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

    final fraction = parseIntOrNull(_fraction.text);
    final rate = parseIntOrNull(_rate.text);
    final comments = _comments.text.trim();

    final anyAssessmentEntered = fraction != null ||
        rate != null ||
        _compressionQuality != _AssessmentRating.notSelected ||
        _ventilationQuality != _AssessmentRating.notSelected ||
        _pausesAssessment != _AssessmentRating.notSelected ||
        comments.isNotEmpty;

    if (_decision == ChecklistDecision.pass && !anyAssessmentEntered) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one assessment field before marking Pass.')));
      return;
    }

    // Required quality selections before final review.
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
        const SnackBar(content: Text('Instructor comment required when compression fraction is blank but a final decision is entered.')),
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

    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (_seconds % 60).toString().padLeft(2, '0');
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName.isEmpty ? 'Student' : s.fullName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text('$minutes:$remaining', style: Theme.of(context).textTheme.displaySmall),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _toggleTimer,
                                        child: Text(_running ? 'Pause' : 'Start'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _resetTimer,
                                        child: const Text('Reset'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Timer supports the evaluation but does not auto-complete CCF. Instructor decision is required.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fraction,
                            decoration: const InputDecoration(labelText: 'Compression fraction %', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return null;
                              final n = int.tryParse(t);
                              if (n == null) return 'Enter a number';
                              if (n < 0 || n > 100) return 'Must be 0–100';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _rate,
                            decoration: const InputDecoration(labelText: 'Compression rate', border: OutlineInputBorder()),
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
                        ),
                      ],
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
                      onSelectionChanged: (set) => setState(() => _compressionQuality = set.isEmpty ? _AssessmentRating.notSelected : set.first),
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
                      onSelectionChanged: (set) => setState(() => _ventilationQuality = set.isEmpty ? _AssessmentRating.notSelected : set.first),
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
                    const SizedBox(height: 10),
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
