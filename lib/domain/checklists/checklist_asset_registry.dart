/// Central registry for checklist images.
///
/// IMPORTANT:
/// - This must be the only place in the codebase that contains checklist image
///   asset paths.
/// - Assets may not be uploaded yet. Return null for missing images.
class ChecklistAssetRegistry {
  static const Map<String, String?> _pathsByItemId = {
    // Adult BLS (FINAL stable IDs for Phase 2 — do not rename)
    // 1) adult_scene_safety_ppe -> assets/bls/01_scene_safety.png
    'adult_scene_safety_ppe': 'assets/bls/01_scene_safety.png',
    // 2) adult_responsiveness -> assets/bls/02_check_responsiveness.png
    'adult_responsiveness': 'assets/bls/02_check_responsiveness.png',
    // 3) adult_activate_ems_retrieve_aed -> assets/bls/03_activate_ems.png
    'adult_activate_ems_retrieve_aed': 'assets/bls/03_activate_ems.png',
    // 4) adult_check_breathing_pulse -> assets/bls/04_check_breathing_pulse.png
    'adult_check_breathing_pulse': 'assets/bls/04_check_breathing_pulse.png',
    // 5) adult_start_compressions -> assets/bls/05_start_compressions.png
    'adult_start_compressions': 'assets/bls/05_start_compressions.png',
    // 6) adult_hand_placement -> assets/bls/06_hand_placement.png
    'adult_hand_placement': 'assets/bls/06_hand_placement.png',
    // 7) adult_compression_depth -> assets/bls/07_compression_depth.png
    'adult_compression_depth': 'assets/bls/07_compression_depth.png',
    // 8) adult_compression_rate -> assets/bls/08_compression_rate.png
    'adult_compression_rate': 'assets/bls/08_compression_rate.png',
    // 9) adult_full_recoil -> assets/bls/09_full_recoil.png
    'adult_full_recoil': 'assets/bls/09_full_recoil.png',
    // 10) adult_minimize_interruptions -> assets/bls/10_minimize_interruptions.png
    'adult_minimize_interruptions': 'assets/bls/10_minimize_interruptions.png',
    // 11) adult_30_2_sequence -> assets/bls/11_30_2_ratio.png
    'adult_30_2_sequence': 'assets/bls/11_30_2_ratio.png',
    // 12) adult_effective_breaths -> assets/bls/12_effective_breaths.png
    'adult_effective_breaths': 'assets/bls/12_effective_breaths.png',
    // 13) adult_apply_aed_pads -> assets/bls/13_apply_aed_pads.png
    'adult_apply_aed_pads': 'assets/bls/13_apply_aed_pads.png',
    // 14) adult_clear_before_analysis -> assets/bls/14_clear_before_analysis.png
    'adult_clear_before_analysis': 'assets/bls/14_clear_before_analysis.png',
    // 15) adult_resume_compressions -> assets/bls/15_resume_cpr.png
    'adult_resume_compressions': 'assets/bls/15_resume_cpr.png',
    // 16) adult_team_communication -> assets/bls/16_team_communication.png
    'adult_team_communication': 'assets/bls/16_team_communication.png',

    // Adult BLS (deprecated Phase 1/early Phase 2 IDs — keep for data migration)
    'adult_activate_emergency_response': null,
    'adult_retrieve_aed': null,
    'adult_open_airway': null,
    'adult_pocket_mask_ventilation': null,
    'adult_correct_breaths': null,
    'adult_aed_operation': null,
    'adult_two_rescuer_teamwork': null,
    'adult_scene_safety_and_ppe': null,
    'adult_activate_ems': null,
    'adult_retrieve_aed_apply_pads': null,
    'adult_aed_pads': null,
    'adult_clear': null,
    'adult_resume_cpr': null,

    // Infant/Child BLS
    // (FINAL stable IDs for Phase 2 — do not rename)
    // Step 01
    'ic_scene_safety_ppe': 'assets/bls/infant/infant_step_01_scene_safety.png',
    // Step 02
    'ic_responsiveness': 'assets/bls/infant/infant_step_02_check_response.png',
    // Step 03
    'ic_activate_ems': 'assets/bls/infant/infant_step_03_activate_ems.png',
    // Step 04
    'ic_check_breathing': 'assets/bls/infant/infant_step_04_check_breathing.png',
    // Step 05
    'ic_check_brachial_pulse': 'assets/bls/infant/infant_step_05_check_brachial_pulse.png',
    // Step 06 (UNAPPROVED compression artwork; keep null)
    'ic_one_rescuer_compressions': null,
    // Step 07 (UNAPPROVED compression artwork; keep null)
    'ic_compression_depth': null,
    // Step 08 (UNAPPROVED compression artwork; keep null)
    'ic_compression_rate': null,
    // Step 09 (UNAPPROVED compression artwork; keep null)
    'ic_30_2_ratio': null,
    // Step 10
    'ic_open_airway': 'assets/bls/infant/infant_step_10_open_airway.png',
    // Step 11
    'ic_two_breaths': 'assets/bls/infant/infant_step_11_two_breaths.png',
    // Step 12 (UNAPPROVED compression artwork; keep null)
    'ic_continue_cpr_30_2': null,
    // Step 13
    'ic_second_rescuer_arrives': 'assets/bls/infant/infant_step_13_second_rescuer_arrives.png',
    // Step 14 (approved only for this step)
    'ic_two_thumb_encircling': 'assets/bls/infant/infant_step_14_two_thumb_encircling.png',
    // Step 15
    'ic_15_2_sequence': 'assets/bls/infant/infant_step_15_continue_cpr_15_2.png',
    // Step 16
    'ic_bag_mask_ventilation': 'assets/bls/infant/infant_step_16_bag_mask_ventilation.png',
    // Step 17
    'ic_resume_cpr': 'assets/bls/infant/infant_step_17_resume_cpr.png',

    // Infant/Child BLS (deprecated Phase 1/early Phase 2 IDs — keep for migration)
    'ic_activate_emergency_response': null,
    'ic_check_breathing_brachial_pulse': null,
    'ic_infant_compression_placement': null,
    'ic_30_2_one_rescuer_sequence': null,
    'ic_pocket_mask_breaths': null,
    'ic_two_rescuer_transition': null,
    'ic_two_thumb_technique': null,
    'ic_15_2_two_rescuer_sequence': null,
    'ic_aed_use_when_applicable': null,
  };

  static String? pathForItem(String itemId) => _pathsByItemId[itemId];

  static Iterable<String> get nonNullPaths => _pathsByItemId.values.whereType<String>();

  static Map<String, String?> get debugAll => Map.unmodifiable(_pathsByItemId);
}
