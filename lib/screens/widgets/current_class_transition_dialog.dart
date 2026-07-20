import 'package:flutter/material.dart';

import 'package:ccf_timer_low_risk_test/app/app_state.dart';

enum CurrentClassDisposition { cancel, archive, discard }

/// Makes creation of a new class explicit when another class is active.
///
/// Returns true only when it is safe for the caller to continue creating the
/// new class. All destructive state changes require instructor confirmation.
Future<bool> prepareForNewClass({
  required BuildContext context,
  required AppState appState,
}) async {
  if (appState.currentClass == null) return true;

  final selected = await showDialog<CurrentClassDisposition>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('A class is already active'),
      content: const Text(
        'Current class, roster, checklist, CCF, and score data is temporary during this restoration stage. '
        'Choose what should happen to the active class before creating another class.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(CurrentClassDisposition.cancel),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(CurrentClassDisposition.archive),
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archive Current Class'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(CurrentClassDisposition.discard),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Discard & Continue'),
        ),
      ],
    ),
  );

  if (selected == null || selected == CurrentClassDisposition.cancel) return false;

  if (selected == CurrentClassDisposition.archive) {
    appState.archiveCurrentClass();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current class archived (temporary).')),
      );
    }
    return true;
  }

  if (appState.currentClassHasStudentsOrEvaluations()) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard current class data?'),
        content: const Text(
          'This permanently clears the active in-memory class, roster, and entered evaluations. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }

  appState.discardCurrentClassAndData();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Current class discarded (temporary).')),
    );
  }
  return true;
}
