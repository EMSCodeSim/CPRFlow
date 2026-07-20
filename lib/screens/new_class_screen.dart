import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/current_class_transition_dialog.dart';

class NewClassScreen extends StatefulWidget {
  const NewClassScreen({required this.defaultPrimaryInstructorName, super.key});

  final String defaultPrimaryInstructorName;

  @override
  State<NewClassScreen> createState() => _NewClassScreenState();
}

class _NewClassScreenState extends State<NewClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _className = TextEditingController();
  final _trainingCenter = TextEditingController();
  final _location = TextEditingController();
  final _primaryInstructor = TextEditingController();
  final _additionalInstructor = TextEditingController();
  final _notes = TextEditingController();

  CourseType _courseType = CourseType.blsProvider;
  DateTime _classDate = DateTime.now();
  final Set<RequiredComponent> _required = {
    RequiredComponent.adultChecklist,
    RequiredComponent.infantChecklist,
    RequiredComponent.ccfEvaluation,
    RequiredComponent.writtenTest,
  };

  @override
  void initState() {
    super.initState();
    _primaryInstructor.text = widget.defaultPrimaryInstructorName;
  }

  @override
  void dispose() {
    _className.dispose();
    _trainingCenter.dispose();
    _location.dispose();
    _primaryInstructor.dispose();
    _additionalInstructor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _classDate,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() => _classDate = picked);
  }

  void _syncRequiredForCourse() {
    // Only Skills Session and Custom allow customizing required components.
    if (_courseType == CourseType.skillsSession || _courseType == CourseType.custom) return;
    setState(() {
      switch (_courseType) {
        case CourseType.blsProvider:
          _required
            ..clear()
            ..addAll({
              RequiredComponent.adultChecklist,
              RequiredComponent.infantChecklist,
              RequiredComponent.ccfEvaluation,
              RequiredComponent.writtenTest,
            });
        case CourseType.heartsaverCprAed:
        case CourseType.heartsaverFirstAidCprAed:
          _required
            ..clear()
            ..addAll({
              RequiredComponent.adultChecklist,
              RequiredComponent.ccfEvaluation,
              RequiredComponent.writtenTest,
            });
        case CourseType.skillsSession:
        case CourseType.custom:
          break;
      }
    });
  }

  Future<void> _saveClass() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appState = AppStateScope.of(context);
    final canContinue = await prepareForNewClass(context: context, appState: appState);
    if (!canContinue || !mounted) return;
    appState.createClass(
      courseType: _courseType,
      className: _className.text.trim(),
      classDate: _classDate,
      trainingCenter: _trainingCenter.text.trim(),
      location: _location.text.trim(),
      primaryInstructor: _primaryInstructor.text.trim(),
      additionalInstructor: _additionalInstructor.text.trim(),
      notes: _notes.text.trim(),
      skillsSessionRequired: Set.unmodifiable(_required),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class saved (in-memory for this restoration stage).')),
    );
    context.go('/today-class');
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_classDate.month}/${_classDate.day}/${_classDate.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Class'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const TemporaryDataBanner(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _className,
                decoration: const InputDecoration(labelText: 'Class name', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a class name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CourseType>(
                value: _courseType,
                decoration: const InputDecoration(labelText: 'Course type', border: OutlineInputBorder()),
                items: CourseType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(growable: false),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _courseType = v);
                  _syncRequiredForCourse();
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Class date', border: OutlineInputBorder()),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(dateLabel)),
                      const Icon(Icons.edit_calendar_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trainingCenter,
                decoration: const InputDecoration(labelText: 'Training center', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _primaryInstructor,
                decoration: const InputDecoration(labelText: 'Primary instructor', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _additionalInstructor,
                decoration: const InputDecoration(labelText: 'Additional instructor', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Optional notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (_courseType == CourseType.skillsSession || _courseType == CourseType.custom) ...[
                Text('Required components', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...RequiredComponent.values.map((c) => SwitchListTile.adaptive(
                      value: _required.contains(c),
                      onChanged: (v) => setState(() {
                        if (v) {
                          _required.add(c);
                        } else {
                          _required.remove(c);
                        }
                      }),
                      title: Text(c.label),
                    )),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saveClass,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
