import 'package:flutter/widgets.dart';

import 'package:ccf_timer_low_risk_test/app/app_state.dart';

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({required AppState appState, required super.child, super.key}) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}
