import 'dart:async';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/local/app_database_executor.dart';
import 'package:cpr_instructor_doc/startup/startup_coordinator.dart';
import 'package:cpr_instructor_doc/startup/startup_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StartupCoordinator becomes ready on successful init', () async {
    final coordinator = StartupCoordinator(databaseFactory: () async => AppDatabase.inMemory(), requiredTimeout: const Duration(seconds: 2));
    await coordinator.start();
    expect(coordinator.state.phase, StartupPhase.ready);
    expect(coordinator.services, isNotNull);
  });

  test('StartupCoordinator verifies database connection before ready', () async {
    var verified = false;
    final coordinator = StartupCoordinator(
      databaseFactory: () async {
        final db = _TestDb(openAppDatabaseTestExecutor(), onVerify: () => verified = true);
        return db;
      },
      requiredTimeout: const Duration(seconds: 2),
    );
    await coordinator.start();
    expect(coordinator.state.phase, StartupPhase.ready);
    expect(verified, true);
  });

  test('StartupCoordinator enters recovery on timeout', () async {
    final coordinator = StartupCoordinator(
      databaseFactory: () async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return AppDatabase.inMemory();
      },
      requiredTimeout: const Duration(milliseconds: 50),
    );
    await coordinator.start();
    expect(coordinator.state.phase, StartupPhase.recovery);
    expect(coordinator.state.issues, isNotEmpty);
  });

  test('Open without class data still becomes ready', () async {
    final coordinator = StartupCoordinator(databaseFactory: () async => throw StateError('boom'), requiredTimeout: const Duration(seconds: 1));
    await coordinator.start();
    expect(coordinator.state.phase, StartupPhase.recovery);
    coordinator.openWithoutClassData();
    expect(coordinator.state.phase, StartupPhase.ready);
    expect(coordinator.services?.hasClassData, false);
  });

  test('Retry creates a new database instance after a failure', () async {
    var calls = 0;
    late AppDatabase first;
    late AppDatabase second;

    final coordinator = StartupCoordinator(
      databaseFactory: () async {
        calls++;
        if (calls == 1) {
          first = _FailingVerifyDb(openAppDatabaseTestExecutor());
          return first;
        }
        second = AppDatabase.inMemory();
        return second;
      },
      requiredTimeout: const Duration(seconds: 2),
    );

    await coordinator.start();
    expect(coordinator.state.phase, StartupPhase.recovery);
    await coordinator.retry();
    expect(coordinator.state.phase, StartupPhase.ready);
    expect(identical(first, second), false);
    expect(calls, 2);
  });
}

class _TestDb extends AppDatabase {
  _TestDb(super.e, {required this.onVerify});

  final VoidCallback onVerify;

  @override
  Future<void> verifyConnection() async {
    onVerify();
    await super.verifyConnection();
  }
}

class _FailingVerifyDb extends AppDatabase {
  _FailingVerifyDb(super.e);

  @override
  Future<void> verifyConnection() async {
    throw StateError('verify failed');
  }
}
