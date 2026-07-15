import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_dismiss.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_safe_save_bar.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClassEditScreen extends StatefulWidget {
  const ClassEditScreen({super.key, required this.classId});

  final String? classId;

  @override
  State<ClassEditScreen> createState() => _ClassEditScreenState();
}

class _ClassEditScreenState extends State<ClassEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _className = TextEditingController();
  final _location = TextEditingController();
  final _leadInstructor = TextEditingController();
  final _additionalInstructor = TextEditingController();
  final _trainingCenter = TextEditingController();
  final _trainingSite = TextEditingController();
  final _passingScore = TextEditingController();

  DateTime? _classDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _defaultSkillsDate;
  DateTime? _defaultIssueDate;

  bool _writtenTestRequired = false;
  bool _ccfRequired = false;

  bool _loading = true;
  bool _saving = false;
  ClassRecord? _loaded;
  bool _didLoadInitialData = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialData) return;
    _didLoadInitialData = true;
    _loadInitialData();
  }

  @override
  void dispose() {
    _className.dispose();
    _location.dispose();
    _leadInstructor.dispose();
    _additionalInstructor.dispose();
    _trainingCenter.dispose();
    _trainingSite.dispose();
    _passingScore.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final services = AppScope.of(context);
    try {
      _loadError = null;
      if (widget.classId != null) {
        final c = await services.classRepository.getById(widget.classId!);
        if (c == null) {
          throw StateError('Class not found');
        }

        _loaded = c;

        // Preserve any fast user input: only apply loaded values when the user
        // has not already typed something.
        if (_className.text.isEmpty) _className.text = c.className;
        if (_location.text.isEmpty) _location.text = c.location ?? '';
        if (_leadInstructor.text.isEmpty) _leadInstructor.text = c.leadInstructor ?? '';
        if (_additionalInstructor.text.isEmpty) _additionalInstructor.text = c.additionalInstructor ?? '';
        if (_trainingCenter.text.isEmpty) _trainingCenter.text = c.trainingCenter ?? '';
        if (_trainingSite.text.isEmpty) _trainingSite.text = c.trainingSite ?? '';
        if (_passingScore.text.isEmpty) _passingScore.text = c.passingScore?.toString() ?? '';

        _classDate ??= c.classDate;
        _startTime ??= c.startTime == null ? null : TimeOfDay.fromDateTime(c.startTime!);
        _endTime ??= c.endTime == null ? null : TimeOfDay.fromDateTime(c.endTime!);
        _writtenTestRequired = c.writtenTestRequired;
        _ccfRequired = c.ccfRequired;
        _defaultSkillsDate ??= c.defaultSkillsCheckOffDate;
        _defaultIssueDate ??= c.defaultIssueDate;
      }
    } catch (e, st) {
      debugPrint('Failed to load class: $e\n$st');
      _loadError = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryLoad() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.classId != null;
    return KeyboardDismiss(
      child: Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Class' : 'Create Class')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 44),
                            const SizedBox(height: 12),
                            Text(
                              'Class data could not be loaded.',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You can retry loading this class. If the issue persists, open recovery mode from startup.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _retryLoad,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
              : Form(
                  key: _formKey,
                  child: CustomScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            TextFormField(
                              controller: _className,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Class Name'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Class Name is required' : null,
                            ),
                            const SizedBox(height: 12),
                            _ReadOnlyField(label: 'Course Type', value: 'BLS Provider'),
                            const SizedBox(height: 12),
                            _DatePickerField(
                              label: 'Class Date',
                              value: _classDate,
                              onPick: (d) => setState(() => _classDate = d),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimePickerField(
                                    label: 'Start Time',
                                    value: _startTime,
                                    onPick: (t) => setState(() => _startTime = t),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TimePickerField(
                                    label: 'End Time',
                                    value: _endTime,
                                    onPick: (t) => setState(() => _endTime = t),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(controller: _location, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Location')),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _leadInstructor,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Lead Instructor'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _additionalInstructor,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Additional Instructor'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _trainingCenter,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Training Center'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _trainingSite,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Training Site'),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _writtenTestRequired,
                              onChanged: (v) => setState(() => _writtenTestRequired = v),
                              title: const Text('Written Test Required'),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passingScore,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Passing Score'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final parsed = int.tryParse(v.trim());
                                if (parsed == null) return 'Passing Score must be a number';
                                if (parsed < 0 || parsed > 100) return 'Passing Score should be 0–100';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _ccfRequired,
                              onChanged: (v) => setState(() => _ccfRequired = v),
                              title: const Text('CCF Required'),
                            ),
                            const SizedBox(height: 12),
                            _DatePickerField(
                              label: 'Default Skills Check-Off Date',
                              value: _defaultSkillsDate,
                              onPick: (d) => setState(() => _defaultSkillsDate = d),
                            ),
                            const SizedBox(height: 12),
                            _DatePickerField(
                              label: 'Default Issue Date',
                              value: _defaultIssueDate,
                              onPick: (d) => setState(() => _defaultIssueDate = d),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: KeyboardSafeSaveBar(
          isSaving: _saving,
          saveLabel: 'Save',
          isEnabled: _loadError == null,
          onSave: _onSave,
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _saving = true);
    final services = AppScope.of(context);
    final repo = services.classRepository;
    try {
      final now = DateTime.now();
      final id = widget.classId ?? _newId();

      final startDateTime = _mergeDateAndTime(_classDate, _startTime);
      final endDateTime = _mergeDateAndTime(_classDate, _endTime);

      final companion = ClassRecordsCompanion(
        id: drift.Value(id),
        className: drift.Value(_className.text.trim()),
        courseType: const drift.Value(CourseType.blsProvider),
        classDate: drift.Value(_classDate),
        startTime: drift.Value(startDateTime),
        endTime: drift.Value(endDateTime),
        location: drift.Value(_cleanOrNull(_location.text)),
        leadInstructor: drift.Value(_cleanOrNull(_leadInstructor.text)),
        additionalInstructor: drift.Value(_cleanOrNull(_additionalInstructor.text)),
        trainingCenter: drift.Value(_cleanOrNull(_trainingCenter.text)),
        trainingSite: drift.Value(_cleanOrNull(_trainingSite.text)),
        writtenTestRequired: drift.Value(_writtenTestRequired),
        passingScore: drift.Value(_passingScore.text.trim().isEmpty ? null : int.tryParse(_passingScore.text.trim())),
        ccfRequired: drift.Value(_ccfRequired),
        defaultSkillsCheckOffDate: drift.Value(_defaultSkillsDate),
        defaultIssueDate: drift.Value(_defaultIssueDate),
        isActive: const drift.Value(true),
        createdAt: drift.Value(_loaded?.createdAt ?? now),
        updatedAt: drift.Value(now),
      );

      await repo.upsertClass(companion: companion, makeActiveIfNone: true);
      if (mounted) context.pop();
    } on ActiveClassAlreadyExistsException {
      if (!mounted) return;
      await _showActiveClassExistsDialog();
    } catch (e, st) {
      debugPrint('Failed to save class: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save class')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showActiveClassExistsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Active class exists'),
          content: const Text(
            'Creating another class while one is active is blocked in Phase 1.\n\nFinalize is not implemented yet.',
          ),
          actions: [
            TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
            TextButton(onPressed: null, child: const Text('Finalize Current Class')),
            FilledButton(onPressed: () => context.pop(), child: const Text('Return to Current Class')),
          ],
        );
      },
    );
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
  static String? _cleanOrNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static DateTime? _mergeDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.label, required this.value, required this.onPick});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : MaterialLocalizations.of(context).formatMediumDate(value!);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        onPick(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text(text.isEmpty ? 'Tap to select' : text),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.label, required this.value, required this.onPick});

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : value!.format(context);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
        onPick(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule_outlined)),
        child: Text(text.isEmpty ? 'Tap to select' : text),
      ),
    );
  }
}
