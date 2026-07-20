import 'package:flutter/material.dart';

class TemporaryDataBanner extends StatelessWidget {
  const TemporaryDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Restoration stage: class workflow data is temporary and resets when Preview restarts.',
            ),
          ),
        ],
      ),
    );
  }
}
