import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/assets/cpr_image_catalog.dart';
import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/checklist_validation.dart' as cv;
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/screens/safe_error_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/widgets/checklist_instruction_image.dart';

class ChecklistItemDef {
  const ChecklistItemDef({
    required this.id,
    required this.category,
    required this.title,
    required this.instruction,
    required this.imageId,
    this.required = true,
  });

  final String id;
  final String category;
  final String title;
  final String instruction;
  final String? imageId;
  final bool required;
}

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({required this.studentId, required this.kind, super.key});

  final String studentId;
  final ChecklistKind kind;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

enum ChecklistKind { adult, infant }

extension on ChecklistKind {
  String get title => this == ChecklistKind.adult ? 'Adult CPR Checklist' : 'Infant CPR Checklist';
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  Map<String, ChecklistRating> _ratings = {};
  bool _reviewed = false;
  ChecklistDecision _decision = ChecklistDecision.notDecided;
  TextEditingController? _notes;
  Student? _student;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_student != null) return;
    final appState = AppStateScope.of(context);
    final s = appState.getStudent(widget.studentId);
    _student = s;
    if (s == null) return;
    final attempt = widget.kind == ChecklistKind.adult ? s.adultChecklist : s.infantChecklist;
    _ratings = Map.of(attempt.ratings);
    _reviewed = attempt.reviewed;
    _decision = attempt.decision;
    _notes = TextEditingController(text: attempt.instructorNotes);
  }

  @override
  void dispose() {
    _notes?.dispose();
    super.dispose();
  }

  List<ChecklistItemDef> get _items => widget.kind == ChecklistKind.adult ? _adultItems : _infantItems;

  void _setRating(String itemId, ChecklistRating rating) {
    setState(() => _ratings[itemId] = rating);
  }

  Future<void> _save() async {
    final appState = AppStateScope.of(context);
    final notes = (_notes?.text ?? '').trim();

    if (_reviewed) {
      final meta = _items.map((i) => cv.ChecklistItemMeta(id: i.id, title: i.title, required: i.required)).toList(growable: false);
      final validation = cv.ChecklistValidationHelper.validateForReview(
        items: meta,
        ratings: _ratings,
        decision: _decision,
        instructorNotes: notes,
      );

      if (!validation.canSave) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation.messages.first)));
        return;
      }

      if (validation.requiresConfirmation) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(validation.confirmationTitle ?? 'Confirm'),
            content: Text(validation.messages.join('\n\n')),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => context.pop(true), child: const Text('Confirm & Save')),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }

    if (widget.kind == ChecklistKind.adult) {
      appState.updateAdultChecklist(
        studentId: widget.studentId,
        ratings: _ratings,
        reviewed: _reviewed,
        decision: _decision,
        instructorNotes: notes,
      );
    } else {
      appState.updateInfantChecklist(
        studentId: widget.studentId,
        ratings: _ratings,
        reviewed: _reviewed,
        decision: _decision,
        instructorNotes: notes,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist saved (temporary).')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _student;
    if (s == null) {
      return SafeErrorScreen(
        title: 'Student not found',
        message: 'The student identifier is invalid or the student was removed.',
        primaryActionLabel: "Back to Today's Class",
        onPrimaryAction: () => context.go('/today-class'),
      );
    }

    final meta = _items.map((i) => cv.ChecklistItemMeta(id: i.id, title: i.title, required: i.required)).toList(growable: false);
    final summary = cv.ChecklistValidationHelper.summarize(items: meta, ratings: _ratings);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.title),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName.isEmpty ? 'Student' : s.fullName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricChip(label: 'Total', value: '${summary.totalItems}'),
                        _MetricChip(label: 'Applicable', value: '${summary.applicableItems}'),
                        _MetricChip(label: 'Evaluated', value: '${summary.evaluatedApplicableItems}'),
                        _MetricChip(label: 'Meets', value: '${summary.meetsCriteriaCount}'),
                        _MetricChip(label: 'Needs', value: '${summary.needsImprovementCount}'),
                        _MetricChip(label: 'N/A', value: '${summary.notApplicableCount}'),
                        _MetricChip(label: 'Not eval', value: '${summary.notEvaluatedCount}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!summary.isReadyForReview)
                      Text(
                        'Not ready for instructor review: ${summary.notEvaluatedCount} applicable item(s) are still Not Evaluated.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    if (summary.needsImprovementTitles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Skills needing improvement:',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      ...summary.needsImprovementTitles.take(5).map((t) => Text('• $t')),
                      if (summary.needsImprovementTitles.length > 5)
                        Text('• +${summary.needsImprovementTitles.length - 5} more'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._buildCategorySections(context),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Review decision', style: Theme.of(context).textTheme.titleMedium)),
                        Switch.adaptive(value: _reviewed, onChanged: (v) => setState(() => _reviewed = v)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ChecklistDecision>(
                      segments: const [
                        ButtonSegment(value: ChecklistDecision.pass, label: Text('Pass'), icon: Icon(Icons.check_circle_outline)),
                        ButtonSegment(value: ChecklistDecision.needsReview, label: Text('Needs Remediation'), icon: Icon(Icons.error_outline)),
                      ],
                      selected: {_decision}.where((d) => d != ChecklistDecision.notDecided).toSet(),
                      onSelectionChanged: (set) {
                        if (set.isEmpty) {
                          setState(() => _decision = ChecklistDecision.notDecided);
                        } else {
                          setState(() => _decision = set.first);
                        }
                      },
                      emptySelectionAllowed: true,
                      multiSelectionEnabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'Instructor notes', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Not Applicable items are excluded from failure calculations.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Checklist'),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections(BuildContext context) {
    final grouped = <String, List<ChecklistItemDef>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.category, () => <ChecklistItemDef>[]).add(item);
    }

    final categories = grouped.keys.toList(growable: false);
    return categories.map((category) {
      final items = grouped[category]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...items.map((i) => _ChecklistRow(
                      title: i.title,
                       instruction: i.instruction,
                       imageId: i.imageId,
                      rating: _ratings[i.id] ?? ChecklistRating.notEvaluated,
                      onChanged: (r) => _setRating(i.id, r),
                    )),
              ],
            ),
          ),
        ),
      );
    }).toList(growable: false);
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.title, required this.instruction, required this.imageId, required this.rating, required this.onChanged});

  final String title;
  final String instruction;
  final String? imageId;
  final ChecklistRating rating;
  final ValueChanged<ChecklistRating> onChanged;

  @override
  Widget build(BuildContext context) {
    final asset = imageId == null ? null : CprImageCatalog.byId(imageId!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            instruction,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
          ),
          if (asset != null) ...[
            const SizedBox(height: 10),
            ChecklistInstructionImage(asset: asset, skillTitle: title),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 200,
              child: DropdownButtonFormField<ChecklistRating>(
                value: rating,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: ChecklistRating.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label, overflow: TextOverflow.ellipsis)))
                    .toList(growable: false),
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

const _adultItems = <ChecklistItemDef>[
  ChecklistItemDef(
    id: 'scene_safety',
    category: 'Initial assessment',
    title: 'Scene safety and PPE',
    instruction: 'Ensure the scene is safe and apply appropriate PPE before approaching.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'responsiveness',
    category: 'Initial assessment',
    title: 'Responsiveness check',
    instruction: 'Tap and shout. If unresponsive, proceed immediately with assessment and activation.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'activate_ems',
    category: 'Initial assessment',
    title: 'Activating emergency response',
    instruction: 'Activate EMS and get AED (or send a bystander).',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'breathing_pulse',
    category: 'Initial assessment',
    title: 'Breathing and pulse check',
    instruction: 'Check breathing and pulse simultaneously for no more than 10 seconds.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'hand_placement',
    category: 'Compressions',
    title: 'Correct hand placement',
    instruction: 'Place the heel of your hand on the center of the chest, other hand on top. Keep fingers off ribs.',
    imageId: 'adult_hand_placement',
  ),
  ChecklistItemDef(
    id: 'compression_rate',
    category: 'Compressions',
    title: 'Compression rate',
    instruction: 'Maintain 100–120 compressions per minute with consistent rhythm.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'compression_depth',
    category: 'Compressions',
    title: 'Compression depth',
    instruction: 'Compress at least 2 inches (5 cm) and allow full recoil.',
    imageId: 'adult_compression_depth',
  ),
  ChecklistItemDef(
    id: 'recoil',
    category: 'Compressions',
    title: 'Full chest recoil',
    instruction: 'Allow the chest to fully recoil after each compression; do not lean.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'interruptions',
    category: 'Compressions',
    title: 'Minimal interruptions',
    instruction: 'Minimize pauses in compressions; resume immediately after analysis/shock.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'open_airway',
    category: 'Ventilations',
    title: 'Opening airway',
    instruction: 'Use head tilt–chin lift unless trauma suspected.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'pocket_mask',
    category: 'Ventilations',
    title: 'Pocket-mask breaths',
    instruction: 'Ensure a tight seal and deliver each breath over 1 second with visible chest rise.',
    imageId: 'adult_pocket_mask',
  ),
  ChecklistItemDef(
    id: 'ratio_30_2',
    category: 'Ventilations',
    title: 'Correct 30:2 ratio',
    instruction: 'Perform cycles of 30 compressions to 2 breaths.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'aed_operation',
    category: 'AED',
    title: 'AED operation',
    instruction: 'Turn on AED, follow prompts, and apply pads to bare, dry chest.',
    imageId: 'adult_aed_pads',
  ),
  ChecklistItemDef(
    id: 'resume_cpr',
    category: 'AED',
    title: 'Resuming compressions after shock/no-shock',
    instruction: 'Resume compressions immediately after shock or “no shock advised”.',
    imageId: null,
  ),
];

const _infantItems = <ChecklistItemDef>[
  ChecklistItemDef(
    id: 'scene_safety',
    category: 'Initial assessment',
    title: 'Scene safety and PPE',
    instruction: 'Ensure the scene is safe and apply appropriate PPE before approaching.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'responsiveness',
    category: 'Initial assessment',
    title: 'Responsiveness',
    instruction: 'Tap the soles and shout. If unresponsive, proceed with assessment and activation.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'activate_ems',
    category: 'Initial assessment',
    title: 'Activating emergency response',
    instruction: 'Activate EMS and get AED (or send a bystander).',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'breathing_brachial',
    category: 'Initial assessment',
    title: 'Breathing and brachial pulse check',
    instruction: 'Check breathing and brachial pulse simultaneously for no more than 10 seconds.',
    imageId: 'infant_brachial_pulse',
  ),
  ChecklistItemDef(
    id: 'one_rescuer',
    category: 'Compressions',
    title: 'One-rescuer compression technique',
    instruction: 'Use two fingers on the center of the chest just below the nipple line.',
    imageId: 'infant_two_finger',
  ),
  ChecklistItemDef(
    id: 'two_thumb',
    category: 'Compressions',
    title: 'Two-thumb encircling technique',
    instruction: 'Encircle the chest with both hands; place both thumbs on the center of the chest.',
    imageId: 'infant_two_thumb_encircling',
  ),
  ChecklistItemDef(
    id: 'compression_depth',
    category: 'Compressions',
    title: 'Correct compression depth',
    instruction: 'Compress about 1.5 inches (4 cm) or one-third the anterior-posterior diameter.',
    imageId: 'infant_compression_depth',
  ),
  ChecklistItemDef(
    id: 'compression_rate',
    category: 'Compressions',
    title: 'Correct compression rate',
    instruction: 'Maintain 100–120 compressions per minute.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'recoil',
    category: 'Compressions',
    title: 'Full chest recoil',
    instruction: 'Allow the chest to fully recoil after each compression; do not lean.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'interruptions',
    category: 'Compressions',
    title: 'Minimal interruptions',
    instruction: 'Minimize pauses in compressions; resume immediately after analysis/shock.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'open_airway',
    category: 'Ventilations',
    title: 'Opening airway',
    instruction: 'Use head tilt–chin lift unless trauma suspected.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'pocket_mask',
    category: 'Ventilations',
    title: 'Pocket-mask breaths',
    instruction: 'Seal the mask and give each breath over 1 second with visible chest rise. Avoid over-ventilation.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'ratio_30_2',
    category: 'Ventilations',
    title: 'Correct 30:2 ratio',
    instruction: 'Single rescuer: 30 compressions to 2 breaths.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'ratio_15_2',
    category: 'Ventilations',
    title: 'Correct 15:2 ratio (two rescuers)',
    instruction: 'Two rescuers: 15 compressions to 2 breaths.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'aed_peds',
    category: 'AED',
    title: 'AED use with pediatric pads when available',
    instruction: 'Use pediatric pads if available; otherwise follow AED prompts for pad placement.',
    imageId: 'infant_pediatric_aed_pads',
  ),
  ChecklistItemDef(
    id: 'resume_cpr',
    category: 'AED',
    title: 'Resuming CPR',
    instruction: 'Resume compressions immediately after shock or “no shock advised”.',
    imageId: null,
  ),
];
