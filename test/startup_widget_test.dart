import 'dart:async';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/startup/startup_coordinator.dart';
import 'package:cpr_instructor_doc/startup/startup_widget.dart';
import 'package:cpr_instructor_doc/ui/home/home_screen.dart';
import 'package:cpr_instructor_doc/ui/routes/recovery_screen.dart';
import 'package:cpr_instructor_doc/ui/routes/startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Startup screen appears immediately', (tester) async {
    final completer = Completer<AppDatabase>();
    final coordinator = StartupCoordinator(databaseFactory: () => completer.future, requiredTimeout: const Duration(seconds: 2));

    await tester.pumpWidget(
      StartupWidget(
        coordinator: coordinator,
        lightTheme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      ),
    );

    // First frame: startup UI should be visible even though the DB isn't ready.
    expect(find.byType(StartupScreen), findsOneWidget);

    // Complete startup.
    completer.complete(AppDatabase.inMemory());
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('RecoveryRequired displays RecoveryScreen', (tester) async {
    final coordinator = StartupCoordinator(databaseFactory: () async => _FailingVerifyDb(AppDatabase.inMemory()), requiredTimeout: const Duration(seconds: 2));

    await tester.pumpWidget(
      StartupWidget(
        coordinator: coordinator,
        lightTheme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(RecoveryScreen), findsOneWidget);
  });
}

class _FailingVerifyDb extends AppDatabase {
  _FailingVerifyDb(this._delegate) : super(_delegate.executor);

  final AppDatabase _delegate;

  @override
  Future<void> verifyConnection() async {
    throw StateError('verify failed');
  }
}
