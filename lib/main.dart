import 'dart:async';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/startup/startup_coordinator.dart';
import 'package:cpr_instructor_doc/startup/startup_widget.dart';
import 'package:cpr_instructor_doc/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  // Dreamflow's Web preview may initialize Flutter bindings in a different
  // zone before calling our `main()`. Using runZonedGuarded can therefore
  // trigger Flutter's "Zone mismatch" assertion during `runApp`.
  //
  // We still capture framework + async errors via the standard handlers.
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
  };

  ErrorWidget.builder = (details) {
    final message = details.exceptionAsString();
    debugPrint('Fatal widget build error: $message\n${details.stack}');
    return Material(
      color: const Color(0xFFFDF7F7),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'CCF Timer could not open this screen',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Close and reopen the app. The technical message below identifies the exact failing widget.',
              ),
              const SizedBox(height: 16),
              SelectableText(message),
            ],
          ),
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true;
  };

  final coordinator = StartupCoordinator(databaseFactory: AppDatabase.open);
  runApp(CCFTimerApp(coordinator: coordinator));
}

class CCFTimerApp extends StatelessWidget {
  const CCFTimerApp({super.key, required this.coordinator});

  final StartupCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return StartupWidget(coordinator: coordinator, lightTheme: lightTheme, darkTheme: darkTheme);
  }
}
