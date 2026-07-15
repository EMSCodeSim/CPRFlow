import 'package:cpr_instructor_doc/startup/startup_issue.dart';
import 'package:flutter/material.dart';

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key, required this.issues, required this.onRetry, required this.onOpenWithoutClassData});

  final List<StartupIssue> issues;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenWithoutClassData;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDetails = issues.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Startup Recovery')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CCF Timer couldn\'t finish required startup initialization.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'What you can do',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Retry Startup: attempts to reopen the local database and validate it.\n'
                      '• Open Without Class Data: launches the app in recovery mode with class/student features disabled.\n'
                      '• Return: goes back (if possible).',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        'Summary: Class data could not be opened. Your existing database will not be modified automatically.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasDetails)
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'Technical details',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          children: [
                            const SizedBox(height: 6),
                            ...issues.map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Kind: ${issue.kind}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(issue.message, style: Theme.of(context).textTheme.bodySmall),
                                      if (issue.stackTrace != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          issue.stackTrace.toString(),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'No technical details were provided.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          await onRetry();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Startup'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenWithoutClassData,
                        icon: const Icon(Icons.folder_off_outlined),
                        label: const Text('Open Without Class Data'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: Navigator.of(context).canPop() ? () => Navigator.of(context).maybePop() : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Return'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This mode disables class and student features. No data will be wiped or repaired automatically.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
