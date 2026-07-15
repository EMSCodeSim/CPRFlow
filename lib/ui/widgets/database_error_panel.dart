import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A consistent, user-friendly panel for database stream/future failures.
///
/// The primary message is human-readable. Technical details are hidden by
/// default and can be expanded.
class DatabaseErrorPanel extends StatelessWidget {
  const DatabaseErrorPanel({super.key, this.title, required this.message, this.error, this.onRetry, this.onOpenRecovery});

  final String? title;
  final String message;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenRecovery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title ?? 'Class data could not be loaded.', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(message, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Technical details', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      kReleaseMode ? 'Unavailable in release builds.' : error.toString(),
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              if (onOpenRecovery != null)
                OutlinedButton.icon(
                  onPressed: onOpenRecovery,
                  icon: const Icon(Icons.medical_information_outlined),
                  label: const Text('Open Recovery'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
