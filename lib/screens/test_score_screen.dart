import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';

class TestScoreScreen extends StatefulWidget {
  const TestScoreScreen({required this.studentId, super.key});

  final String studentId;

  @override
  State<TestScoreScreen> createState() => _TestScoreScreenState();
}

class _TestScoreScreenState extends State<TestScoreScreen> {
  Student? _student;
  final _formKey = GlobalKey<FormState>();
  final _score = TextEditingController();
  final _threshold = TextEditingController(text: '84');
  final _notes = TextEditingController();
  ChecklistDecision _decision = ChecklistDecision.notDecided;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_student != null) return;
    final s = AppStateScope.of(context).getStudent(widget.studentId);
    _student = s;
    if (s == null) return;
    final ts = s.testScore;
    _score.text = ts.scorePercent?.toString() ?? '';
    _threshold.text = ts.passingThresholdPercent.toString();
    _notes.text = ts.instructorNotes;
    _decision = ts.decision;
  }

  @override
  void dispose() {
    _score.dispose();
    _threshold.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_decision == ChecklistDecision.notDecided) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Pass or Needs Remediation.')));
      return;
    }

    final score = int.parse(_score.text.trim());
    final threshold = int.parse(_threshold.text.trim());
    final meets = score >= threshold;
    final notes = _notes.text.trim();

    if (_decision == ChecklistDecision.pass && !meets && notes.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Instructor note required when passing below the threshold.')));
      return;
    }
    if (_decision == ChecklistDecision.needsReview && meets && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructor note required when selecting Needs Remediation above the threshold.')),
      );
      return;
    }

    final now = DateTime.now();
    final prev = _student!.testScore;
    final next = prev.copyWith(
      scorePercent: score,
      passingThresholdPercent: threshold,
      decision: _decision,
      instructorNotes: notes,
      updatedAt: now,
    );

    AppStateScope.of(context).updateTestScore(studentId: widget.studentId, score: next);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Written test saved (temporary).')));
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

    final score = int.tryParse(_score.text.trim());
    final threshold = int.tryParse(_threshold.text.trim());
    final meets = (score != null && threshold != null) ? score >= threshold : null;
    final resultLabel = meets == null ? '—' : (meets ? 'Meets threshold' : 'Below threshold');
    final cs = Theme.of(context).colorScheme;
    final resultColor = meets == null ? cs.onSurfaceVariant : (meets ? cs.primary : cs.error);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Written Test'),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Icon(Icons.fact_check_outlined, color: resultColor),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Calculated: $resultLabel', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: resultColor))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _score,
                              decoration: const InputDecoration(labelText: 'Score percent (0–100)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return 'Score is required';
                                final n = int.tryParse(t);
                                if (n == null) return 'Enter a number';
                                if (n < 0 || n > 100) return 'Score must be 0–100';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _threshold,
                              decoration: const InputDecoration(labelText: 'Passing threshold (1–100)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return 'Threshold is required';
                                final n = int.tryParse(t);
                                if (n == null) return 'Enter a number';
                                if (n <= 0 || n > 100) return 'Threshold must be 1–100';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Instructor decision', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SegmentedButton<ChecklistDecision>(
                        segments: const [
                          ButtonSegment(value: ChecklistDecision.pass, label: Text('Pass'), icon: Icon(Icons.check_circle_outline)),
                          ButtonSegment(value: ChecklistDecision.needsReview, label: Text('Needs Remediation'), icon: Icon(Icons.error_outline)),
                        ],
                        selected: {_decision}.where((d) => d != ChecklistDecision.notDecided).toSet(),
                        onSelectionChanged: (set) {
                          setState(() => _decision = set.isEmpty ? ChecklistDecision.notDecided : set.first);
                        },
                        emptySelectionAllowed: true,
                        multiSelectionEnabled: false,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notes,
                        decoration: const InputDecoration(labelText: 'Instructor notes', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calculated threshold result is separate from the instructor decision. Default threshold is 84% for a new form.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
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
            label: const Text('Save Test Score'),
          ),
        ),
      ),
      ),
    );
  }
}
