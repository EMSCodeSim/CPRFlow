import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_asset_registry.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_item_definition.dart';

class AdultBlsDefinition {
  static const String sectionPrimary = 'Adult BLS';

  static ChecklistDefinition build() {
    // Adult BLS Phase 2 FINAL sequence (16 steps, one image per stable ID).
    final items = <ChecklistItemDefinition>[
      ChecklistItemDefinition(
        id: 'adult_scene_safety_ppe',
        title: 'Scene safety & PPE',
        instructorPrompt: 'Confirm the scene is safe and apply appropriate PPE.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_scene_safety_ppe'),
        required: true,
        order: 1,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_responsiveness',
        title: 'Check responsiveness',
        instructorPrompt: 'Tap and shout: “Are you okay?” Demonstrate an appropriate responsiveness check.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_responsiveness'),
        required: true,
        order: 2,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_activate_ems_retrieve_aed',
        title: 'Activate EMS / retrieve AED',
        instructorPrompt: 'Direct bystanders to activate emergency response (call 911) and bring the AED.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_activate_ems_retrieve_aed'),
        required: true,
        order: 3,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_check_breathing_pulse',
        title: 'Check breathing & pulse',
        instructorPrompt: 'Check for breathing and carotid pulse simultaneously (≤10 seconds).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_check_breathing_pulse'),
        required: true,
        order: 4,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_start_compressions',
        title: 'Start compressions',
        instructorPrompt: 'Begin high-quality compressions immediately when indicated.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_start_compressions'),
        required: true,
        order: 5,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_hand_placement',
        title: 'Hand placement',
        instructorPrompt: 'Place hands on the center of the chest (lower half of sternum).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_hand_placement'),
        required: true,
        order: 6,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_compression_depth',
        title: 'Compression depth',
        instructorPrompt: 'Compress at least 2 inches / 5 cm (allow full recoil).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_compression_depth'),
        required: true,
        order: 7,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_compression_rate',
        title: 'Compression rate',
        instructorPrompt: 'Maintain 100–120 compressions per minute.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_compression_rate'),
        required: true,
        order: 8,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_full_recoil',
        title: 'Full recoil',
        instructorPrompt: 'Allow complete chest recoil between compressions; avoid leaning.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_full_recoil'),
        required: true,
        order: 9,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_minimize_interruptions',
        title: 'Minimize interruptions',
        instructorPrompt: 'Minimize pauses; resume compressions quickly after any interruption.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_minimize_interruptions'),
        required: true,
        order: 10,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_30_2_sequence',
        title: '30:2 ratio',
        instructorPrompt: 'Demonstrate 30 compressions followed by 2 breaths with minimal pause.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_30_2_sequence'),
        required: true,
        order: 11,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_effective_breaths',
        title: 'Effective breaths',
        instructorPrompt: 'Give 2 effective breaths (1 second each) with visible chest rise; avoid excessive ventilation.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_effective_breaths'),
        required: true,
        order: 12,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_apply_aed_pads',
        title: 'Apply AED pads',
        instructorPrompt: 'Apply AED pads to the bare chest in the correct positions and follow prompts.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_apply_aed_pads'),
        required: true,
        order: 13,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_clear_before_analysis',
        title: 'Clear before analysis',
        instructorPrompt: 'Ensure everyone is clear before analysis/shock and when prompted by the AED.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_clear_before_analysis'),
        required: true,
        order: 14,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_resume_compressions',
        title: 'Resume CPR',
        instructorPrompt: 'Resume compressions immediately after analysis/shock/no-shock decision per prompts.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_resume_compressions'),
        required: true,
        order: 15,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'adult_team_communication',
        title: 'Team communication',
        instructorPrompt: 'Use clear team communication and role clarity; coordinate smooth transitions when applicable.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('adult_team_communication'),
        required: true,
        order: 16,
        section: sectionPrimary,
      ),
    ];

    return ChecklistDefinition(type: ChecklistType.adult, title: 'Adult BLS Skills', items: items);
  }
}
