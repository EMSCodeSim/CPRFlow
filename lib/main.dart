import 'package:flutter/material.dart';

void main() {
  runApp(const CcfTimerTestApp());
}

class CcfTimerTestApp extends StatelessWidget {
  const CcfTimerTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCF Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const BasicHomeScreen(),
    );
  }
}

class BasicHomeScreen extends StatelessWidget {
  const BasicHomeScreen({super.key});

  void _openScreen(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestFeatureScreen(title: title, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCF Timer'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.monitor_heart, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Instructor Toolkit',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stage 2 test: built-in Flutter navigation only',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () =>
                    _openScreen(context, "Today's Class", Icons.groups),
                icon: const Icon(Icons.groups),
                label: const Text("Today's Class"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _openScreen(context, 'CCF Timer', Icons.timer),
                icon: const Icon(Icons.timer),
                label: const Text('CCF Timer'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _openScreen(context, 'Archive', Icons.archive_outlined),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
              const Spacer(),
              const Text(
                'No GoRouter • No database • No services • No plugins',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TestFeatureScreen extends StatefulWidget {
  const TestFeatureScreen({
    required this.title,
    required this.icon,
    super.key,
  });

  final String title;
  final IconData icon;

  @override
  State<TestFeatureScreen> createState() => _TestFeatureScreenState();
}

class _TestFeatureScreenState extends State<TestFeatureScreen> {
  int _pressCount = 0;

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
              Icon(widget.icon, size: 88),
              const SizedBox(height: 20),
              Text(
                '${widget.title} screen loaded',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Button presses: $_pressCount',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _pressCount++;
                  });
                },
                child: const Text('Test button'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Return home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
