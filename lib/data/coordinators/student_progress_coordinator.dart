import 'dart:async';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class StudentProgressViewModel {
  const StudentProgressViewModel({
    required this.classRecord,
    required this.student,
    required this.completion,
    required this.finalizedCcfAttempts,
    required this.calculationError,
  });

  final ClassRecord? classRecord;
  final StudentRecord? student;
  final StudentCompletionResult? completion;
  final List<CcfSession> finalizedCcfAttempts;
  final Object? calculationError;

  static StudentProgressViewModel empty() => const StudentProgressViewModel(
        classRecord: null,
        student: null,
        completion: null,
        finalizedCcfAttempts: <CcfSession>[],
        calculationError: null,
      );
}

/// Reactive coordinator for the Student Progress screen.
///
/// Watches:
/// - Active class
/// - Selected student
/// - Checklist attempts for the student
/// - Item results for those attempts
/// - CCF sessions for the student
///
/// Then recomputes completion immediately whenever any dependent record changes.
class StudentProgressCoordinator {
  StudentProgressCoordinator({required AppDatabase db, required StudentCompletionService completionService, required String studentId})
      : _db = db,
        _completionService = completionService,
        _studentId = studentId;

  final AppDatabase _db;
  final StudentCompletionService _completionService;
  final String _studentId;

  final StreamController<StudentProgressViewModel> _controller = StreamController<StudentProgressViewModel>.broadcast();
  Stream<StudentProgressViewModel> get stream => _controller.stream;
  StudentProgressViewModel latest = StudentProgressViewModel.empty();

  StreamSubscription<ClassRecord?>? _activeClassSub;
  StreamSubscription<StudentRecord?>? _studentSub;
  StreamSubscription<List<ChecklistAttempt>>? _attemptsSub;
  StreamSubscription<List<CcfSession>>? _ccfSub;

  final Map<String, StreamSubscription<List<ChecklistItemResult>>> _itemSubsByAttemptId = {};
  final Map<String, List<ChecklistItemResult>> _itemResultsByAttemptId = {};
  List<ChecklistAttempt> _attempts = const [];
  List<CcfSession> _ccfSessions = const [];
  ClassRecord? _activeClass;
  StudentRecord? _student;

  bool _started = false;
  bool _disposed = false;

  void startWatching() {
    if (_started) return;
    _started = true;

    _activeClassSub = (_db.select(_db.classRecords)..where((t) => t.isActive.equals(true))..limit(1)).watchSingleOrNull().listen(
      (clazz) {
        _activeClass = clazz;
        _emit();
      },
      onError: (e, st) {
        debugPrint('StudentProgressCoordinator watchActiveClass failed: $e\n$st');
        _emit(calculationError: e);
      },
    );

    _studentSub = (_db.select(_db.studentRecords)..where((t) => t.id.equals(_studentId))..limit(1)).watchSingleOrNull().listen(
      (student) {
        _student = student;
        _emit();
      },
      onError: (e, st) {
        debugPrint('StudentProgressCoordinator watchStudent failed: $e\n$st');
        _emit(calculationError: e);
      },
    );

    _attemptsSub = (_db.select(_db.checklistAttempts)
          ..where((t) => t.studentId.equals(_studentId))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch()
        .listen(
      (attempts) async {
        _attempts = attempts;
        await _resetItemResultWatchers(attempts);
        _emit();
      },
      onError: (e, st) {
        debugPrint('StudentProgressCoordinator watchAttempts failed: $e\n$st');
        _emit(calculationError: e);
      },
    );

    _ccfSub = (_db.select(_db.ccfSessions)
          ..where((t) => t.studentId.equals(_studentId))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .watch()
        .listen(
      (sessions) {
        _ccfSessions = sessions;
        _emit();
      },
      onError: (e, st) {
        debugPrint('StudentProgressCoordinator watchCCF failed: $e\n$st');
        _emit(calculationError: e);
      },
    );
  }

  Future<void> _resetItemResultWatchers(List<ChecklistAttempt> attempts) async {
    final wanted = attempts.map((a) => a.id).toSet();

    // Cancel removed attempt watchers.
    final removed = _itemSubsByAttemptId.keys.where((id) => !wanted.contains(id)).toList();
    for (final attemptId in removed) {
      final sub = _itemSubsByAttemptId.remove(attemptId);
      _itemResultsByAttemptId.remove(attemptId);
      await sub?.cancel();
    }

    // Start new attempt watchers.
    for (final attempt in attempts) {
      if (_itemSubsByAttemptId.containsKey(attempt.id)) continue;
      _itemSubsByAttemptId[attempt.id] = (_db.select(_db.checklistItemResults)
            ..where((t) => t.attemptId.equals(attempt.id))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch()
          .listen(
        (rows) {
          _itemResultsByAttemptId[attempt.id] = rows;
          _emit();
        },
        onError: (e, st) {
          debugPrint('StudentProgressCoordinator watchItemResults failed: $e\n$st');
          _emit(calculationError: e);
        },
      );
    }
  }

  void _emit({Object? calculationError}) {
    if (_disposed || _controller.isClosed) return;

    final clazz = _activeClass;
    final student = _student;

    // Reject mismatch (must match active class).
    if (clazz != null && student != null && student.classId != clazz.id) {
      latest = StudentProgressViewModel(
        classRecord: null,
        student: null,
        completion: null,
        finalizedCcfAttempts: const <CcfSession>[],
        calculationError: StateError('Student does not belong to the active class'),
      );
      _controller.add(latest);
      return;
    }

    StudentCompletionResult? completion;
    Object? error = calculationError;
    if (error == null && clazz != null && student != null) {
      try {
        completion = _completionService.computeForStudentFromData(
          clazz: clazz,
          student: student,
          attemptsForStudent: _attempts,
          itemResultsByAttemptId: _itemResultsByAttemptId,
          ccfSessionsForStudent: _ccfSessions,
        );
      } catch (e, st) {
        debugPrint('StudentProgressCoordinator compute failed: $e\n$st');
        error = e;
      }
    }

    final finalized = _ccfSessions.where((s) => s.finalized).toList()
      ..sort((a, b) {
        final aKey = a.endedAt ?? a.startedAt;
        final bKey = b.endedAt ?? b.startedAt;
        return bKey.compareTo(aKey);
      });

    latest = StudentProgressViewModel(
      classRecord: clazz,
      student: student,
      completion: completion,
      finalizedCcfAttempts: finalized,
      calculationError: error,
    );
    _controller.add(latest);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _activeClassSub?.cancel();
    await _studentSub?.cancel();
    await _attemptsSub?.cancel();
    await _ccfSub?.cancel();
    for (final sub in _itemSubsByAttemptId.values) {
      await sub.cancel();
    }
    _itemSubsByAttemptId.clear();
    _itemResultsByAttemptId.clear();
    await _controller.close();
  }
}
