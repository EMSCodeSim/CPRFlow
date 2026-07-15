import 'package:cpr_instructor_doc/ui/checklists/checklist_image_viewer.dart';
import 'package:flutter/material.dart';

class ChecklistImage extends StatelessWidget {
  const ChecklistImage({super.key, required this.assetPath, required this.title});

  final String? assetPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = assetPath;
    final radius = BorderRadius.circular(16);

    if (path == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.image_not_supported_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Approved checklist image not yet added.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.82)),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: radius,
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (_) => Dialog.fullscreen(child: ChecklistImageViewer(assetPath: path, title: title)),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = (constraints.maxWidth * 0.58).clamp(160.0, 320.0).toDouble();
            return SizedBox(
              height: height,
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Center(
                  child: Text(
                    'Image could not be loaded.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
