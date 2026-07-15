import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:flutter/widgets.dart';

/// Simple dependency container for the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) => services != oldWidget.services;
}
