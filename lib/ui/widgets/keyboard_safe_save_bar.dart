import 'package:flutter/material.dart';

/// Bottom save bar that stays visible above iOS keyboard.
class KeyboardSafeSaveBar extends StatelessWidget {
  const KeyboardSafeSaveBar({super.key, required this.isSaving, required this.onSave, required this.saveLabel, this.isEnabled = true});

  final bool isSaving;
  final Future<void> Function() onSave;
  final String saveLabel;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (keyboardOpen)
                OutlinedButton.icon(
                  onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                  icon: const Icon(Icons.keyboard_hide_outlined),
                  label: const Text('Hide'),
                ),
              if (keyboardOpen) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (isSaving || !isEnabled)
                      ? null
                      : () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await onSave();
                  },
                  icon: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(saveLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
