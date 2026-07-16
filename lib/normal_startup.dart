import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/startup/startup_coordinator.dart';
import 'package:cpr_instructor_doc/startup/startup_widget.dart';
import 'package:cpr_instructor_doc/theme.dart';
import 'package:flutter/material.dart';

/// Starts the full application.
///
/// This is intentionally split out of `main.dart` so the diagnostic startup path
/// can avoid importing any database / startup / DI code.
void startNormalApp() {
  final coordinator = StartupCoordinator(databaseFactory: AppDatabase.open);
  runApp(_CCFTimerApp(coordinator: coordinator));
}

class _CCFTimerApp extends StatelessWidget {
  const _CCFTimerApp({required this.coordinator});

  final StartupCoordinator coordinator;

  @override
  Widget build(BuildContext context) =>
      StartupWidget(coordinator: coordinator, lightTheme: lightTheme, darkTheme: darkTheme);
}
