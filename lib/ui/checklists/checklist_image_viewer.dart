import 'package:flutter/material.dart';

class ChecklistImageViewer extends StatelessWidget {
  const ChecklistImageViewer({super.key, required this.assetPath, required this.title});

  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load image.', style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
