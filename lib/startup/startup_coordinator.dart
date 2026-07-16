import 'dart:async';

import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/startup/startup_issue.dart';
import 'package:cpr_instructor_doc/startup/startup_state.dart';
import 'package:flutter/foundation.dart';

typedef AppDatabaseFactory = Future<AppDatabase> Function();

/// Coordinates required app startup initialization.
///
/// Requirements addressed:
/// - Shows startup UI immediately
/// - Required init has a timeout
/// - Never infinite loading
/// - Empty storage is OK
/// - Optional init failures never block (Phase 1: no optional init)
/// - Required init failure opens RecoveryScreen
class StartupCoordinator extends ChangeNotifier {
  StartupCoordinator({required AppDatabaseFactory databaseFactory, Duration requiredTimeout = const Duration(seconds: 6)})
    : _databaseFactory = databaseFactory,
      _requiredTimeout = requiredTimeout,
      state = const StartupState.idle();

  final AppDatabaseFactory _databaseFactory;
  final Duration _requiredTimeout;

  StartupState state;
  AppServices? services;
  AppDatabase? _lastDatabase;

  void _log(String message) => debugPrint('[startup] $message');

  Future<void> start() async {
    _log('phase=initializing');
    state = const StartupState.initializing();
    notifyListeners();

    final issues = <StartupIssue>[];
    final startedAt = DateTime.now();
    _log('required_init_start_ms=${startedAt.millisecondsSinceEpoch}');
    try {
      final db = await _withTimeout(_databaseFactory(), _requiredTimeout);
      _lastDatabase = db;

      // Ensure the database is actually open and usable before declaring ready.
      await _withTimeout(db.verifyConnection(), _requiredTimeout);

      services = AppServices(database: db);
      services!.wireCompletionService();
      services!.wirePhase3Services();
      services!.wirePhase4Services();
      state = const StartupState.ready();
      _log('phase=ready');
      notifyListeners();
    } on TimeoutException catch (e, st) {
      _log('required_init_timeout');
      debugPrint('Startup timed out: $e');
      issues.add(
        StartupIssue(
          kind: StartupIssueKind.requiredInitTimedOut,
          message: 'Startup took too long. Please retry.',
          stackTrace: st,
        ),
      );
      await _disposeFailedDatabase();
      state = StartupState.recovery(issues);
      notifyListeners();
    } catch (e, st) {
      _log('required_init_failed');
      debugPrint('Startup failed: $e\n$st');
      final kind = _lastDatabase == null ? StartupIssueKind.databaseOpenFailed : StartupIssueKind.databaseHealthCheckFailed;
      issues.add(
        StartupIssue(
          kind: kind,
          message: 'Required startup failed. Class data could not be opened.',
          stackTrace: st,
        ),
      );
      await _disposeFailedDatabase();
      state = StartupState.recovery(issues);
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _log('action=retry_startup');
    await services?.dispose();
    services = null;
    await _disposeFailedDatabase();
    await start();
  }

  /// Recovery option: Continue without class data.
  ///
  /// This does NOT wipe, migrate, or rewrite anything.
  void openWithoutClassData() {
    _log('action=open_without_class_data');
    services = AppServices.withoutDatabase();
    state = const StartupState.ready();
    notifyListeners();
  }

  Future<void> _disposeFailedDatabase() async {
    try {
      await _lastDatabase?.close();
    } catch (e, st) {
      debugPrint('Failed to close database after startup failure: $e\n$st');
    } finally {
      _lastDatabase = null;
    }
  }

  static Future<T> _withTimeout<T>(Future<T> future, Duration timeout) => future.timeout(timeout);
}
