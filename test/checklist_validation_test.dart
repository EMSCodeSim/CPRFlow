import 'package:flutter_test/flutter_test.dart';

import 'package:ccf_timer_low_risk_test/app/checklist_validation.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';

void main() {
  const items = [
    ChecklistItemMeta(id: 'a', title: 'Skill A', required: true),
    ChecklistItemMeta(id: 'b', title: 'Skill B', required: true),
  ];

  test('review is blocked while required items are not evaluated', () {
    final result = ChecklistValidationHelper.validateForReview(
      items: items,
      ratings: const {'a': ChecklistRating.meetsCriteria},
      decision: ChecklistDecision.pass,
      instructorNotes: '',
    );

    expect(result.canSave, isFalse);
  });

  test('not applicable is excluded but requires a note for required skills', () {
    final blocked = ChecklistValidationHelper.validateForReview(
      items: items,
      ratings: const {
        'a': ChecklistRating.notApplicable,
        'b': ChecklistRating.meetsCriteria,
      },
      decision: ChecklistDecision.pass,
      instructorNotes: '',
    );
    expect(blocked.canSave, isFalse);

    final allowed = ChecklistValidationHelper.validateForReview(
      items: items,
      ratings: const {
        'a': ChecklistRating.notApplicable,
        'b': ChecklistRating.meetsCriteria,
      },
      decision: ChecklistDecision.pass,
      instructorNotes: 'Skill A was not part of this station.',
    );
    expect(allowed.canSave, isTrue);
  });

  test('pass with needs improvement requires confirmation', () {
    final result = ChecklistValidationHelper.validateForReview(
      items: items,
      ratings: const {
        'a': ChecklistRating.needsImprovement,
        'b': ChecklistRating.meetsCriteria,
      },
      decision: ChecklistDecision.pass,
      instructorNotes: 'Instructor reviewed the overall performance.',
    );

    expect(result.canSave, isTrue);
    expect(result.requiresConfirmation, isTrue);
  });
}
