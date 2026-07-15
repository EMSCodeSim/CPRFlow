import 'dart:async';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/classes/todays_class_view_model.dart';
import 'package:cpr_instructor_doc/domain/completion/completion_status.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_result.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class TodaysClassCoordinator {
  TodaysClassCoordinator({required AppDatabase db, required StudentCompletionService completionService})
      : _db = db,
        _completionService = completionService;

  final AppDatabase _db;
  final StudentCompletionService _completionService;

  StreamSubscription? _activeClassSub;
  StreamSubscription? _studentsSub;
  StreamSubscription? _attemptsSub;
  StreamSubscription? _resultsSub;
  StreamSubscription? _ccfSub;

  final _controller = StreamController<TodaysClassViewModel?>.broadcast();
  ClassRecord? _activeClass;

  List<StudentRecord> _students = const [];
  List<ChecklistAttempt> _attempts = const [];
  List<ChecklistItemResult> _itemResults = const [];
  List<CcfSession> _ccfSessions = const [];

  TodaysClassViewModel? _last;

  Stream<TodaysClassViewModel?> get stream => _controller.stream;
  TodaysClassViewModel? get latest => _last;

  void startWatching() {
    _activeClassSub ??= (_db.select(_db.classRecords)..where((t) => t.isActive.equals(true))).watchSingleOrNull().listen((clazz) {
      _activeClass = clazz;
      _resubscribeForActiveClass();
    }, onError: (e, st) {
      debugPrint('TodaysClassCoordinator watchActiveClass failed: $e\n$st');
      _controller.addError(e, st);
    });
  }

  void _resubscribeForActiveClass() {
    final clazz = _activeClass;
    _studentsSub?.cancel();
    _attemptsSub?.cancel();
    _resultsSub?.cancel();
    _ccfSub?.cancel();
    _studentsSub = null;
    _attemptsSub = null;
    _resultsSub = null;
    _ccfSub = null;

    _students = const [];
    _attempts = const [];
    _itemResults = const [];
    _ccfSessions = const [];

    if (clazz == null) {
      _emit();
      return;
    }

    _studentsSub = (_db.select(_db.studentRecords)
          ..where((t) => t.classId.equals(clazz.id))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .watch()
        .listen((rows) {
      _students = rows;
      _emit();
    }, onError: (e, st) {
      debugPrint('TodaysClassCoordinator watchStudents failed: $e\n$st');
      _controller.addError(e, st);
    });

    _attemptsSub = (_db.select(_db.checklistAttempts)
          ..where((t) => t.classId.equals(clazz.id))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch()
        .listen((rows) {
      _attempts = rows;
      _emit();
    }, onError: (e, st) {
      debugPrint('TodaysClassCoordinator watchAttempts failed: $e\n$st');
      _controller.addError(e, st);
    });

    final resultsJoin = _db.select(_db.checklistItemResults).join([
      innerJoin(_db.checklistAttempts, _db.checklistAttempts.id.equalsExp(_db.checklistItemResults.attemptId)),
    ])
      ..where(_db.checklistAttempts.classId.equals(clazz.id));
    _resultsSub = resultsJoin.watch().listen((rows) {
      _itemResults = [for (final r in rows) r.readTable(_db.checklistItemResults)];
      _emit();
    }, onError: (e, st) {
      debugPrint('TodaysClassCoordinator watchItemResults failed: $e\n$st');
      _controller.addError(e, st);
    });

    _ccfSub = (_db.select(_db.ccfSessions)
          ..where((t) => t.classId.equals(clazz.id))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .watch()
        .listen((rows) {
      _ccfSessions = rows;
      _emit();
    }, onError: (e, st) {
      debugPrint('TodaysClassCoordinator watchCCF failed: $e\n$st');
      _controller.addError(e, st);
    });
  }

  void requestRecompute() => _emit();

  void _emit() {
    final clazz = _activeClass;
    if (clazz == null) {
      _last = null;
      _controller.add(null);
      return;
    }

    final resultsByAttempt = <String, List<ChecklistItemResult>>{};
    for (final r in _itemResults) {
      resultsByAttempt.putIfAbsent(r.attemptId, () => []).add(r);
    }

    final attemptsByStudent = <String, List<ChecklistAttempt>>{};
    for (final a in _attempts) {
      attemptsByStudent.putIfAbsent(a.studentId, () => []).add(a);
    }

    final ccfByStudent = <String, List<CcfSession>>{};
    for (final s in _ccfSessions) {
      final sid = s.studentId;
      if (sid == null) continue;
      ccfByStudent.putIfAbsent(sid, () => []).add(s);
    }

    final rows = <StudentProgressRow>[];
    var passed = 0;
    var incomplete = 0;
    var failed = 0;
    var adultComplete = 0;
    var infantComplete = 0;
    var ccfCompleteReq = 0;
    var missingScore = 0;

    for (final student in _students) {
      StudentCompletionResult completion;
      Object? error;
      try {
        completion = _completionService.computeForStudentFromData(
          clazz: clazz,
          student: student,
          attemptsForStudent: attemptsByStudent[student.id] ?? const [],
          itemResultsByAttemptId: resultsByAttempt,
          ccfSessionsForStudent: ccfByStudent[student.id] ?? const [],
        );
      } catch (e, st) {
        debugPrint('TodaysClass completion failed for ${student.id}: $e\n$st');
        error = e;
        completion = StudentCompletionResult(
          adultStatus: ChecklistStatus.incomplete,
          infantChildStatus: ChecklistStatus.incomplete,
          ccfStatus: clazz.ccfRequired ? RequirementStatus.incomplete : RequirementStatus.notRequired,
          writtenTestStatus: clazz.writtenTestRequired ? RequirementStatus.incomplete : RequirementStatus.notRequired,
          overallResult: OverallStudentResult.incomplete,
          missingRequirements: const [],
          failureReasons: const [],
          completionPercentage: 0,
          validationWarnings: const [],
        );
      }

      String writtenDisplay;
      if (!clazz.writtenTestRequired) {
        writtenDisplay = 'N/A';
      } else if (student.writtenTestScore == null) {
        writtenDisplay = 'Not Entered';
        missingScore += 1;
      } else if (!student.writtenTestingFinalized) {
        writtenDisplay = 'Unfinalized';
      } else {
        writtenDisplay = '${student.writtenTestScore}';
      }

      if (completion.adultStatus == ChecklistStatus.passed) adultComplete += 1;
      if (completion.infantChildStatus == ChecklistStatus.passed) infantComplete += 1;
      if (clazz.ccfRequired && completion.ccfStatus == RequirementStatus.passed) ccfCompleteReq += 1;

      switch (completion.overallResult) {
        case OverallStudentResult.pass:
          passed += 1;
          break;
        case OverallStudentResult.fail:
          failed += 1;
          break;
        case OverallStudentResult.incomplete:
          incomplete += 1;
          break;
      }

      // Never treat a calc error as passed.
      if (error != null && completion.overallResult == OverallStudentResult.pass) {
        passed -= 1;
        incomplete += 1;
      }

      rows.add(
        StudentProgressRow(
          student: student,
          completion: completion,
          writtenScoreDisplay: writtenDisplay,
          calculationError: error,
        ),
      );
    }

    final vm = TodaysClassViewModel(
      classRecord: clazz,
      students: rows,
      totalStudents: rows.length,
      passedCount: passed,
      incompleteCount: incomplete,
      failedCount: failed,
      adultCompleteCount: adultComplete,
      infantChildCompleteCount: infantComplete,
      requiredCcfCompleteCount: ccfCompleteReq,
      missingScoreCount: missingScore,
    );
    _last = vm;
    _controller.add(vm);
  }

  Future<void> dispose() async {
    await _activeClassSub?.cancel();
    await _studentsSub?.cancel();
    await _attemptsSub?.cancel();
    await _resultsSub?.cancel();
    await _ccfSub?.cancel();
    await _controller.close();
  }
}
