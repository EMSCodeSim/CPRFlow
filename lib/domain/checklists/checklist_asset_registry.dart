/// Central registry for checklist images.
///
/// IMPORTANT:
/// - This must be the only place in the codebase that contains checklist image
///   asset paths.
/// - Assets may not be uploaded yet. Return null for missing images.
class ChecklistAssetRegistry {
  static const Map<String, String?> _pathsByItemId = {
    // Adult BLS
    'adult_scene_safety_ppe': null,
    'adult_responsiveness': null,
    'adult_activate_emergency_response': null,
    'adult_retrieve_aed': null,
    'adult_check_breathing_pulse': null,
    'adult_hand_placement': null,
    'adult_compression_rate': null,
    'adult_compression_depth': null,
    'adult_full_recoil': null,
    'adult_minimize_interruptions': null,
    'adult_open_airway': null,
    'adult_pocket_mask_ventilation': null,
    'adult_correct_breaths': null,
    'adult_30_2_sequence': null,
    'adult_aed_operation': null,
    'adult_resume_compressions': null,
    'adult_two_rescuer_teamwork': null,

    // Infant/Child BLS
    'ic_scene_safety_ppe': null,
    'ic_responsiveness': null,
    'ic_activate_emergency_response': null,
    'ic_check_breathing_brachial_pulse': null,
    'ic_infant_compression_placement': null,
    'ic_compression_rate': null,
    'ic_compression_depth': null,
    'ic_30_2_one_rescuer_sequence': null,
    'ic_open_airway': null,
    'ic_pocket_mask_breaths': null,
    'ic_two_rescuer_transition': null,
    'ic_two_thumb_technique': null,
    'ic_15_2_two_rescuer_sequence': null,
    'ic_aed_use_when_applicable': null,
    'ic_resume_cpr': null,
  };

  static String? pathForItem(String itemId) => _pathsByItemId[itemId];

  static Iterable<String> get nonNullPaths => _pathsByItemId.values.whereType<String>();

  static Map<String, String?> get debugAll => Map.unmodifiable(_pathsByItemId);
}
