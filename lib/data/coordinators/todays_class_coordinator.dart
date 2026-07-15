import 'dart:async';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/classes/todays_class_view_model.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class TodaysClassCoordinator {
  TodaysClassCoordinator({
    required AppDatabase db,
    required StudentCompletionService completionService,
  })  : _db = db,
        _completionService = completionService;

  final AppDatabase _db;
  final StudentCompletionService _completionService;

  StreamSubscription<ClassRecord?>? _activeClassSub;
  StreamSubscription<List<StudentRecord>>? _studentsSub;
  StreamSubscription<List<ChecklistAttempt>>? _attemptsSub;
  StreamSubscription<List<TypedResult>>? _resultsSub;
  StreamSubscription<List<CcfSession>>? _ccfSub;

  final StreamController<TodaysClassViewModel?> _controller =
      StreamController<TodaysClassViewModel?>.broadcast();

  ClassRecord? _activeClass;
  List<StudentRecord> _students = const [];
  List<ChecklistAttempt> _attempts = const [];
  List<ChecklistItemResult> _itemResults = const [];
  List<CcfSession> _ccfSessions = const [];

  TodaysClassViewModel? _last;
  Future<void> _resubscribeSerial = Future<void>.value();
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;

  /// Replays the latest view model first, then emits future changes.
  Stream<TodaysClassViewModel?> get stream async* {
    yield _last;
    yield* _controller.stream;
  }

  TodaysClassViewModel? get latest => _last;

  void startWatching() {
    if (_started || _disposed) return;
    _started = true;
    _activeClassSub = (_db.select(_db.classRecords)
          ..where((table) => table.isActive.equals(true))
          ..limit(1))
        .watchSingleOrNull()
        .listen(
      (clazz) {
        if (_disposed) return;
        _activeClass = clazz;
        _queueResubscribe(clazz);
      },
      onError: _addError,
    );
  }

  void _queueResubscribe(ClassRecord? clazz) {
    final generation = ++_generation;
    _resubscribeSerial = _resubscribeSerial.then((_) async {
      await _resubscribeForActiveClass(clazz, generation);
    }).catchError((Object error, StackTrace stackTrace) {
      _addError(error, stackTrace);
    });
  }

  Future<void> _resubscribeForActiveClass(
    ClassRecord? clazz,
    int generation,
  ) async {
    await _cancelClassScopedSubscriptions();
    if (_disposed || generation != _generation) return;

    _students = const [];
    _attempts = const [];
    _itemResults = const [];
    _ccfSessions = const [];

    if (clazz == null) {
      _emit(generation: generation);
      return;
    }

    final classId = clazz.id;

    _studentsSub = (_db.select(_db.studentRecords)
          ..where((table) => table.classId.equals(classId))
          ..orderBy([
            (table) => OrderingTerm(expression: table.displayName),
          ]))
        .watch()
        .listen(
      (rows) {
        if (!_isCurrent(generation, classId)) return;
        _students = rows;
        _emit(generation: generation);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isCurrent(generation, classId)) {
          _addError(error, stackTrace);
        }
      },
    );

    _attemptsSub = (_db.select(_db.checklistAttempts)
          ..where((table) => table.classId.equals(classId))
          ..orderBy([
            (table) => OrderingTerm(
                  expression: table.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch()
        .listen(
      (rows) {
        if (!_isCurrent(generation, classId)) return;
        _attempts = rows;
        _emit(generation: generation);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isCurrent(generation, classId)) {
          _addError(error, stackTrace);
        }
      },
    );

    final resultsJoin = _db.select(_db.checklistItemResults).join([
      innerJoin(
        _db.checklistAttempts,
        _db.checklistAttempts.id
            .equalsExp(_db.checklistItemResults.attemptId),
      ),
    ])
      ..where(_db.checklistAttempts.classId.equals(classId));
    _resultsSub = resultsJoin.watch().listen(
      (rows) {
        if (!_isCurrent(generation, classId)) return;
        _itemResults = [
          for (final row in rows) row.readTable(_db.checklistItemResults),
        ];
        _emit(generation: generation);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isCurrent(generation, classId)) {
          _addError(error, stackTrace);
        }
      },
    );

    _ccfSub = (_db.select(_db.ccfSessions)
          ..where((table) => table.classId.equals(classId))
          ..orderBy([
            (table) => OrderingTerm(
                  expression: table.startedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch()
        .listen(
      (rows) {
        if (!_isCurrent(generation, classId)) return;
        _ccfSessions = rows;
        _emit(generation: generation);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isCurrent(generation, classId)) {
          _addError(error, stackTrace);
        }
      },
    );
  }

  bool _isCurrent(int generation, String classId) =>
      !_disposed &&
      generation == _generation &&
      _activeClass?.id == classId;

  Future<void> _cancelClassScopedSubscriptions() async {
    final students = _studentsSub;
    final attempts = _attemptsSub;
    final results = _resultsSub;
    final ccf = _ccfSub;
    _studentsSub = null;
    _attemptsSub = null;
    _resultsSub = null;
    _ccfSub = null;

    await students?.cancel();
    await attempts?.cancel();
    await results?.cancel();
    await ccf?.cancel();
  }

  void requestRecompute() => _emit(generation: _generation);

  void _addError(Object error, [StackTrace? stackTrace]) {
    debugPrint('TodaysClassCoordinator stream failed: $error\n$stackTrace');
    if (_disposed || _controller.isClosed) return;
    _controller.addError(error, stackTrace);
  }

  void _emit({required int generation}) {
    if (_disposed || _controller.isClosed || generation != _generation) return;

    final clazz = _activeClass;
    if (clazz == null) {
      _last = null;
      _controller.add(null);
      return;
    }

    final resultsByAttempt = <String, List<ChecklistItemResult>>{};
    for (final result in _itemResults) {
      resultsByAttempt.putIfAbsent(result.attemptId, () => []).add(result);
    }

    final attemptsByStudent = <String, List<ChecklistAttempt>>{};
    for (final attempt in _attempts) {
      attemptsByStudent
          .putIfAbsent(attempt.studentId, () => [])
          .add(attempt);
    }

    final ccfByStudent = <String, List<CcfSession>>{};
    for (final session in _ccfSessions) {
      final studentId = session.studentId;
      if (studentId == null) continue;
      ccfByStudent.putIfAbsent(studentId, () => []).add(session);
    }

    final rows = <StudentProgressRow>[];
    var passed = 0;
    var incomplete = 0;
    var failed = 0;
    var adultComplete = 0;
    var infantComplete = 0;
    var requiredCcfComplete = 0;
    var missingScore = 0;

    for (final student in _students) {
      StudentCompletionResult completion;
      Object? calculationError;
      try {
        completion = _completionService.computeForStudentFromData(
          clazz: clazz,
          student: student,
          attemptsForStudent: attemptsByStudent[student.id] ?? const [],
          itemResultsByAttemptId: resultsByAttempt,
          ccfSessionsForStudent: ccfByStudent[student.id] ?? const [],
        );
      } catch (error, stackTrace) {
        debugPrint(
          'TodaysClass completion failed for ${student.id}: '
          '$error\n$stackTrace',
        );
        calculationError = error;
        completion = StudentCompletionResult(
          adultStatus: ChecklistStatus.incomplete,
          infantChildStatus: ChecklistStatus.incomplete,
          ccfStatus: clazz.ccfRequired
              ? RequirementStatus.incomplete
              : RequirementStatus.notRequired,
          writtenTestStatus: clazz.writtenTestRequired
              ? RequirementStatus.incomplete
              : RequirementStatus.notRequired,
          overallResult: OverallStudentResult.incomplete,
          missingRequirements: const [],
          failureReasons: const [],
          completionPercentage: 0,
          validationWarnings: const [],
        );
      }

      final writtenDisplay = _writtenScoreDisplay(clazz, student);
      if (clazz.writtenTestRequired && student.writtenTestScore == null) {
        missingScore += 1;
      }
      if (completion.adultStatus == ChecklistStatus.passed) {
        adultComplete += 1;
      }
      if (completion.infantChildStatus == ChecklistStatus.passed) {
        infantComplete += 1;
      }
      if (clazz.ccfRequired &&
          completion.ccfStatus == RequirementStatus.passed) {
        requiredCcfComplete += 1;
      }

      switch (completion.overallResult) {
        case OverallStudentResult.pass:
          if (calculationError == null) {
            passed += 1;
          } else {
            incomplete += 1;
          }
          break;
        case OverallStudentResult.fail:
          failed += 1;
          break;
        case OverallStudentResult.incomplete:
          incomplete += 1;
          break;
      }

      rows.add(
        StudentProgressRow(
          student: student,
          completion: completion,
          writtenScoreDisplay: writtenDisplay,
          calculationError: calculationError,
        ),
      );
    }

    final viewModel = TodaysClassViewModel(
      classRecord: clazz,
      students: rows,
      totalStudents: rows.length,
      passedCount: passed,
      incompleteCount: incomplete,
      failedCount: failed,
      adultCompleteCount: adultComplete,
      infantChildCompleteCount: infantComplete,
      requiredCcfCompleteCount: requiredCcfComplete,
      missingScoreCount: missingScore,
    );
    _last = viewModel;
    _controller.add(viewModel);
  }

  String _writtenScoreDisplay(ClassRecord clazz, StudentRecord student) {
    if (!clazz.writtenTestRequired) return 'N/A';
    final score = student.writtenTestScore;
    if (score == null) return 'Not Entered';
    if (!student.writtenTestingFinalized) return 'Unfinalized';
    return '$score%';
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    await _activeClassSub?.cancel();
    _activeClassSub = null;
    try {
      await _resubscribeSerial;
    } catch (_) {
      // Any error has already been surfaced through the coordinator stream.
    }
    await _cancelClassScopedSubscriptions();
    await _controller.close();
  }
}
