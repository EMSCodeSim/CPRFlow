import 'package:flutter/services.dart';

enum CprImageCategory { adult, infant, common }

/// One CPR instructional image asset.
///
/// NOTE: We only reference real, existing assets. If an asset is missing or
/// medically questionable, set [assetPath] to null and record [unavailableReason].
class CprImageAsset {
  const CprImageAsset({
    required this.id,
    required this.category,
    required this.title,
    required this.recommendedStep,
    required this.semanticLabel,
    required this.assetPath,
    required this.approvedForInstruction,
    required this.unavailableReason,
  });

  final String id;
  final CprImageCategory category;
  final String title;
  final String recommendedStep;
  final String semanticLabel;
  final String? assetPath;

  /// If false, the UI should treat this as unavailable even if [assetPath]
  /// exists (e.g., technique appears incorrect).
  final bool approvedForInstruction;

  /// Human-readable reason when [assetPath] is null or [approvedForInstruction]
  /// is false.
  final String? unavailableReason;

  bool get isAvailable => assetPath != null && approvedForInstruction;
}

/// Centralized catalog for all CPR instructional images currently present in
/// the repo.
class CprImageCatalog {
  // =====================
  // Adult CPR (assets/bls)
  // =====================
  static const adultSceneSafety = CprImageAsset(
    id: 'adult_scene_safety',
    category: CprImageCategory.adult,
    title: 'Scene safety',
    recommendedStep: 'Scene safety and PPE',
    semanticLabel: 'Scene safety and PPE concept',
    assetPath: 'assets/bls/01_scene_safety.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultResponsiveness = CprImageAsset(
    id: 'adult_responsiveness',
    category: CprImageCategory.adult,
    title: 'Responsiveness check',
    recommendedStep: 'Responsiveness check',
    semanticLabel: 'Checking responsiveness',
    assetPath: 'assets/bls/02_check_responsiveness.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultActivateEms = CprImageAsset(
    id: 'adult_activate_ems',
    category: CprImageCategory.adult,
    title: 'Activate emergency response',
    recommendedStep: 'Activating emergency response',
    semanticLabel: 'Activating emergency response concept',
    assetPath: 'assets/bls/03_activate_ems.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultBreathingPulse = CprImageAsset(
    id: 'adult_breathing_pulse',
    category: CprImageCategory.adult,
    title: 'Breathing and pulse check',
    recommendedStep: 'Breathing and pulse check',
    semanticLabel: 'Checking breathing and pulse',
    assetPath: 'assets/bls/04_check_breathing_pulse.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultStartCompressions = CprImageAsset(
    id: 'adult_start_compressions',
    category: CprImageCategory.adult,
    title: 'Start compressions',
    recommendedStep: 'Start compressions',
    semanticLabel: 'Starting chest compressions concept',
    assetPath: 'assets/bls/05_start_compressions.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultHandPlacement = CprImageAsset(
    id: 'adult_hand_placement',
    category: CprImageCategory.adult,
    title: 'Hand placement',
    recommendedStep: 'Correct hand placement',
    semanticLabel: 'Adult CPR hand placement on the center of the chest',
    assetPath: 'assets/bls/06_hand_placement.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultCompressionRate = CprImageAsset(
    id: 'adult_compression_rate',
    category: CprImageCategory.adult,
    title: 'Compression rate',
    recommendedStep: 'Compression rate',
    semanticLabel: 'Adult CPR compression rate concept',
    assetPath: 'assets/bls/08_compression_rate.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultCompressionDepth = CprImageAsset(
    id: 'adult_compression_depth',
    category: CprImageCategory.adult,
    title: 'Compression depth',
    recommendedStep: 'Compression depth',
    semanticLabel: 'Adult CPR compression depth concept',
    assetPath: 'assets/bls/07_compression_depth.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultFullRecoil = CprImageAsset(
    id: 'adult_full_recoil',
    category: CprImageCategory.adult,
    title: 'Full chest recoil',
    recommendedStep: 'Full chest recoil',
    semanticLabel: 'Allowing full chest recoil concept',
    assetPath: 'assets/bls/09_full_recoil.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultMinimizeInterruptions = CprImageAsset(
    id: 'adult_minimize_interruptions',
    category: CprImageCategory.adult,
    title: 'Minimize interruptions',
    recommendedStep: 'Minimal interruptions',
    semanticLabel: 'Minimizing interruptions in compressions concept',
    assetPath: 'assets/bls/10_minimize_interruptions.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultRatio302 = CprImageAsset(
    id: 'adult_ratio_30_2',
    category: CprImageCategory.adult,
    title: '30:2 ratio',
    recommendedStep: 'Correct 30:2 ratio',
    semanticLabel: '30 compressions to 2 breaths concept',
    assetPath: 'assets/bls/11_30_2_ratio.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultPocketMask = CprImageAsset(
    id: 'adult_pocket_mask',
    category: CprImageCategory.adult,
    title: 'Pocket-mask ventilation',
    recommendedStep: 'Pocket-mask breaths',
    semanticLabel: 'Pocket-mask breaths technique concept',
    assetPath: 'assets/bls/12_effective_breaths.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultAedPads = CprImageAsset(
    id: 'adult_aed_pads',
    category: CprImageCategory.adult,
    title: 'AED pad placement',
    recommendedStep: 'AED operation',
    semanticLabel: 'AED pad placement concept',
    assetPath: 'assets/bls/13_apply_aed_pads.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultClearBeforeAnalysis = CprImageAsset(
    id: 'adult_clear_before_analysis',
    category: CprImageCategory.adult,
    title: 'Clear before analysis',
    recommendedStep: 'AED operation',
    semanticLabel: 'Clear the patient before AED analysis concept',
    assetPath: 'assets/bls/14_clear_before_analysis.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultResumeCpr = CprImageAsset(
    id: 'adult_resume_cpr',
    category: CprImageCategory.adult,
    title: 'Resume CPR',
    recommendedStep: 'Resume compressions',
    semanticLabel: 'Resuming CPR concept',
    assetPath: 'assets/bls/15_resume_cpr.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const adultTeamCommunication = CprImageAsset(
    id: 'adult_team_communication',
    category: CprImageCategory.adult,
    title: 'Team communication',
    recommendedStep: 'Team communication',
    semanticLabel: 'Team communication during resuscitation concept',
    assetPath: 'assets/bls/16_team_communication.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  // ======================
  // Infant CPR (assets/bls/infant)
  // ======================
  static const infantSceneSafety = CprImageAsset(
    id: 'infant_scene_safety',
    category: CprImageCategory.infant,
    title: 'Scene safety',
    recommendedStep: 'Scene safety and PPE',
    semanticLabel: 'Scene safety and PPE concept',
    assetPath: 'assets/bls/infant/infant_step_01_scene_safety.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantResponsiveness = CprImageAsset(
    id: 'infant_responsiveness',
    category: CprImageCategory.infant,
    title: 'Responsiveness check',
    recommendedStep: 'Responsiveness',
    semanticLabel: 'Checking infant responsiveness',
    assetPath: 'assets/bls/infant/infant_step_02_check_response.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantActivateEms = CprImageAsset(
    id: 'infant_activate_ems',
    category: CprImageCategory.infant,
    title: 'Activate emergency response',
    recommendedStep: 'Activating emergency response',
    semanticLabel: 'Activating emergency response concept',
    assetPath: 'assets/bls/infant/infant_step_03_activate_ems.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantCheckBreathing = CprImageAsset(
    id: 'infant_check_breathing',
    category: CprImageCategory.infant,
    title: 'Check breathing',
    recommendedStep: 'Breathing assessment',
    semanticLabel: 'Checking infant breathing concept',
    assetPath: 'assets/bls/infant/infant_step_04_check_breathing.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantBrachialPulse = CprImageAsset(
    id: 'infant_brachial_pulse',
    category: CprImageCategory.infant,
    title: 'Brachial pulse check',
    recommendedStep: 'Breathing and brachial pulse check',
    semanticLabel: 'Brachial pulse check location concept',
    assetPath: 'assets/bls/infant/infant_step_05_check_brachial_pulse.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantTwoFinger = CprImageAsset(
    id: 'infant_two_finger',
    category: CprImageCategory.infant,
    title: 'One-rescuer two-finger compressions',
    recommendedStep: 'One-rescuer compression technique',
    semanticLabel: 'Infant CPR two-finger compression technique concept',
    assetPath: 'assets/bls/infant/infant_step_06_one_rescuer_compressions.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantTwoThumbEncircling = CprImageAsset(
    id: 'infant_two_thumb_encircling',
    category: CprImageCategory.infant,
    title: 'Two-thumb encircling technique',
    recommendedStep: 'Two-thumb encircling technique',
    semanticLabel: 'Infant CPR two-thumb encircling technique concept',
    assetPath: 'assets/bls/infant/infant_step_14_two_thumb_encircling.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantCompressionDepth = CprImageAsset(
    id: 'infant_compression_depth',
    category: CprImageCategory.infant,
    title: 'Compression depth',
    recommendedStep: 'Correct compression depth',
    semanticLabel: 'Infant CPR compression depth concept',
    assetPath: 'assets/bls/infant/infant_step_07_compression_depth.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantCompressionRate = CprImageAsset(
    id: 'infant_compression_rate',
    category: CprImageCategory.infant,
    title: 'Compression rate',
    recommendedStep: 'Correct compression rate',
    semanticLabel: 'Infant CPR compression rate concept',
    assetPath: 'assets/bls/infant/infant_step_08_compression_rate.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantRatio302 = CprImageAsset(
    id: 'infant_ratio_30_2',
    category: CprImageCategory.infant,
    title: '30:2 ratio',
    recommendedStep: 'Correct 30:2 ratio',
    semanticLabel: '30 compressions to 2 breaths concept',
    assetPath: 'assets/bls/infant/infant_step_09_30_to_2_ratio.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantOpenAirway = CprImageAsset(
    id: 'infant_open_airway',
    category: CprImageCategory.infant,
    title: 'Open airway',
    recommendedStep: 'Opening airway',
    semanticLabel: 'Opening infant airway concept',
    assetPath: 'assets/bls/infant/infant_step_10_open_airway.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantTwoBreaths = CprImageAsset(
    id: 'infant_two_breaths',
    category: CprImageCategory.infant,
    title: 'Give two breaths',
    recommendedStep: 'Two breaths',
    semanticLabel: 'Giving two breaths concept',
    assetPath: 'assets/bls/infant/infant_step_11_two_breaths.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantContinueCpr302 = CprImageAsset(
    id: 'infant_continue_cpr_30_2',
    category: CprImageCategory.infant,
    title: 'Continue CPR (30:2)',
    recommendedStep: 'Continue CPR 30:2',
    semanticLabel: 'Continue CPR 30:2 concept',
    assetPath: 'assets/bls/infant/infant_step_12_continue_cpr_30_2.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantSecondRescuerArrives = CprImageAsset(
    id: 'infant_second_rescuer_arrives',
    category: CprImageCategory.infant,
    title: 'Second rescuer arrives',
    recommendedStep: 'Second rescuer arrives',
    semanticLabel: 'Second rescuer arrives concept',
    assetPath: 'assets/bls/infant/infant_step_13_second_rescuer_arrives.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantBagMaskVentilation = CprImageAsset(
    id: 'infant_bag_mask_ventilation',
    category: CprImageCategory.infant,
    title: 'Bag-mask ventilation',
    recommendedStep: 'Bag-mask breaths',
    semanticLabel: 'Infant bag-mask ventilation concept',
    assetPath: 'assets/bls/infant/infant_step_16_bag_mask_ventilation.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantPocketMask = CprImageAsset(
    id: 'infant_pocket_mask',
    category: CprImageCategory.infant,
    title: 'Pocket-mask ventilation',
    recommendedStep: 'Pocket-mask breaths',
    semanticLabel: 'Infant pocket-mask ventilation concept',
    assetPath: null,
    approvedForInstruction: false,
    unavailableReason: 'No dedicated infant pocket-mask asset found in current project assets.',
  );

  static const infantContinueCpr152 = CprImageAsset(
    id: 'infant_continue_cpr_15_2',
    category: CprImageCategory.infant,
    title: 'Continue CPR (15:2)',
    recommendedStep: 'Correct 15:2 ratio (two rescuers)',
    semanticLabel: 'Continue CPR 15:2 concept',
    assetPath: 'assets/bls/infant/infant_step_15_continue_cpr_15_2.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantResumeCpr = CprImageAsset(
    id: 'infant_resume_cpr',
    category: CprImageCategory.infant,
    title: 'Resume CPR',
    recommendedStep: 'Resuming CPR',
    semanticLabel: 'Resuming CPR concept',
    assetPath: 'assets/bls/infant/infant_step_17_resume_cpr.png',
    approvedForInstruction: true,
    unavailableReason: null,
  );

  static const infantPediatricAedPads = CprImageAsset(
    id: 'infant_pediatric_aed_pads',
    category: CprImageCategory.infant,
    title: 'Pediatric AED pad placement',
    recommendedStep: 'AED use with pediatric pads when available',
    semanticLabel: 'Pediatric AED pad placement concept',
    assetPath: null,
    approvedForInstruction: false,
    unavailableReason: 'No pediatric AED pad asset found in current project assets.',
  );

  /// All known CPR-related image assets in the repository.
  ///
  /// This list is used by the internal `/asset-test` screen.
  static const all = <CprImageAsset>[
    // Adult
    adultSceneSafety,
    adultResponsiveness,
    adultActivateEms,
    adultBreathingPulse,
    adultStartCompressions,
    adultHandPlacement,
    adultCompressionRate,
    adultCompressionDepth,
    adultFullRecoil,
    adultMinimizeInterruptions,
    adultRatio302,
    adultPocketMask,
    adultAedPads,
    adultClearBeforeAnalysis,
    adultResumeCpr,
    adultTeamCommunication,
    // Infant
    infantSceneSafety,
    infantResponsiveness,
    infantActivateEms,
    infantCheckBreathing,
    infantBrachialPulse,
    infantTwoFinger,
    infantTwoThumbEncircling,
    infantCompressionDepth,
    infantCompressionRate,
    infantRatio302,
    infantOpenAirway,
    infantTwoBreaths,
    infantContinueCpr302,
    infantSecondRescuerArrives,
    infantBagMaskVentilation,
    infantPocketMask,
    infantContinueCpr152,
    infantPediatricAedPads,
    infantResumeCpr,
  ];

  static CprImageAsset? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Best-effort asset byte size. Returns null if the asset is missing.
  static Future<int?> tryLoadByteSize(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.lengthInBytes;
    } catch (_) {
      return null;
    }
  }
}
