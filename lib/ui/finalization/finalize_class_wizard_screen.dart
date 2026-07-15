import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/finalization/class_finalization_service.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_student_result.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;

class FinalizeClassWizardScreen extends StatefulWidget {
  const FinalizeClassWizardScreen({super.key});

  @override
  State<FinalizeClassWizardScreen> createState() => _FinalizeClassWizardScreenState();
}

class _FinalizeClassWizardScreenState extends State<FinalizeClassWizardScreen> {
  int _step = 0;
  bool _isSaving = false;
  String? _error;

  // Concurrency snapshot from Step 2.
  DateTime? _expectedClassUpdatedAt;
  Map<String, DateTime> _expectedStudentUpdatedAt = {};

  void _next() => setState(() => _step = (_step + 1).clamp(0, 2));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 2));

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final finalization = services.classFinalizationService;
    if (finalization == null) {
      return const SafeErrorScreen(title: 'Finalization unavailable', message: 'Class data services are not available.', onRetryLocation: AppRoutes.home);
    }

    return StreamBuilder<ClassRecord?>(
      stream: services.classRepository.watchActiveClass(),
      builder: (context, snap) {
        if (snap.hasError) return const SafeErrorScreen(title: 'Finalization failed', message: 'Active class could not be loaded.', onRetryLocation: AppRoutes.today);
        final clazz = snap.data;
        if (clazz == null) return const SafeErrorScreen(title: 'No active class', message: 'Return to Today\'s Class and try again.', onRetryLocation: AppRoutes.today);
        if (clazz.lifecycleStatus != ClassLifecycleStatus.active) {
          return const SafeErrorScreen(title: 'Class is read-only', message: 'This class has already been finalized.', onRetryLocation: AppRoutes.archive);
        }

        return StreamBuilder<List<StudentRecord>>(
          stream: services.studentRepository.watchStudentsForClass(clazz.id),
          builder: (context, studentsSnap) {
            final students = studentsSnap.data ?? const <StudentRecord>[];
            return Scaffold(
              appBar: AppBar(
                title: const Text('Finalize Class'),
                centerTitle: false,
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _WizardHeader(step: _step, error: _error),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: switch (_step) {
                          0 => _Step1ClassInfo(clazz: clazz),
                          1 => _Step2StudentReview(
                              clazz: clazz,
                              students: students,
                              onCapturedConcurrency: (classUpdatedAt, studentUpdatedAt) {
                                _expectedClassUpdatedAt = classUpdatedAt;
                                _expectedStudentUpdatedAt = studentUpdatedAt;
                              },
                            ),
                          _ => _Step3Decision(
                              clazz: clazz,
                              students: students,
                              expectedClassUpdatedAt: _expectedClassUpdatedAt,
                              expectedStudentUpdatedAt: _expectedStudentUpdatedAt,
                              isSaving: _isSaving,
                              onSaveProgress: () => _saveProgress(finalization, clazz.id),
                              onFinalize: (allowIncomplete) => _finalize(finalization, clazz, allowIncomplete),
                            ),
                        },
                      ),
                    ),
                    _WizardBottomBar(
                      step: _step,
                      isBusy: _isSaving,
                      onCancel: () => context.pop(),
                      onBack: _back,
                      onContinue: () {
                        setState(() => _error = null);
                        _next();
                      },
                      onEditClass: () {
                        setState(() => _error = null);
                        context.push('${AppRoutes.classEdit}?id=${Uri.encodeComponent(clazz.id)}');
                      },
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveProgress(ClassFinalizationService service, String classId) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await service.saveProgress(classId: classId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Finalization review saved')));
      context.go(AppRoutes.today);
    } catch (e, st) {
      debugPrint('Save progress failed: $e\n$st');
      setState(() => _error = 'Could not save progress. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finalize(ClassFinalizationService service, ClassRecord clazz, bool allowIncomplete) async {
    final expectedClassUpdatedAt = _expectedClassUpdatedAt;
    if (expectedClassUpdatedAt == null) {
      setState(() => _error = 'Please review students before finalizing.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final res = await service.finalize(
        ClassFinalizationRequest(
          classId: clazz.id,
          allowIncompleteStudents: allowIncomplete,
          instructorName: clazz.leadInstructor,
          instructorInitials: null,
          expectedClassUpdatedAt: expectedClassUpdatedAt,
          expectedStudentUpdatedAt: _expectedStudentUpdatedAt,
        ),
      );
      if (!mounted) return;
      context.go('${AppRoutes.finalizationSuccess}?snapshotId=${Uri.encodeComponent(res.snapshotId)}');
    } catch (e, st) {
      debugPrint('Finalize failed: $e\n$st');
      setState(() {
        _error = switch (e) {
          FinalizationStaleReviewException() => 'Class data changed during final review. Please review again.',
          FinalizationValidationException(:final message) => message,
          _ => 'Finalization failed. Please try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.step, required this.error});
  final int step;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StepPill(label: 'Class Info', active: step == 0),
              const SizedBox(width: 8),
              _StepPill(label: 'Students', active: step == 1),
              const SizedBox(width: 8),
              _StepPill(label: 'Decision', active: step == 2),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: active ? cs.onPrimary : cs.onSurface, fontWeight: FontWeight.w600)),
    );
  }
}

class _WizardBottomBar extends StatelessWidget {
  const _WizardBottomBar({
    required this.step,
    required this.isBusy,
    required this.onCancel,
    required this.onBack,
    required this.onContinue,
    required this.onEditClass,
  });

  final int step;
  final bool isBusy;
  final VoidCallback onCancel;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onEditClass;

  @override
  Widget build(BuildContext context) {
    if (step == 2) return const SizedBox.shrink();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              if (keyboardOpen) ...[
                OutlinedButton.icon(
                  onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                  icon: const Icon(Icons.keyboard_hide_outlined),
                  label: const Text('Hide'),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : (step == 0 ? onCancel : onBack),
                  child: Text(step == 0 ? 'Cancel' : 'Back'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          if (step == 0) {
                            onEditClass();
                          } else if (step == 1) {
                            onContinue();
                          } else {
                            // Step 3 buttons are within the step.
                          }
                        },
                  child: Text(step == 0 ? 'Edit Class' : (step == 1 ? 'Continue' : '')), 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step1ClassInfo extends StatelessWidget {
  const _Step1ClassInfo({required this.clazz});
  final ClassRecord clazz;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool missing = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: missing ? Theme.of(context).colorScheme.error : null, fontWeight: missing ? FontWeight.w700 : null),
            ),
          ),
        ],
      ),
    );

    final missingPassing = clazz.writtenTestRequired && (clazz.passingScore == null || clazz.passingScore! <= 0);

    return ListView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Review class information. Tap “Continue” to review students.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row('Class name', clazz.className, missing: clazz.className.trim().isEmpty),
                row('Course type', clazz.courseType.name),
                row('Class date', clazz.classDate?.toLocal().toString() ?? 'Missing', missing: clazz.classDate == null),
                row('Location', clazz.location ?? 'Missing', missing: (clazz.location ?? '').trim().isEmpty),
                row('Lead instructor', clazz.leadInstructor ?? 'Missing', missing: (clazz.leadInstructor ?? '').trim().isEmpty),
                row('Additional', clazz.additionalInstructor ?? '—'),
                row('Training Center', clazz.trainingCenter ?? '—'),
                row('Training Site', clazz.trainingSite ?? '—'),
                row('Written required', clazz.writtenTestRequired ? 'Yes' : 'No'),
                row('Passing score', clazz.passingScore?.toString() ?? 'Missing', missing: missingPassing),
                row('CCF required', clazz.ccfRequired ? 'Yes' : 'No'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Step2StudentReview extends StatefulWidget {
  const _Step2StudentReview({
    required this.clazz,
    required this.students,
    required this.onCapturedConcurrency,
  });

  final ClassRecord clazz;
  final List<StudentRecord> students;
  final void Function(DateTime classUpdatedAt, Map<String, DateTime> studentUpdatedAt) onCapturedConcurrency;

  @override
  State<_Step2StudentReview> createState() => _Step2StudentReviewState();
}

class _Step2StudentReviewState extends State<_Step2StudentReview> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.onCapturedConcurrency(widget.clazz.updatedAt, {for (final s in widget.students) s.id: s.updatedAt});
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final completion = services.studentCompletionService;

    return ListView.builder(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: widget.students.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Review each student. You can set a manual result override when needed.', style: Theme.of(context).textTheme.bodyMedium),
          );
        }
        final student = widget.students[idx - 1];
        return FutureBuilder(
          future: completion.computeForStudent(clazz: widget.clazz, student: student),
          builder: (context, snap) {
            if (snap.hasError) {
              return Card(
                child: ListTile(
                  title: Text(student.displayName),
                  subtitle: Text('Could not calculate completion. Tap to retry.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () => setState(() {}),
                ),
              );
            }
            final auto = snap.data;
            if (auto == null) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator());
            }
            final finalRes = FinalStudentResult.fromAutomaticAndStudent(automatic: auto, student: student);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(student.displayName, style: Theme.of(context).textTheme.titleMedium)),
                        _ResultChip(label: 'Auto ${auto.overallResult.name}', result: auto.overallResult),
                        const SizedBox(width: 8),
                        _ResultChip(label: 'Final ${finalRes.finalResult.name}', result: finalRes.finalResult),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (student.manualResultOverride != ManualStudentResultOverride.none) ...[
                      Text('Override: ${student.manualResultOverride.name} — ${student.manualResultReason ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editOverride(context: context, student: student, auto: auto),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Manual Result'),
                        ),
                        if (student.manualResultOverride != ManualStudentResultOverride.none)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final repo = services.studentRepository;
                              await repo.upsertStudent(
                                companion: StudentRecordsCompanion(
                                  id: Value(student.id),
                                  classId: Value(student.classId),
                                  displayName: Value(student.displayName),
                                  manualResultOverride: const Value(ManualStudentResultOverride.none),
                                  manualResultReason: const Value.absent(),
                                  manualResultChangedAt: const Value.absent(),
                                  manualResultInstructorInitials: const Value.absent(),
                                  createdAt: Value(student.createdAt),
                                ),
                              );
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Remove Override'),
                          ),
                      ],
                    ),
                    if (auto.missingRequirements.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Missing: ${auto.missingRequirements.join(', ')}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (auto.failureReasons.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Failures: ${auto.failureReasons.join(', ')}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (auto.validationWarnings.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Warnings: ${auto.validationWarnings.join(' • ')}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editOverride({required BuildContext context, required StudentRecord student, required dynamic auto}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _OverrideSheet(student: student, automaticResult: auto.overallResult),
    );
  }
}

class _OverrideSheet extends StatefulWidget {
  const _OverrideSheet({required this.student, required this.automaticResult});
  final StudentRecord student;
  final OverallStudentResult automaticResult;

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  ManualStudentResultOverride _override = ManualStudentResultOverride.none;
  final _reason = TextEditingController();
  final _initials = TextEditingController();
  bool _confirmManualPass = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _override = widget.student.manualResultOverride;
    _reason.text = widget.student.manualResultReason ?? '';
    _initials.text = widget.student.manualResultInstructorInitials ?? '';
  }

  @override
  void dispose() {
    _reason.dispose();
    _initials.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final showPassWarning = _override == ManualStudentResultOverride.pass && widget.automaticResult != OverallStudentResult.pass;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manual Result Override', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<ManualStudentResultOverride>(
            value: _override,
            items: ManualStudentResultOverride.values
                .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                .toList(growable: false),
            onChanged: (v) => setState(() {
              _override = v ?? ManualStudentResultOverride.none;
              _error = null;
            }),
            decoration: const InputDecoration(labelText: 'Override'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason (required for overrides)')),
          const SizedBox(height: 10),
          TextField(controller: _initials, decoration: const InputDecoration(labelText: 'Instructor initials (optional)')),
          if (showPassWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Automatic result is ${widget.automaticResult.name}. Manual PASS will keep missing requirements and failure reasons in the record.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _confirmManualPass,
              onChanged: (v) => setState(() => _confirmManualPass = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I understand and want to mark PASS anyway'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save Override'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final hasOverride = _override != ManualStudentResultOverride.none;
    if (hasOverride && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Reason is required.');
      return;
    }
    if (_override == ManualStudentResultOverride.pass && widget.automaticResult != OverallStudentResult.pass && !_confirmManualPass) {
      setState(() => _error = 'Please confirm the manual PASS warning.');
      return;
    }

    try {
      final services = AppScope.of(context);
      await services.studentRepository.upsertStudent(
        companion: StudentRecordsCompanion(
          id: Value(widget.student.id),
          classId: Value(widget.student.classId),
          displayName: Value(widget.student.displayName),
          manualResultOverride: Value(_override),
          manualResultReason: hasOverride ? Value(_reason.text.trim()) : const Value.absent(),
          manualResultChangedAt: hasOverride ? Value(DateTime.now()) : const Value.absent(),
          manualResultInstructorInitials: hasOverride && _initials.text.trim().isNotEmpty ? Value(_initials.text.trim()) : const Value.absent(),
          createdAt: Value(widget.student.createdAt),
        ),
      );
      if (mounted) context.pop();
    } catch (e, st) {
      debugPrint('Override save failed: $e\n$st');
      setState(() => _error = 'Could not save override.');
    }
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.result});
  final String label;
  final OverallStudentResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (result) {
      OverallStudentResult.pass => (cs.primaryContainer, cs.onPrimaryContainer),
      OverallStudentResult.incomplete => (cs.tertiaryContainer, cs.onTertiaryContainer),
      OverallStudentResult.fail => (cs.errorContainer, cs.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _Step3Decision extends StatelessWidget {
  const _Step3Decision({
    required this.clazz,
    required this.students,
    required this.expectedClassUpdatedAt,
    required this.expectedStudentUpdatedAt,
    required this.isSaving,
    required this.onSaveProgress,
    required this.onFinalize,
  });

  final ClassRecord clazz;
  final List<StudentRecord> students;
  final DateTime? expectedClassUpdatedAt;
  final Map<String, DateTime> expectedStudentUpdatedAt;
  final bool isSaving;
  final VoidCallback onSaveProgress;
  final void Function(bool allowIncomplete) onFinalize;

  @override
  Widget build(BuildContext context) {
    final completion = AppScope.of(context).studentCompletionService;
    return FutureBuilder(
      future: Future.wait(students.map((s) async {
        final auto = await completion.computeForStudent(clazz: clazz, student: s);
        return FinalStudentResult.fromAutomaticAndStudent(automatic: auto, student: s);
      })),
      builder: (context, snap) {
        final list = snap.data ?? const <FinalStudentResult>[];
        final passed = list.where((r) => r.finalResult == OverallStudentResult.pass).length;
        final incomplete = list.where((r) => r.finalResult == OverallStudentResult.incomplete).length;
        final failed = list.where((r) => r.finalResult == OverallStudentResult.fail).length;
        final overrides = students.where((s) => s.manualResultOverride != ManualStudentResultOverride.none).length;

        return ListView(
          key: const ValueKey('step3'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Confirm the final totals. Finalization is atomic and creates an immutable archived snapshot.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Final Totals', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text('Passed: $passed'),
                    Text('Incomplete: $incomplete'),
                    Text('Failed: $failed'),
                    const SizedBox(height: 10),
                    Text('Manual overrides: $overrides'),
                    const SizedBox(height: 10),
                    Text('Snapshot schema: v1', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: isSaving ? null : onSaveProgress,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Progress'),
                ),
                FilledButton.icon(
                  onPressed: isSaving || incomplete > 0 ? null : () => onFinalize(false),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Finalize and Archive'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isSaving ? null : () => _confirmIncomplete(context, incomplete),
                  icon: const Icon(Icons.archive),
                  label: const Text('Archive with Incomplete'),
                ),
              ],
            ),
            if (expectedClassUpdatedAt == null) ...[
              const SizedBox(height: 12),
              Text('Tip: Visit Student Review step to capture the reviewed versions before finalizing.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmIncomplete(BuildContext context, int incomplete) async {
    if (incomplete == 0) {
      onFinalize(true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive with incomplete students?'),
        content: const Text('This class contains incomplete student records. Those students will remain marked Incomplete in the finalized class record.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok == true) onFinalize(true);
  }
}
