import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/restoration_prefs_controller.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/temporary_data_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final RestorationPrefsController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  String _status = 'No save attempted yet';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.instructorName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final result = await widget.controller.setInstructorName(_nameController.text.trim());
    if (!mounted) return;
    setState(() => _status = _statusFromResult(result, changedOnly: 'Name updated for this session (not persisted).'));
  }

  Future<void> _toggleDarkMode(bool v) async {
    final result = await widget.controller.setDarkMode(v);
    if (!mounted) return;
    setState(() => _status = _statusFromResult(result, changedOnly: 'Dark mode changed for this session (not persisted).'));
  }

  String _statusFromResult(PrefSaveResult r, {required String changedOnly}) {
    switch (r) {
      case PrefSaveResult.success:
        return 'Saved successfully';
      case PrefSaveResult.unavailable:
        return changedOnly;
      case PrefSaveResult.failed:
        return 'Save failed (try again).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TemporaryDataBanner(),
          const SizedBox(height: 16),
          SwitchListTile(
            value: widget.controller.darkMode,
            onChanged: _toggleDarkMode,
            title: const Text('Dark mode'),
            subtitle: const Text('Attempts to persist via SharedPreferences.'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Instructor name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saveName, child: const Text('Save name')),
          const SizedBox(height: 8),
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final result = await widget.controller.clearStage5Data();
              _nameController.clear();
              if (!mounted) return;
              setState(() {
                _status = switch (result) {
                  PrefSaveResult.success => 'Saved preferences cleared',
                  PrefSaveResult.unavailable => 'Preferences cleared for this session (not persisted).',
                  PrefSaveResult.failed => 'Clear failed (try again).',
                };
              });
            },
            child: const Text('Clear restoration-test preferences'),
          ),
          const SizedBox(height: 24),
          Text('Restoration diagnostics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/asset-test'),
            icon: const Icon(Icons.image_search_rounded),
            label: const Text('CPR Asset Test'),
          ),
        ],
      ),
    );
  }
}
