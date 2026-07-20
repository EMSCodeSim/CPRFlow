import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SafeErrorScreen extends StatelessWidget {
  const SafeErrorScreen({required this.title, required this.message, required this.primaryActionLabel, required this.onPrimaryAction, super.key});

  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : onPrimaryAction(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 44),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(primaryActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
