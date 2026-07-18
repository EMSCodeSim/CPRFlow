import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_routes.dart';
import 'theme.dart';

void main() {
  runApp(const LowRiskTestApp());
}

class LowRiskTestApp extends StatefulWidget {
  const LowRiskTestApp({super.key});

  @override
  State<LowRiskTestApp> createState() => _LowRiskTestAppState();
}

class _LowRiskTestAppState extends State<LowRiskTestApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CCF Timer Low-Risk Test',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => HomeScreen(
              darkMode: darkMode,
              onDarkModeChanged: (value) => setState(() => darkMode = value),
            ),
        AppRoutes.today: (_) => const LocalFormScreen(),
        AppRoutes.ccfTimer: (_) => const LocalTimerScreen(),
        AppRoutes.archive: (_) => const StaticArchiveScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.darkMode,
    required this.onDarkModeChanged,
    super.key,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCF Timer'),
        actions: [
          Switch(value: darkMode, onChanged: onDarkModeChanged),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icons/dreamflow_icon.jpg',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, __) => Text('Asset error: $error'),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Low-risk restoration test',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tests assets, named routes, forms, dialogs, local state, timers, and theme switching. No services or plugins are loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.today),
              icon: const Icon(Icons.groups_rounded),
              label: const Text("Today's Class Form"),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.ccfTimer),
              icon: const Icon(Icons.timer_rounded),
              label: const Text('Local Timer'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.archive),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Static Archive'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Dialog works'),
                  content: const Text('This is local Flutter UI only.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Test Dialog'),
            ),
          ],
        ),
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
      appBar: AppBar(title: const Text("Today's Class Form")),
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
      appBar: AppBar(title: const Text('Local Timer')),
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

class StaticArchiveScreen extends StatelessWidget {
  const StaticArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Static Archive')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
            title: Text('Sample class ${index + 1}'),
            subtitle: const Text('Local display data only'),
          ),
        ),
      ),
    );
  }
}
