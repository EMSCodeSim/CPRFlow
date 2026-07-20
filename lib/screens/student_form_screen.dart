import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({required this.studentId, super.key});

  /// Use 'new' for new student.
  final String studentId;

  bool get isNew => studentId == 'new';

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _studentId = TextEditingController();
  final _notes = TextEditingController();

  Student? _existing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.isNew && _existing == null) {
      final appState = AppStateScope.of(context);
      final s = appState.getStudent(widget.studentId);
      _existing = s;
      if (s != null) {
        _first.text = s.firstName;
        _last.text = s.lastName;
        _email.text = s.email;
        _phone.text = s.phone;
        _studentId.text = s.studentId;
        _notes.text = s.notes;
      }
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _studentId.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _save() {
    _dismissKeyboard();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appState = AppStateScope.of(context);
    try {
      final id = appState.upsertStudent(
        existingStudentId: widget.isNew ? null : widget.studentId,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        studentId: _studentId.text.trim(),
        notes: _notes.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student saved (temporary).')));
      context.go('/students/$id');
    } catch (e) {
      debugPrint('Failed to save student: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save student.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    if (!appState.hasCurrentClass()) {
      return SafeErrorScreen(
        title: 'No active class',
        message: 'Create a class before adding students.',
        primaryActionLabel: 'Start New Class',
        onPrimaryAction: () => context.go('/new-class'),
      );
    }

    if (!widget.isNew && _existing == null) {
      return SafeErrorScreen(
        title: 'Student not found',
        message: 'The student identifier is invalid or no longer exists in memory.',
        primaryActionLabel: "Back to Today's Class",
        onPrimaryAction: () => context.go('/today-class'),
      );
    }

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Add Student' : 'Edit Student'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Dismiss keyboard',
              onPressed: _dismissKeyboard,
              icon: const Icon(Icons.keyboard_hide_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isNew ? 'Add a student to the current roster.' : 'Update student details.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _first,
                          decoration: const InputDecoration(labelText: 'First name', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _last,
                          decoration: const InputDecoration(labelText: 'Last name', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]'))],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _studentId,
                    decoration: const InputDecoration(labelText: 'Student ID (optional)', border: OutlineInputBorder()),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ID is generated in-memory using a collision-resistant timestamp+random scheme (not a raw timestamp).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.go('/today-class'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
