import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_asset_registry.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_item_definition.dart';

class InfantChildBlsDefinition {
  static const String sectionPrimary = 'Infant/Child BLS';

  static ChecklistDefinition build() {
    // Infant/Child Phase 2 FINAL sequence (17 steps).
    // NOTE: Some compression artwork is explicitly NOT approved yet.
    // For those steps, we keep imageAssetPath null and the UI will show the
    // “Approved checklist image not yet added.” placeholder.
    final items = <ChecklistItemDefinition>[
      ChecklistItemDefinition(
        id: 'ic_scene_safety_ppe',
        title: 'Scene safety & PPE',
        instructorPrompt: 'Confirm the scene is safe and apply appropriate PPE.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_scene_safety_ppe'),
        required: true,
        order: 1,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_responsiveness',
        title: 'Check responsiveness',
        instructorPrompt: 'Assess responsiveness appropriately for an infant/child.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_responsiveness'),
        required: true,
        order: 2,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_activate_ems',
        title: 'Activate EMS',
        instructorPrompt: 'Direct bystanders to activate emergency response and bring the AED.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_activate_ems'),
        required: true,
        order: 3,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_check_breathing',
        title: 'Check breathing',
        instructorPrompt: 'Check for breathing (≤10 seconds).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_check_breathing'),
        required: true,
        order: 4,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_check_brachial_pulse',
        title: 'Check brachial pulse',
        instructorPrompt: 'Check for brachial pulse (≤10 seconds).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_check_brachial_pulse'),
        required: true,
        order: 5,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_one_rescuer_compressions',
        title: 'One-rescuer compressions',
        instructorPrompt: 'Demonstrate correct one-rescuer compression technique (image pending).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_one_rescuer_compressions'),
        required: true,
        order: 6,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_compression_depth',
        title: 'Compression depth',
        instructorPrompt: 'Demonstrate correct depth (about 1/3 chest depth) (image pending).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_compression_depth'),
        required: true,
        order: 7,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_compression_rate',
        title: 'Compression rate',
        instructorPrompt: 'Demonstrate compressions at 100–120/min (image pending).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_compression_rate'),
        required: true,
        order: 8,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_30_2_ratio',
        title: '30:2 ratio',
        instructorPrompt: 'Demonstrate 30 compressions to 2 breaths (image pending).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_30_2_ratio'),
        required: true,
        order: 9,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_open_airway',
        title: 'Open airway',
        instructorPrompt: 'Open the airway appropriately for infant/child.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_open_airway'),
        required: true,
        order: 10,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_two_breaths',
        title: 'Give breaths',
        instructorPrompt: 'Give 2 effective breaths with visible chest rise.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_two_breaths'),
        required: true,
        order: 11,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_continue_cpr_30_2',
        title: 'Continue CPR (30:2)',
        instructorPrompt: 'Continue CPR at 30:2 until help arrives (image pending).',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_continue_cpr_30_2'),
        required: true,
        order: 12,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_second_rescuer_arrives',
        title: 'Second rescuer arrives',
        instructorPrompt: 'Demonstrate actions/role transition when a second rescuer arrives.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_second_rescuer_arrives'),
        required: true,
        order: 13,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_two_thumb_encircling',
        title: 'Two-thumb encircling technique',
        instructorPrompt: 'Demonstrate the two-thumb encircling-hands technique for infant compressions.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_two_thumb_encircling'),
        required: true,
        order: 14,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_15_2_sequence',
        title: '15:2 sequence',
        instructorPrompt: 'Demonstrate two-rescuer CPR with 15 compressions and 2 breaths.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_15_2_sequence'),
        required: true,
        order: 15,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_bag_mask_ventilation',
        title: 'Bag-mask ventilation',
        instructorPrompt: 'Demonstrate effective ventilation with a bag-mask device.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_bag_mask_ventilation'),
        required: true,
        order: 16,
        section: sectionPrimary,
      ),
      ChecklistItemDefinition(
        id: 'ic_resume_cpr',
        title: 'Resume CPR',
        instructorPrompt: 'Resume CPR immediately after any interruption, following prompts.',
        imageAssetPath: ChecklistAssetRegistry.pathForItem('ic_resume_cpr'),
        required: true,
        order: 17,
        section: sectionPrimary,
      ),
    ];

    return ChecklistDefinition(type: ChecklistType.infantChild, title: 'Infant/Child BLS Skills', items: items);
  }
}
