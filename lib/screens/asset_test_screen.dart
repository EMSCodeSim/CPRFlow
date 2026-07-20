import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ccf_timer_low_risk_test/assets/cpr_image_catalog.dart';

class AssetTestScreen extends StatefulWidget {
  const AssetTestScreen({super.key});

  @override
  State<AssetTestScreen> createState() => _AssetTestScreenState();
}

class _AssetTestScreenState extends State<AssetTestScreen> {
  final Map<String, int?> _byteSizes = {};
  final Map<String, bool> _loadOk = {};

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    for (final a in CprImageCatalog.all) {
      final path = a.assetPath;
      if (path == null) continue;
      final size = await CprImageCatalog.tryLoadByteSize(path);
      if (!mounted) return;
      setState(() => _byteSizes[path] = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPR Asset Test (Restoration)'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: CprImageCatalog.all.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final a = CprImageCatalog.all[index];
            final path = a.assetPath;
            final ok = path == null ? false : (_loadOk[path] ?? true);
            final size = path == null ? null : _byteSizes[path];
            final sizeLabel = size == null ? '—' : '${(size / 1024).toStringAsFixed(1)} KB';
            final categoryLabel = switch (a.category) {
              CprImageCategory.adult => 'Adult',
              CprImageCategory.infant => 'Infant',
              CprImageCategory.common => 'Common',
            };

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                'id: ${a.id}',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusChip(
                          label: a.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                          color: a.isAvailable ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoPill(label: 'Category', value: categoryLabel),
                        _InfoPill(label: 'Size', value: sizeLabel),
                        _InfoPill(label: 'Loads', value: path == null ? 'NO PATH' : (ok ? 'OK' : 'FAIL')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (path == null) ...[
                      Text(
                        a.unavailableReason ?? 'No asset path for this catalog item.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ] else ...[
                      Text(
                        path,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: cs.surfaceContainerHighest,
                          padding: const EdgeInsets.all(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: Image.asset(
                              path,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (context, error, stack) {
                                debugPrint('AssetTestScreen failed for $path: $error');
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  if (_loadOk[path] == false) return;
                                  setState(() => _loadOk[path] = false);
                                });
                                return _BrokenPreview(message: 'Failed to load image');
                              },
                            ),
                          ),
                        ),
                      ),
                      if (!a.approvedForInstruction) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Marked as not approved for instruction: ${a.unavailableReason ?? 'No reason provided.'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.4),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _BrokenPreview extends StatelessWidget {
  const _BrokenPreview({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      width: double.infinity,
      alignment: Alignment.center,
      color: cs.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
