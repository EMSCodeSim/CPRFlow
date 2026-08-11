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
          Icon(Icons.save_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Class, student, checklist, CCF, score, and archive data are saved locally on this device.',
            ),
          ),
        ],
      ),
    );
  }
}
