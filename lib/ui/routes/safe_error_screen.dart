import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SafeErrorScreen extends StatelessWidget {
  const SafeErrorScreen({super.key, required this.title, required this.message, this.details, this.onRetryLocation});

  final String title;
  final String message;
  final String? details;
  final String? onRetryLocation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 54, color: scheme.error),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8)), textAlign: TextAlign.center),
                if ((details ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(details!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                    ),
                    if (onRetryLocation != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.go(onRetryLocation!),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
