import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_dismiss.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_safe_save_bar.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudentEditScreen extends StatefulWidget {
  const StudentEditScreen({super.key, required this.studentId});

  final String? studentId;

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _displayName = TextEditingController();
  final _originalFullName = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _nameNeedsReview = false;

  bool _loading = true;
  bool _saving = false;
  StudentRecord? _loaded;
  String? _classId;
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
    _displayName.dispose();
    _originalFullName.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final services = AppScope.of(context);
    try {
      _loadError = null;
      final active = await services.classRepository.getActiveClass();
      _classId = active?.id;
      if (_classId == null) {
        debugPrint('No active class; student edit not allowed');
        return;
      }

      if (widget.studentId != null) {
        final s = await services.studentRepository.getById(widget.studentId!);
        if (s == null) throw StateError('Student not found');
        _loaded = s;

        if (_displayName.text.isEmpty) _displayName.text = s.displayName;
        if (_originalFullName.text.isEmpty) _originalFullName.text = s.originalFullName ?? '';
        if (_firstName.text.isEmpty) _firstName.text = s.firstName ?? '';
        if (_lastName.text.isEmpty) _lastName.text = s.lastName ?? '';
        if (_email.text.isEmpty) _email.text = s.email ?? '';
        if (_phone.text.isEmpty) _phone.text = s.phone ?? '';
        _nameNeedsReview = s.nameNeedsReview;
      }
    } catch (e, st) {
      debugPrint('Failed to load student: $e\n$st');
      _loadError = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.studentId != null;
    return KeyboardDismiss(
      child: Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Student' : 'Add Student')),
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
                              'Student data could not be loaded.',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You can retry loading this student. If the issue persists, open recovery mode from startup.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _loadError = null;
                                  });
                                  _loadInitialData();
                                },
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
              : _classId == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, size: 42),
                            const SizedBox(height: 12),
                            Text(
                              'No active class',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text('Create or select an active class before adding students.'),
                            const SizedBox(height: 16),
                            FilledButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back), label: const Text('Back')),
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
                                  controller: _displayName,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Display Name'),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Display Name is required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _originalFullName,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Original Full Name'),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstName,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(labelText: 'First Name'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastName,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(labelText: 'Last Name'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Email'),
                                  validator: (v) {
                                    final t = v?.trim() ?? '';
                                    if (t.isEmpty) return null;
                                    if (!t.contains('@')) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(labelText: 'Phone'),
                                  onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                ),
                                const SizedBox(height: 16),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _nameNeedsReview,
                                  onChanged: (v) => setState(() => _nameNeedsReview = v),
                                  title: const Text('Name Needs Review'),
                                ),
                                const SizedBox(height: 8),
                                if (_loaded != null)
                                  _ReadOnlyMeta(
                                    createdAt: _loaded!.createdAt,
                                    updatedAt: _loaded!.updatedAt,
                                  ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
        bottomNavigationBar: _classId == null
            ? null
            : KeyboardSafeSaveBar(
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

    final classId = _classId;
    if (classId == null) return;

    setState(() => _saving = true);
    final services = AppScope.of(context);
    try {
      final now = DateTime.now();
      final id = widget.studentId ?? _newId();
      final companion = StudentRecordsCompanion(
        id: drift.Value(id),
        classId: drift.Value(classId),
        displayName: drift.Value(_displayName.text.trim()),
        originalFullName: drift.Value(_cleanOrNull(_originalFullName.text)),
        firstName: drift.Value(_cleanOrNull(_firstName.text)),
        lastName: drift.Value(_cleanOrNull(_lastName.text)),
        email: drift.Value(_cleanOrNull(_email.text)),
        phone: drift.Value(_cleanOrNull(_phone.text)),
        nameNeedsReview: drift.Value(_nameNeedsReview),
        createdAt: drift.Value(_loaded?.createdAt ?? now),
        updatedAt: drift.Value(now),
      );
      await services.studentRepository.upsertStudent(companion: companion);
      if (mounted) context.pop();
    } catch (e, st) {
      debugPrint('Failed to save student: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save student')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
  static String? _cleanOrNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}

class _ReadOnlyMeta extends StatelessWidget {
  const _ReadOnlyMeta({required this.createdAt, required this.updatedAt});

  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final createdText = '${loc.formatMediumDate(createdAt)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt))}';
    final updatedText = '${loc.formatMediumDate(updatedAt)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Created: $createdText', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text('Updated: $updatedText', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
