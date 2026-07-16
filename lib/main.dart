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
                'Stage 1 startup test: static interface only',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Today\'s Class button works')),
                  );
                },
                icon: const Icon(Icons.groups),
                label: const Text("Today's Class"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CCF Timer button works')),
                  );
                },
                icon: const Icon(Icons.timer),
                label: const Text('CCF Timer'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Archive button works')),
                  );
                },
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
              const Spacer(),
              const Text(
                'No router • No database • No services • No assets',
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
