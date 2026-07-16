import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final name = controller.instructorName.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCF Timer'),
        actions: [
          IconButton(
            onPressed: () => context.goNamed('settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 44,
                child: Icon(Icons.monitor_heart, size: 46),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              name.isEmpty ? 'Stage 5 test' : 'Welcome, $name',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Launch count saved in SharedPreferences: ${controller.launchCount}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Testing GoRouter, async startup, and saved preferences. No database or app services are loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.goNamed('class'),
              icon: const Icon(Icons.groups_rounded),
              label: const Text("Today's Class Form"),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.goNamed('timer'),
              icon: const Icon(Icons.timer_rounded),
              label: const Text('Local Timer'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.goNamed('settings'),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Saved Settings Test'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController nameController;
  String status = 'No save attempted yet';

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.controller.instructorName);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> saveName() async {
    await widget.controller.setInstructorName(nameController.text.trim());
    if (!mounted) return;
    setState(() => status = 'Saved successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            value: widget.controller.darkMode,
            onChanged: widget.controller.setDarkMode,
            title: const Text('Persist dark mode'),
            subtitle: const Text('Restart Preview to confirm it remains saved.'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Instructor name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: saveName, child: const Text('Save name')),
          const SizedBox(height: 8),
          Text(status, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              await widget.controller.clearSavedData();
              nameController.clear();
              if (mounted) setState(() => status = 'Stage 5 saved data cleared');
            },
            child: const Text('Clear Stage 5 saved data'),
          ),
        ],
      ),
    );
  }
}

class LocalFormScreen extends StatefulWidget {
  const LocalFormScreen({super.key});

  @override
  State<LocalFormScreen> createState() => _LocalFormScreenState();
}

class _LocalFormScreenState extends State<LocalFormScreen> {
  final controller = TextEditingController();
  final students = <String>[];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void addStudent() {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      students.add(name);
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Class"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Student name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => addStudent(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: addStudent, child: const Text('Add student')),
            const SizedBox(height: 16),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('No students added'))
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (_, index) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(students[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => students.removeAt(index)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalTimerScreen extends StatefulWidget {
  const LocalTimerScreen({super.key});

  @override
  State<LocalTimerScreen> createState() => _LocalTimerScreenState();
}

class _LocalTimerScreenState extends State<LocalTimerScreen> {
  Timer? timer;
  int seconds = 0;
  bool running = false;

  void toggle() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Timer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$minutes:$remaining', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 24),
            FilledButton(onPressed: toggle, child: Text(running ? 'Pause' : 'Start')),
            TextButton(
              onPressed: () {
                timer?.cancel();
                setState(() {
                  running = false;
                  seconds = 0;
                });
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}
