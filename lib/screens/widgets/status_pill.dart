import 'package:flutter/material.dart';

import 'package:ccf_timer_low_risk_test/app/models.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  final CompletionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      CompletionStatus.complete => (cs.primaryContainer, cs.onPrimaryContainer),
      CompletionStatus.needsReview => (cs.errorContainer, cs.onErrorContainer),
      CompletionStatus.inProgress => (cs.tertiaryContainer, cs.onTertiaryContainer),
      CompletionStatus.notStarted => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
