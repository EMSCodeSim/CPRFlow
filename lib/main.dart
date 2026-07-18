import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PreviewBootApp());
}

/// Ultra-minimal boot app used to unblock Dreamflow Preview.
///
/// Intentionally avoids importing any other project files so that unresolved
/// dependencies elsewhere cannot prevent the app from rendering.
class PreviewBootApp extends StatelessWidget {
  const PreviewBootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: PreviewBootScreen());
  }
}

class PreviewBootScreen extends StatelessWidget {
  const PreviewBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Preview Boot Screen', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Flutter is running. If you see this, Dreamflow Preview is rendering and any remaining issues are elsewhere in the app.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {},
                  child: const Text('UI interaction test'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
