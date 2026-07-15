import 'package:cpr_instructor_doc/domain/checklists/checklist_asset_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

Future<void> _assertExactCaseFileExists(String assetPath) async {
  // rootBundle.load validates:
  // - file exists
  // - file is included in pubspec assets
  await rootBundle.load(assetPath);

  // Additionally validate case-sensitive filename on disk.
  final file = File(assetPath);
  expect(file.existsSync(), isTrue, reason: 'Asset missing on disk: $assetPath');

  final parent = file.parent;
  final entries = parent.listSync().whereType<File>().toList();
  final actualName = entries.map((e) => e.uri.pathSegments.last).toList();
  final expectedName = file.uri.pathSegments.last;
  expect(actualName.contains(expectedName), isTrue, reason: 'Filename capitalization mismatch for $assetPath');
}

Future<void> _assertDecodesAsImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  expect(frame.image.width, greaterThan(0));
  expect(frame.image.height, greaterThan(0));
  codec.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ChecklistAssetRegistry non-null paths are unique and well-formed', () {
    final paths = ChecklistAssetRegistry.nonNullPaths.toList();
    expect(paths.length, paths.toSet().length, reason: 'Duplicate asset paths detected (not approved)');

    for (final p in paths) {
      expect(p.startsWith('assets/'), isTrue, reason: 'Asset path must be under assets/: $p');
      expect(p.contains('..'), isFalse);
      expect(p.contains('.png.png'), isFalse);
      expect(p.contains('.jpg.jpg'), isFalse);
      expect(p.contains('.jpeg.jpeg'), isFalse);
      expect(p.contains('.webp.webp'), isFalse);
      expect(p.contains('..png') || p.contains('..jpg') || p.contains('..jpeg') || p.contains('..webp'), isFalse);
      final lower = p.toLowerCase();
      final ok = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');
      expect(ok, isTrue, reason: 'Unsupported extension for $p');
    }
  });

  test('Adult BLS: all 16 approved artwork assets are connected and loadable', () async {
    const adultIds = [
      'adult_scene_safety_ppe',
      'adult_responsiveness',
      'adult_activate_ems_retrieve_aed',
      'adult_check_breathing_pulse',
      'adult_start_compressions',
      'adult_hand_placement',
      'adult_compression_depth',
      'adult_compression_rate',
      'adult_full_recoil',
      'adult_minimize_interruptions',
      'adult_30_2_sequence',
      'adult_effective_breaths',
      'adult_apply_aed_pads',
      'adult_clear_before_analysis',
      'adult_resume_compressions',
      'adult_team_communication',
    ];

    for (final id in adultIds) {
      final path = ChecklistAssetRegistry.pathForItem(id);
      expect(path, isNotNull, reason: 'Missing adult asset for $id');
      await _assertExactCaseFileExists(path!);
      await _assertDecodesAsImage(path);
    }
  });

  test('Infant/Child: approved assets are connected; unapproved compression artwork remains unassigned', () async {
    const approvedIds = [
      'ic_scene_safety_ppe',
      'ic_responsiveness',
      'ic_activate_ems',
      'ic_check_breathing',
      'ic_check_brachial_pulse',
      'ic_open_airway',
      'ic_two_breaths',
      'ic_second_rescuer_arrives',
      'ic_two_thumb_encircling',
      'ic_15_2_sequence',
      'ic_bag_mask_ventilation',
      'ic_resume_cpr',
    ];
    for (final id in approvedIds) {
      final path = ChecklistAssetRegistry.pathForItem(id);
      expect(path, isNotNull, reason: 'Missing infant/child approved asset for $id');
      await _assertExactCaseFileExists(path!);
      await _assertDecodesAsImage(path);
    }

    const unapprovedIds = [
      'ic_one_rescuer_compressions',
      'ic_compression_depth',
      'ic_compression_rate',
      'ic_30_2_ratio',
      'ic_continue_cpr_30_2',
    ];
    for (final id in unapprovedIds) {
      expect(ChecklistAssetRegistry.pathForItem(id), isNull, reason: 'Unapproved step must not have image: $id');
    }

    const unapprovedFilenames = [
      'infant_step_06_one_rescuer_compressions.png',
      'infant_step_07_compression_depth.png',
      'infant_step_08_compression_rate.png',
      'infant_step_09_30_to_2_ratio.png',
      'infant_step_12_continue_cpr_30_2.png',
    ];
    final allPaths = ChecklistAssetRegistry.nonNullPaths.toList();
    for (final name in unapprovedFilenames) {
      expect(allPaths.any((p) => p.endsWith(name)), isFalse, reason: 'Unapproved file must not be wired: $name');
    }
  });
}
