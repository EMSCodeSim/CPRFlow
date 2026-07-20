import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/assets/cpr_image_catalog.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({required this.imageId, super.key});

  final String imageId;

  @override
  Widget build(BuildContext context) {
    final asset = CprImageCatalog.byId(imageId);
    if (asset == null) {
      return SafeErrorScreen(
        title: 'Image not found',
        message: 'Catalog id "$imageId" does not exist.',
        primaryActionLabel: 'Back',
        onPrimaryAction: () => context.pop(),
      );
    }
    if (!asset.isAvailable) {
      return SafeErrorScreen(
        title: 'Image unavailable',
        message: asset.unavailableReason ?? 'This instructional image is unavailable.',
        primaryActionLabel: 'Back',
        onPrimaryAction: () => context.pop(),
      );
    }
    final path = asset.assetPath;
    if (path == null) {
      return SafeErrorScreen(
        title: 'Image unavailable',
        message: 'No asset path defined for this image.',
        primaryActionLabel: 'Back',
        onPrimaryAction: () => context.pop(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(asset.title),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: cs.surface,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Hero(
            tag: 'cpr_image_${asset.id}',
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Center(
                  child: Text(
                    'Image failed to load.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
