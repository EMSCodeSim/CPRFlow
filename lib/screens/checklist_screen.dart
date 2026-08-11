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
  String get title => this == ChecklistKind.adult
      ? 'Adult CPR Checklist'
      : 'Infant CPR Checklist';

  String get shortTitle =>
      this == ChecklistKind.adult ? 'Adult CPR' : 'Infant CPR';
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _pageController = PageController(viewportFraction: 0.94);

  Map<String, ChecklistRating> _ratings = {};
  bool _reviewed = false;
  ChecklistDecision _decision = ChecklistDecision.notDecided;
  TextEditingController? _notes;
  Student? _student;
  int _currentIndex = 0;

  List<ChecklistItemDef> get _items =>
      widget.kind == ChecklistKind.adult ? _adultItems : _infantItems;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_student != null) return;

    final appState = AppStateScope.of(context);
    final student = appState.getStudent(widget.studentId);
    _student = student;
    if (student == null) return;

    final attempt = widget.kind == ChecklistKind.adult
        ? student.adultChecklist
        : student.infantChecklist;

    _ratings = Map.of(attempt.ratings);
    _reviewed = attempt.reviewed;
    _decision = attempt.decision;
    _notes = TextEditingController(text: attempt.instructorNotes);

    final firstIncomplete = _items.indexWhere(
      (item) =>
          (_ratings[item.id] ?? ChecklistRating.notEvaluated) ==
          ChecklistRating.notEvaluated,
    );
    if (firstIncomplete >= 0) _currentIndex = firstIncomplete;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _currentIndex > 0) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _notes?.dispose();
    super.dispose();
  }

  void _rateAndAdvance(String itemId, ChecklistRating rating) {
    setState(() => _ratings[itemId] = rating);

    if (_currentIndex >= _items.length - 1) return;
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _save() async {
    final appState = AppStateScope.of(context);
    final notes = (_notes?.text ?? '').trim();

    if (_reviewed) {
      final meta = _items
          .map(
            (item) => cv.ChecklistItemMeta(
              id: item.id,
              title: item.title,
              required: item.required,
            ),
          )
          .toList(growable: false);

      final validation = cv.ChecklistValidationHelper.validateForReview(
        items: meta,
        ratings: _ratings,
        decision: _decision,
        instructorNotes: notes,
      );

      if (!validation.canSave) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation.messages.first)),
        );
        return;
      }

      if (validation.requiresConfirmation) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(validation.confirmationTitle ?? 'Confirm'),
            content: Text(validation.messages.join('\n\n')),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('Confirm & Save'),
              ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.kind.title} saved.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final student = _student;
    if (student == null) {
      return SafeErrorScreen(
        title: 'Student not found',
        message: 'The student identifier is invalid or the student was removed.',
        primaryActionLabel: "Back to Today's Class",
        onPrimaryAction: () => context.go('/today-class'),
      );
    }

    final evaluatedCount = _items.where((item) {
      return (_ratings[item.id] ?? ChecklistRating.notEvaluated) !=
          ChecklistRating.notEvaluated;
    }).length;
    final progress = _items.isEmpty ? 0.0 : evaluatedCount / _items.length;

    final meta = _items
        .map(
          (item) => cv.ChecklistItemMeta(
            id: item.id,
            title: item.title,
            required: item.required,
          ),
        )
        .toList(growable: false);
    final summary = cv.ChecklistValidationHelper.summarize(
      items: meta,
      ratings: _ratings,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName.isEmpty ? 'Student' : student.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.kind.shortTitle} • Skill ${_currentIndex + 1} of ${_items.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$evaluatedCount/${_items.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 14),
            SizedBox(
              height: 510,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _SkillCard(
                      item: item,
                      position: index + 1,
                      total: _items.length,
                      rating: _ratings[item.id] ?? ChecklistRating.notEvaluated,
                      onRating: (rating) => _rateAndAdvance(item.id, rating),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous skill',
                  onPressed: _currentIndex == 0
                      ? null
                      : () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 8),
                Text(
                  'Swipe left or right',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Next skill',
                  onPressed: _currentIndex >= _items.length - 1
                      ? null
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Final ${widget.kind.title} review',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch.adaptive(
                          value: _reviewed,
                          onChanged: (value) =>
                              setState(() => _reviewed = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary.isReadyForReview
                          ? 'All applicable skills have been evaluated.'
                          : '${summary.notEvaluatedCount} skill(s) still need a rating.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ChecklistDecision>(
                      segments: const [
                        ButtonSegment(
                          value: ChecklistDecision.pass,
                          label: Text('Pass'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                        ButtonSegment(
                          value: ChecklistDecision.needsReview,
                          label: Text('Needs Remediation'),
                          icon: Icon(Icons.error_outline),
                        ),
                      ],
                      selected: {_decision}
                          .where((d) => d != ChecklistDecision.notDecided)
                          .toSet(),
                      onSelectionChanged: (set) => setState(
                        () => _decision = set.isEmpty
                            ? ChecklistDecision.notDecided
                            : set.first,
                      ),
                      emptySelectionAllowed: true,
                      multiSelectionEnabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Instructor notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: Text('Save ${widget.kind.title}'),
          ),
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.item,
    required this.position,
    required this.total,
    required this.rating,
    required this.onRating,
  });

  final ChecklistItemDef item;
  final int position;
  final int total;
  final ChecklistRating rating;
  final ValueChanged<ChecklistRating> onRating;

  @override
  Widget build(BuildContext context) {
    final asset = item.imageId == null ? null : CprImageCatalog.byId(item.imageId!);
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.category.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  '$position / $total',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              item.instruction,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            if (asset != null)
              Expanded(
                child: Center(
                  child: ChecklistInstructionImage(
                    asset: asset,
                    skillTitle: item.title,
                  ),
                ),
              )
            else
              const Spacer(),
            if (rating != ChecklistRating.notEvaluated) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Current: ${rating.label}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: () =>
                          onRating(ChecklistRating.meetsCriteria),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'PASS',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          onRating(ChecklistRating.needsImprovement),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'NEEDS WORK',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => onRating(ChecklistRating.notApplicable),
                child: const Text('Not Applicable'),
              ),
            ),
          ],
        ),
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
    instruction: 'Place the heel of one hand on the center of the chest, place the other hand on top, and keep fingers off the ribs.',
    imageId: 'adult_hand_placement',
  ),
  ChecklistItemDef(
    id: 'compression_rate',
    category: 'Compressions',
    title: 'Compression rate',
    instruction: 'Maintain 100–120 compressions per minute with a consistent rhythm.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'compression_depth',
    category: 'Compressions',
    title: 'Compression depth',
    instruction: 'Compress at least 2 inches (5 cm), avoid excessive depth, and allow full recoil.',
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
    instruction: 'Minimize pauses in compressions and resume immediately after analysis or shock.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'open_airway',
    category: 'Ventilations',
    title: 'Opening airway',
    instruction: 'Use head tilt–chin lift unless trauma is suspected.',
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
    instruction: 'Turn on the AED, follow prompts, and apply pads to a bare, dry chest.',
    imageId: 'adult_aed_pads',
  ),
  ChecklistItemDef(
    id: 'resume_cpr',
    category: 'AED',
    title: 'Resume compressions after shock/no shock',
    instruction: 'Resume compressions immediately after a shock or a no-shock-advised decision.',
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
    title: 'Infant compression technique',
    instruction: 'Use the heel of one hand or the two-thumb encircling-hands technique on the center of the chest.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'two_thumb',
    category: 'Compressions',
    title: 'Two-thumb encircling-hands technique',
    instruction: 'Encircle the chest with both hands and place both thumbs on the center of the chest.',
    imageId: 'infant_two_thumb_encircling',
  ),
  ChecklistItemDef(
    id: 'compression_depth',
    category: 'Compressions',
    title: 'Correct compression depth',
    instruction: 'Compress about 1.5 inches (4 cm), or one-third the anterior-posterior diameter of the chest.',
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
    instruction: 'Minimize pauses in compressions and resume immediately after analysis or shock.',
    imageId: null,
  ),
  ChecklistItemDef(
    id: 'open_airway',
    category: 'Ventilations',
    title: 'Opening airway',
    instruction: 'Use head tilt–chin lift unless trauma is suspected.',
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
    instruction: 'Resume compressions immediately after a shock or a no-shock-advised decision.',
    imageId: null,
  ),
];
