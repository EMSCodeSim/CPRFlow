import 'package:flutter/material.dart';

import 'theme.dart';

void main() {
  runApp(const CcfThemeTestApp());
}

class CcfThemeTestApp extends StatelessWidget {
  const CcfThemeTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CCF Timer Theme Test',
      theme: lightTheme,
      home: const ThemeTestHome(),
    );
  }
}

class ThemeTestHome extends StatelessWidget {
  const ThemeTestHome({super.key});

  void _openTestScreen(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestScreen(title: title, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CCF Timer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Theme test', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'This stage tests the app theme without services, storage, assets, or plugins.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Class", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    const Text('No active class'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openTestScreen(context, "Today's Class", Icons.groups_rounded),
              icon: const Icon(Icons.groups_rounded),
              label: const Text("Today's Class"),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openTestScreen(context, 'CCF Timer', Icons.timer_rounded),
              icon: const Icon(Icons.timer_rounded),
              label: const Text('CCF Timer'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openTestScreen(context, 'Archive', Icons.archive_outlined),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive'),
            ),
          ],
        ),
      ),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int presses = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text('Button presses: $presses'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => setState(() => presses++),
                child: const Text('Test button'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
