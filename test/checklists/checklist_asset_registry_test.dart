import 'package:cpr_instructor_doc/domain/checklists/checklist_asset_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChecklistAssetRegistry has no duplicate non-null paths and valid extensions', () {
    final paths = ChecklistAssetRegistry.nonNullPaths.toList();
    expect(paths.length, paths.toSet().length, reason: 'Duplicate asset paths detected');

    for (final p in paths) {
      expect(p.contains('..'), isFalse);
      expect(p.contains('.png.png'), isFalse);
      expect(p.contains('.jpg.jpg'), isFalse);
      final lower = p.toLowerCase();
      final ok = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');
      expect(ok, isTrue, reason: 'Unsupported extension for $p');
    }
  });
}
