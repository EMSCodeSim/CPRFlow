import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/assets/cpr_image_catalog.dart';

/// Reusable, safe image component for checklist instructional images.
///
/// - Uses Image.asset
/// - Keeps aspect ratio
/// - Bounded max height
/// - Rounded corners
/// - Placeholder + error fallback
/// - Accessible semantics
/// - Tap to open a larger viewer (if available)
class ChecklistInstructionImage extends StatelessWidget {
  const ChecklistInstructionImage({required this.asset, required this.skillTitle, super.key});

  final CprImageAsset asset;
  final String skillTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    if (!asset.isAvailable) {
      return _UnavailablePanel(
        title: asset.title,
        reason: asset.unavailableReason ?? 'Instructional image unavailable.',
      );
    }

    final path = asset.assetPath;
    if (path == null) {
      return const _UnavailablePanel(title: 'Instructional image', reason: 'Instructional image unavailable.');
    }

    return Semantics(
      image: true,
      label: asset.semanticLabel,
      child: InkWell(
        onTap: () => context.push('/image/${Uri.encodeComponent(asset.id)}'),
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: radius,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      asset.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View larger',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_full_rounded, size: 18, color: cs.primary),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Hero(
                    tag: 'cpr_image_${asset.id}',
                    child: Image.asset(
                      path,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stack) {
                        debugPrint('Failed to load asset image: $path ($error)');
                        return const _ImageErrorFallback();
                      },
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) return child;
                        return const _LoadingShimmer();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel({required this.title, required this.reason});

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.image_not_supported_rounded, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(reason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageErrorFallback extends StatelessWidget {
  const _ImageErrorFallback();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 160,
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('Image failed to load', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final base = cs.surfaceContainerHighest;
        final highlight = cs.surfaceContainerHighest.withValues(alpha: 0.6);
        return Container(
          height: 160,
          width: double.infinity,
          color: Color.lerp(base, highlight, t),
        );
      },
    );
  }
}
