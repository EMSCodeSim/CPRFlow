import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_asset_registry.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_item_definition.dart';

class InfantChildBlsDefinition {
  static const String sectionPrimary = 'Infant/Child BLS';

  static ChecklistDefinition build() {
    final items = <ChecklistItemDefinition>[
      ChecklistItemDefinition(
        id: 'ic_scene_safety_ppe',
        title: 'Scene safety and PPE',
        instructorPrompt: 'Confirm the scene is safe and apply appropriate PPE.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_scene_safety_ppe'),
        required: true,
        order: 1,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_responsiveness',
        title: 'Assess responsiveness',
        instructorPrompt: 'Assess responsiveness appropriately for infant/child.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_responsiveness'),
        required: true,
        order: 2,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_activate_emergency_response',
        title: 'Activate emergency response',
        instructorPrompt: 'Direct bystanders to activate emergency response and bring the AED.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_activate_emergency_response'),
        required: true,
        order: 3,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_check_breathing_brachial_pulse',
        title: 'Check breathing and brachial pulse',
        instructorPrompt: 'Check for breathing and brachial pulse simultaneously (≤10 seconds).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_check_breathing_brachial_pulse'),
        required: true,
        order: 4,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_infant_compression_placement',
        title: 'Correct infant compression placement',
        instructorPrompt: 'Demonstrate correct infant compression placement (two-thumb encircling-hands technique when applicable).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_infant_compression_placement'),
        required: true,
        order: 5,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_compression_rate',
        title: 'Compression rate',
        instructorPrompt: 'Demonstrate compressions at an appropriate rate (100–120/min).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_compression_rate'),
        required: true,
        order: 6,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_compression_depth',
        title: 'Compression depth',
        instructorPrompt: 'Demonstrate correct depth (about 1/3 chest depth).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_compression_depth'),
        required: true,
        order: 7,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_30_2_one_rescuer_sequence',
        title: '30:2 one-rescuer sequence',
        instructorPrompt: 'Demonstrate one-rescuer CPR with 30 compressions and 2 breaths.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_30_2_one_rescuer_sequence'),
        required: true,
        order: 8,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_open_airway',
        title: 'Open airway',
        instructorPrompt: 'Open the airway appropriately for infant/child.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_open_airway'),
        required: true,
        order: 9,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_pocket_mask_breaths',
        title: 'Pocket-mask breaths',
        instructorPrompt: 'Provide effective breaths with visible chest rise.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_pocket_mask_breaths'),
        required: true,
        order: 10,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_two_rescuer_transition',
        title: 'Two-rescuer transition',
        instructorPrompt: 'Demonstrate a smooth transition to two-rescuer CPR when a second rescuer arrives.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_two_rescuer_transition'),
        required: false,
        order: 11,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_two_thumb_technique',
        title: 'Two-thumb encircling-hands technique',
        instructorPrompt: 'Demonstrate the two-thumb encircling-hands technique for infant compressions.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_two_thumb_technique'),
        required: false,
        order: 12,
        section: sectionPrimary,
        optionalTeachingNote: 'Required when doing a two-rescuer infant scenario.',
      ),
      ChecklistItemDefinition(
        id: 'ic_15_2_two_rescuer_sequence',
        title: '15:2 two-rescuer sequence',
        instructorPrompt: 'Demonstrate two-rescuer CPR with 15 compressions and 2 breaths.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_15_2_two_rescuer_sequence'),
        required: false,
        order: 13,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_aed_use_when_applicable',
        title: 'AED use when applicable',
        instructorPrompt: 'Demonstrate appropriate AED use (pads, prompts, clear).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_aed_use_when_applicable'),
        required: true,
        order: 14,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_resume_cpr',
        title: 'Resume CPR',
        instructorPrompt: 'Resume CPR immediately after analysis/shock/no-shock decision per prompts.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_resume_cpr'),
        required: true,
        order: 15,
        section: sectionPrimary,
      ),
    ];

    return ChecklistDefinition(type: ChecklistType.infantChild, title: 'Infant/Child BLS Skills', items: items);
  }
}
