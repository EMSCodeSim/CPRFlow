import 'package:flutter/foundation.dart';

import 'package:ccf_timer_low_risk_test/app/models.dart';

@immutable
class ChecklistItemMeta {
  const ChecklistItemMeta({required this.id, required this.title, required this.required});

  final String id;
  final String title;
  final bool required;
}

@immutable
class ChecklistSummary {
  const ChecklistSummary({
    required this.totalItems,
    required this.applicableItems,
    required this.evaluatedApplicableItems,
    required this.meetsCriteriaCount,
    required this.needsImprovementCount,
    required this.notApplicableCount,
    required this.notEvaluatedCount,
    required this.needsImprovementTitles,
  });

  final int totalItems;
  final int applicableItems;
  final int evaluatedApplicableItems;
  final int meetsCriteriaCount;
  final int needsImprovementCount;
  final int notApplicableCount;
  final int notEvaluatedCount;
  final List<String> needsImprovementTitles;

  bool get isReadyForReview => applicableItems > 0 && evaluatedApplicableItems == applicableItems;
}

@immutable
class ChecklistReviewValidation {
  const ChecklistReviewValidation._({required this.canSave, required this.messages, required this.requiresConfirmation, required this.confirmationTitle});

  final bool canSave;
  final List<String> messages;
  final bool requiresConfirmation;
  final String? confirmationTitle;

  factory ChecklistReviewValidation.ok() => const ChecklistReviewValidation._(canSave: true, messages: [], requiresConfirmation: false, confirmationTitle: null);

  factory ChecklistReviewValidation.blocked(List<String> messages) =>
      ChecklistReviewValidation._(canSave: false, messages: messages, requiresConfirmation: false, confirmationTitle: null);

  factory ChecklistReviewValidation.confirm({required String title, required List<String> messages}) =>
      ChecklistReviewValidation._(canSave: true, messages: messages, requiresConfirmation: true, confirmationTitle: title);
}

class ChecklistValidationHelper {
  static ChecklistSummary summarize({required List<ChecklistItemMeta> items, required Map<String, ChecklistRating> ratings}) {
    var meets = 0;
    var needs = 0;
    var na = 0;
    var notEval = 0;
    final needsTitles = <String>[];

    for (final item in items) {
      final rating = ratings[item.id] ?? ChecklistRating.notEvaluated;
      switch (rating) {
        case ChecklistRating.meetsCriteria:
          meets++;
        case ChecklistRating.needsImprovement:
          needs++;
          needsTitles.add(item.title);
        case ChecklistRating.notApplicable:
          na++;
        case ChecklistRating.notEvaluated:
          notEval++;
      }
    }

    final total = items.length;
    final applicable = (total - na).clamp(0, total);
    final evaluatedApplicable = (meets + needs).clamp(0, applicable);
    final notEvaluatedApplicable = (applicable - evaluatedApplicable).clamp(0, applicable);

    return ChecklistSummary(
      totalItems: total,
      applicableItems: applicable,
      evaluatedApplicableItems: evaluatedApplicable,
      meetsCriteriaCount: meets,
      needsImprovementCount: needs,
      notApplicableCount: na,
      notEvaluatedCount: notEvaluatedApplicable,
      needsImprovementTitles: List.unmodifiable(needsTitles),
    );
  }

  /// Validates the instructor review portion.
  ///
  /// Important rules enforced:
  /// - No required applicable item may remain Not Evaluated
  /// - Pass/Needs Remediation must be explicitly selected
  /// - Not Applicable excluded from pass/fail counts
  /// - Required Not Applicable items require an instructor note
  /// - Needs Improvement + Pass requires note + confirmation
  /// - All Meet Criteria + Needs Remediation requires note
  static ChecklistReviewValidation validateForReview({
    required List<ChecklistItemMeta> items,
    required Map<String, ChecklistRating> ratings,
    required ChecklistDecision decision,
    required String instructorNotes,
  }) {
    final messages = <String>[];
    final notes = instructorNotes.trim();

    // Required items must be evaluated (or NA) and not left Not Evaluated.
    final missing = <String>[];
    var anyRequiredNotApplicable = false;
    for (final item in items) {
      if (!item.required) continue;
      final r = ratings[item.id] ?? ChecklistRating.notEvaluated;
      if (r == ChecklistRating.notEvaluated) missing.add(item.title);
      if (r == ChecklistRating.notApplicable) anyRequiredNotApplicable = true;
    }
    if (missing.isNotEmpty) {
      messages.add('Evaluate all required items before marking reviewed. Missing: ${missing.take(4).join(', ')}${missing.length > 4 ? '…' : ''}');
    }

    if (decision == ChecklistDecision.notDecided) {
      messages.add('Select Pass or Needs Remediation.');
    }

    final summary = summarize(items: items, ratings: ratings);
    if (!summary.isReadyForReview) {
      messages.add('Checklist is not ready for review: ${summary.notEvaluatedCount} applicable item(s) still Not Evaluated.');
    }

    if (anyRequiredNotApplicable && notes.isEmpty) {
      messages.add('Instructor note required when a required skill is marked Not Applicable.');
    }

    if (messages.isNotEmpty) return ChecklistReviewValidation.blocked(messages);

    // Confirmation / explanation rules.
    if (summary.needsImprovementCount > 0 && decision == ChecklistDecision.pass) {
      if (notes.isEmpty) {
        return ChecklistReviewValidation.blocked([
          'Instructor note required when selecting Pass with Needs Improvement items.',
        ]);
      }

      return ChecklistReviewValidation.confirm(
        title: 'Pass with Needs Improvement?',
        messages: [
          '${summary.needsImprovementCount} item(s) are marked Needs Improvement.',
          'Confirm Pass and keep your instructor note explaining the decision.',
        ],
      );
    }

    if (summary.needsImprovementCount == 0 && decision == ChecklistDecision.needsReview) {
      if (notes.isEmpty) {
        return ChecklistReviewValidation.blocked([
          'Instructor note required when selecting Needs Remediation while all items meet criteria.',
        ]);
      }
    }

    return ChecklistReviewValidation.ok();
  }
}
