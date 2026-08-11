import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ccf_timer_low_risk_test/app/completion_evaluator.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/services/preferences_service.dart';
import 'package:ccf_timer_low_risk_test/utils/id_generator.dart';

/// Single source of truth for the instructor workflow.
///
/// Class, roster, checklist, CCF, test-score, and archive data are restored
/// from a versioned local snapshot and automatically saved after each change.
class AppState extends ChangeNotifier {
  AppState({
    IdGenerator? idGenerator,
    PreferencesService? preferencesService,
    String? initialSnapshotJson,
  })  : _ids = idGenerator ?? IdGenerator(),
        _preferencesService = preferencesService {
    if (initialSnapshotJson != null && initialSnapshotJson.trim().isNotEmpty) {
      _restoreSnapshot(initialSnapshotJson);
    }
  }

  final IdGenerator _ids;
  final PreferencesService? _preferencesService;
  Future<void> _saveQueue = Future<void>.value();

  CourseClass? _currentClass;
  final Map<String, CourseClass> _classes = {};
  final Map<String, Student> _studentsById = {};
  final Map<String, List<String>> _studentIdsByClassId = {};
  final List<ArchivedClass> _archive = [];

  CourseClass? get currentClass => _currentClass;

  List<Student> studentsForCurrentClass() {
    final c = _currentClass;
    if (c == null) return const [];
    final ids = _studentIdsByClassId[c.id] ?? const [];
    return ids.map((id) => _studentsById[id]).whereType<Student>().toList(growable: false);
  }

  List<ArchivedClass> get archivedClasses => List.unmodifiable(_archive);

  List<CourseClass> get activeClasses => _classes.values.toList(growable: false);

  bool get hasAnyActiveClasses => _classes.isNotEmpty;

  String createClass({
    required CourseType courseType,
    required String className,
    required DateTime classDate,
    required String trainingCenter,
    required String location,
    required String primaryInstructor,
    required String additionalInstructor,
    required String notes,
    required Set<RequiredComponent> skillsSessionRequired,
  }) {
    final id = _ids.newId(prefix: 'class');
    final c = CourseClass(
      id: id,
      className: className,
      courseType: courseType,
      classDate: classDate,
      trainingCenter: trainingCenter,
      location: location,
      primaryInstructor: primaryInstructor,
      additionalInstructor: additionalInstructor,
      notes: notes,
      skillsSessionRequired: skillsSessionRequired,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _classes[id] = c;
    _studentIdsByClassId.putIfAbsent(id, () => <String>[]);
    _currentClass = c;
    _commit();
    return id;
  }

  bool hasCurrentClass() => _currentClass != null;

  bool currentClassHasAnyWork() {
    final c = _currentClass;
    if (c == null) return false;
    final students = studentsForCurrentClass();
    return students.isNotEmpty;
  }

  bool currentClassHasStudentsOrEvaluations() {
    final c = _currentClass;
    if (c == null) return false;
    final students = studentsForCurrentClass();
    if (students.isEmpty) return false;
    for (final s in students) {
      final anyAdult = s.adultChecklist.ratings.values.any((r) => r != ChecklistRating.notEvaluated);
      final anyInfant = s.infantChecklist.ratings.values.any((r) => r != ChecklistRating.notEvaluated);
      final anyCcf = s.ccf.decision != ChecklistDecision.notDecided ||
          s.ccf.compressionFractionPercent != null ||
          s.ccf.compressionRate != null ||
          s.ccf.compressionQuality.trim().isNotEmpty ||
          s.ccf.ventilationQuality.trim().isNotEmpty ||
          s.ccf.instructorComments.trim().isNotEmpty;
      final anyTest = s.testScore.scorePercent != null ||
          s.testScore.decision != ChecklistDecision.notDecided ||
          s.testScore.instructorNotes.trim().isNotEmpty;
      if (anyAdult || anyInfant || anyCcf || anyTest) return true;
    }
    return true;
  }

  bool selectActiveClass(String classId) {
    final c = _classes[classId];
    if (c == null) return false;
    _currentClass = c;
    _commit();
    return true;
  }

  void clearCurrentClassSelection() {
    _currentClass = null;
    _commit();
  }

  void discardCurrentClassAndData() {
    final c = _currentClass;
    if (c == null) return;
    _removeClassData(classId: c.id);
    _currentClass = null;
    _commit();
  }

  void _removeClassData({required String classId}) {
    final studentIds = _studentIdsByClassId.remove(classId) ?? const <String>[];
    for (final id in studentIds) {
      _studentsById.remove(id);
    }
    _classes.remove(classId);
  }

  CourseClass? getClass(String classId) => _classes[classId];

  Student? getStudent(String studentId) => _studentsById[studentId];

  String upsertStudent({
    required String? existingStudentId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String studentId,
    required String notes,
  }) {
    final current = _currentClass;
    if (current == null) throw StateError('No current class');

    final now = DateTime.now();
    final id = existingStudentId ?? _ids.newId(prefix: 'student');
    final prev = _studentsById[id];
    final next = (prev ?? Student.empty(id: id, createdAt: now)).copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      studentId: studentId,
      notes: notes,
      updatedAt: now,
    );
    _studentsById[id] = next;

    final list = _studentIdsByClassId.putIfAbsent(current.id, () => <String>[]);
    if (!list.contains(id)) list.add(id);

    _commit();
    return id;
  }

  void removeStudent(String studentId) {
    final current = _currentClass;
    if (current == null) return;
    _studentsById.remove(studentId);
    _studentIdsByClassId[current.id]?.remove(studentId);
    _commit();
  }

  void updateAdultChecklist({
    required String studentId,
    required Map<String, ChecklistRating> ratings,
    required bool reviewed,
    required ChecklistDecision decision,
    required String instructorNotes,
  }) {
    final s = _studentsById[studentId];
    if (s == null) return;
    _studentsById[studentId] = s.copyWith(
      adultChecklist: s.adultChecklist.copyWith(
        ratings: Map.unmodifiable(ratings),
        reviewed: reviewed,
        decision: decision,
        instructorNotes: instructorNotes,
        updatedAt: DateTime.now(),
      ),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void updateInfantChecklist({
    required String studentId,
    required Map<String, ChecklistRating> ratings,
    required bool reviewed,
    required ChecklistDecision decision,
    required String instructorNotes,
  }) {
    final s = _studentsById[studentId];
    if (s == null) return;
    _studentsById[studentId] = s.copyWith(
      infantChecklist: s.infantChecklist.copyWith(
        ratings: Map.unmodifiable(ratings),
        reviewed: reviewed,
        decision: decision,
        instructorNotes: instructorNotes,
        updatedAt: DateTime.now(),
      ),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void updateCcfEvaluation({
    required String studentId,
    required CcfEvaluation evaluation,
  }) {
    final s = _studentsById[studentId];
    if (s == null) return;
    _studentsById[studentId] = s.copyWith(
      ccf: evaluation.copyWith(updatedAt: DateTime.now()),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void updateTestScore({
    required String studentId,
    required TestScore score,
  }) {
    final s = _studentsById[studentId];
    if (s == null) return;
    _studentsById[studentId] = s.copyWith(
      testScore: score.copyWith(updatedAt: DateTime.now()),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  CompletionStatus completionForStudent(Student s) {
    final c = _currentClass;
    if (c == null) return CompletionStatus.notStarted;
    return CompletionEvaluator.evaluateStudent(s: s, course: c);
  }

  CourseSummary? currentClassSummary() {
    final c = _currentClass;
    if (c == null) return null;
    final students = studentsForCurrentClass();
    return CompletionEvaluator.evaluateClass(course: c, students: students);
  }

  void archiveCurrentClass() {
    final c = _currentClass;
    if (c == null) return;
    final students = studentsForCurrentClass();
    final summary = CompletionEvaluator.evaluateClass(course: c, students: students);

    CompletionStatus checklistStatus(ChecklistAttempt a) {
      if (!a.reviewed || a.decision == ChecklistDecision.notDecided) {
        final anyTouched = a.ratings.values.any((r) => r != ChecklistRating.notEvaluated);
        return anyTouched ? CompletionStatus.inProgress : CompletionStatus.notStarted;
      }
      return a.decision == ChecklistDecision.pass ? CompletionStatus.complete : CompletionStatus.needsReview;
    }

    CompletionStatus decisionStatus(ChecklistDecision d) => switch (d) {
          ChecklistDecision.notDecided => CompletionStatus.notStarted,
          ChecklistDecision.pass => CompletionStatus.complete,
          ChecklistDecision.needsReview => CompletionStatus.needsReview,
        };

    final rosterSnapshot = students
        .map((s) => ArchivedStudentSnapshot(
              studentId: s.id,
              fullName: s.fullName.isEmpty ? 'Unnamed student' : s.fullName,
              adultChecklistStatus: checklistStatus(s.adultChecklist),
              infantChecklistStatus: checklistStatus(s.infantChecklist),
              ccfStatus: decisionStatus(s.ccf.decision),
              writtenTestStatus: s.testScore.scorePercent == null
                  ? CompletionStatus.notStarted
                  : (s.testScore.decision == ChecklistDecision.notDecided
                      ? CompletionStatus.inProgress
                      : (s.testScore.isPass ? CompletionStatus.complete : CompletionStatus.needsReview)),
              overallStatus: CompletionEvaluator.evaluateStudent(s: s, course: c),
            ))
        .toList(growable: false);

    _archive.insert(
      0,
      ArchivedClass(
        archivedId: _ids.newId(prefix: 'arch'),
        sourceClassId: c.id,
        classSnapshot: c,
        summarySnapshot: summary,
        rosterSnapshot: rosterSnapshot,
        archivedAt: DateTime.now(),
      ),
    );

    _removeClassData(classId: c.id);
    _currentClass = null;
    _commit();
  }

  String createWorkingCopyFromArchive({required String archivedId, required DateTime classDate}) {
    final archived = _archive.firstWhere(
      (a) => a.archivedId == archivedId,
      orElse: () => throw StateError('Archived class not found'),
    );

    final c = archived.classSnapshot;
    return createClass(
      courseType: c.courseType,
      className: c.className,
      classDate: classDate,
      trainingCenter: c.trainingCenter,
      location: c.location,
      primaryInstructor: c.primaryInstructor,
      additionalInstructor: c.additionalInstructor,
      notes: '',
      skillsSessionRequired: c.skillsSessionRequired,
    );
  }

  void _commit() {
    notifyListeners();
    _persistSnapshot();
  }

  void _persistSnapshot() {
    final service = _preferencesService;
    if (service == null) return;

    final payload = jsonEncode(_snapshotToJson());
    _saveQueue = _saveQueue.then((_) async {
      final saved = await service.setWorkflowSnapshotJson(payload);
      if (!saved) {
        debugPrint('CPRFlow workflow snapshot could not be saved.');
      }
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('CPRFlow workflow snapshot save failed: $error');
    });
  }

  Map<String, Object?> _snapshotToJson() => {
        'version': 1,
        'currentClassId': _currentClass?.id,
        'classes': _classes.values.map(_courseToJson).toList(growable: false),
        'students': _studentsById.values.map(_studentToJson).toList(growable: false),
        'studentIdsByClassId': _studentIdsByClassId.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
        'archive': _archive.map(_archivedClassToJson).toList(growable: false),
      };

  void _restoreSnapshot(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['version'] != 1) return;

      final restoredClasses = <String, CourseClass>{};
      for (final item in _mapList(decoded['classes'])) {
        final course = _courseFromJson(item);
        restoredClasses[course.id] = course;
      }

      final restoredStudents = <String, Student>{};
      for (final item in _mapList(decoded['students'])) {
        final student = _studentFromJson(item);
        restoredStudents[student.id] = student;
      }

      final restoredRelations = <String, List<String>>{};
      final relations = decoded['studentIdsByClassId'];
      if (relations is Map) {
        for (final entry in relations.entries) {
          final classId = entry.key.toString();
          if (!restoredClasses.containsKey(classId)) continue;
          final ids = (entry.value is List ? entry.value as List : const <Object?>[])
              .map((e) => e.toString())
              .where(restoredStudents.containsKey)
              .toList(growable: true);
          restoredRelations[classId] = ids;
        }
      }
      for (final classId in restoredClasses.keys) {
        restoredRelations.putIfAbsent(classId, () => <String>[]);
      }

      final restoredArchive = <ArchivedClass>[];
      for (final item in _mapList(decoded['archive'])) {
        restoredArchive.add(_archivedClassFromJson(item));
      }

      _classes
        ..clear()
        ..addAll(restoredClasses);
      _studentsById
        ..clear()
        ..addAll(restoredStudents);
      _studentIdsByClassId
        ..clear()
        ..addAll(restoredRelations);
      _archive
        ..clear()
        ..addAll(restoredArchive);

      final currentId = decoded['currentClassId']?.toString();
      _currentClass = currentId == null ? null : _classes[currentId];
    } catch (error, stackTrace) {
      debugPrint('CPRFlow workflow snapshot restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _classes.clear();
      _studentsById.clear();
      _studentIdsByClassId.clear();
      _archive.clear();
      _currentClass = null;
    }
  }

  static List<Map<String, dynamic>> _mapList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  static T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    final name = raw?.toString();
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static DateTime _date(Object? raw) => DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();

  static Map<String, Object?> _courseToJson(CourseClass c) => {
        'id': c.id,
        'className': c.className,
        'courseType': c.courseType.name,
        'classDate': c.classDate.toIso8601String(),
        'trainingCenter': c.trainingCenter,
        'location': c.location,
        'primaryInstructor': c.primaryInstructor,
        'additionalInstructor': c.additionalInstructor,
        'notes': c.notes,
        'skillsSessionRequired': c.skillsSessionRequired.map((e) => e.name).toList(growable: false),
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
      };

  static CourseClass _courseFromJson(Map<String, dynamic> json) => CourseClass(
        id: json['id']?.toString() ?? '',
        className: json['className']?.toString() ?? '',
        courseType: _enumByName(CourseType.values, json['courseType'], CourseType.blsProvider),
        classDate: _date(json['classDate']),
        trainingCenter: json['trainingCenter']?.toString() ?? '',
        location: json['location']?.toString() ?? '',
        primaryInstructor: json['primaryInstructor']?.toString() ?? '',
        additionalInstructor: json['additionalInstructor']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        skillsSessionRequired: (json['skillsSessionRequired'] is List ? json['skillsSessionRequired'] as List : const [])
            .map((e) => _enumByName(RequiredComponent.values, e, RequiredComponent.adultChecklist))
            .toSet(),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  static Map<String, Object?> _checklistToJson(ChecklistAttempt a) => {
        'ratings': a.ratings.map((key, value) => MapEntry(key, value.name)),
        'reviewed': a.reviewed,
        'decision': a.decision.name,
        'instructorNotes': a.instructorNotes,
        'createdAt': a.createdAt.toIso8601String(),
        'updatedAt': a.updatedAt.toIso8601String(),
      };

  static ChecklistAttempt _checklistFromJson(Map<String, dynamic> json) {
    final ratings = <String, ChecklistRating>{};
    final rawRatings = json['ratings'];
    if (rawRatings is Map) {
      for (final entry in rawRatings.entries) {
        ratings[entry.key.toString()] = _enumByName(
          ChecklistRating.values,
          entry.value,
          ChecklistRating.notEvaluated,
        );
      }
    }
    return ChecklistAttempt(
      ratings: Map.unmodifiable(ratings),
      reviewed: json['reviewed'] == true,
      decision: _enumByName(ChecklistDecision.values, json['decision'], ChecklistDecision.notDecided),
      instructorNotes: json['instructorNotes']?.toString() ?? '',
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  static Map<String, Object?> _ccfToJson(CcfEvaluation e) => {
        'compressionFractionPercent': e.compressionFractionPercent,
        'compressionRate': e.compressionRate,
        'compressionQuality': e.compressionQuality,
        'ventilationQuality': e.ventilationQuality,
        'pausesMinimized': e.pausesMinimized,
        'instructorComments': e.instructorComments,
        'decision': e.decision.name,
        'createdAt': e.createdAt.toIso8601String(),
        'updatedAt': e.updatedAt.toIso8601String(),
      };

  static CcfEvaluation _ccfFromJson(Map<String, dynamic> json) => CcfEvaluation(
        compressionFractionPercent: (json['compressionFractionPercent'] as num?)?.toInt(),
        compressionRate: (json['compressionRate'] as num?)?.toInt(),
        compressionQuality: json['compressionQuality']?.toString() ?? '',
        ventilationQuality: json['ventilationQuality']?.toString() ?? '',
        pausesMinimized: json['pausesMinimized'] == true,
        instructorComments: json['instructorComments']?.toString() ?? '',
        decision: _enumByName(ChecklistDecision.values, json['decision'], ChecklistDecision.notDecided),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  static Map<String, Object?> _testScoreToJson(TestScore s) => {
        'scorePercent': s.scorePercent,
        'passingThresholdPercent': s.passingThresholdPercent,
        'decision': s.decision.name,
        'instructorNotes': s.instructorNotes,
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt.toIso8601String(),
      };

  static TestScore _testScoreFromJson(Map<String, dynamic> json) => TestScore(
        scorePercent: (json['scorePercent'] as num?)?.toInt(),
        passingThresholdPercent: (json['passingThresholdPercent'] as num?)?.toInt() ?? 84,
        decision: _enumByName(ChecklistDecision.values, json['decision'], ChecklistDecision.notDecided),
        instructorNotes: json['instructorNotes']?.toString() ?? '',
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  static Map<String, Object?> _studentToJson(Student s) => {
        'id': s.id,
        'firstName': s.firstName,
        'lastName': s.lastName,
        'email': s.email,
        'phone': s.phone,
        'studentId': s.studentId,
        'notes': s.notes,
        'adultChecklist': _checklistToJson(s.adultChecklist),
        'infantChecklist': _checklistToJson(s.infantChecklist),
        'ccf': _ccfToJson(s.ccf),
        'testScore': _testScoreToJson(s.testScore),
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt.toIso8601String(),
      };

  static Student _studentFromJson(Map<String, dynamic> json) {
    final now = _date(json['createdAt']);
    final adult = json['adultChecklist'] is Map
        ? _checklistFromJson(Map<String, dynamic>.from(json['adultChecklist'] as Map))
        : ChecklistAttempt.empty(now: now);
    final infant = json['infantChecklist'] is Map
        ? _checklistFromJson(Map<String, dynamic>.from(json['infantChecklist'] as Map))
        : ChecklistAttempt.empty(now: now);
    final ccf = json['ccf'] is Map
        ? _ccfFromJson(Map<String, dynamic>.from(json['ccf'] as Map))
        : CcfEvaluation.empty(now: now);
    final test = json['testScore'] is Map
        ? _testScoreFromJson(Map<String, dynamic>.from(json['testScore'] as Map))
        : TestScore.empty(now: now);

    return Student(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      adultChecklist: adult,
      infantChecklist: infant,
      ccf: ccf,
      testScore: test,
      createdAt: now,
      updatedAt: _date(json['updatedAt']),
    );
  }

  static Map<String, Object?> _summaryToJson(CourseSummary s) => {
        'totalStudents': s.totalStudents,
        'completeCount': s.completeCount,
        'needsReviewCount': s.needsReviewCount,
        'inProgressCount': s.inProgressCount,
        'notStartedCount': s.notStartedCount,
        'overallStatus': s.overallStatus.name,
      };

  static CourseSummary _summaryFromJson(Map<String, dynamic> json) => CourseSummary(
        totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
        completeCount: (json['completeCount'] as num?)?.toInt() ?? 0,
        needsReviewCount: (json['needsReviewCount'] as num?)?.toInt() ?? 0,
        inProgressCount: (json['inProgressCount'] as num?)?.toInt() ?? 0,
        notStartedCount: (json['notStartedCount'] as num?)?.toInt() ?? 0,
        overallStatus: _enumByName(CompletionStatus.values, json['overallStatus'], CompletionStatus.notStarted),
      );

  static Map<String, Object?> _archivedStudentToJson(ArchivedStudentSnapshot s) => {
        'studentId': s.studentId,
        'fullName': s.fullName,
        'adultChecklistStatus': s.adultChecklistStatus.name,
        'infantChecklistStatus': s.infantChecklistStatus.name,
        'ccfStatus': s.ccfStatus.name,
        'writtenTestStatus': s.writtenTestStatus.name,
        'overallStatus': s.overallStatus.name,
      };

  static ArchivedStudentSnapshot _archivedStudentFromJson(Map<String, dynamic> json) => ArchivedStudentSnapshot(
        studentId: json['studentId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        adultChecklistStatus: _enumByName(
          CompletionStatus.values,
          json['adultChecklistStatus'],
          CompletionStatus.notStarted,
        ),
        infantChecklistStatus: _enumByName(
          CompletionStatus.values,
          json['infantChecklistStatus'],
          CompletionStatus.notStarted,
        ),
        ccfStatus: _enumByName(CompletionStatus.values, json['ccfStatus'], CompletionStatus.notStarted),
        writtenTestStatus: _enumByName(
          CompletionStatus.values,
          json['writtenTestStatus'],
          CompletionStatus.notStarted,
        ),
        overallStatus: _enumByName(CompletionStatus.values, json['overallStatus'], CompletionStatus.notStarted),
      );

  static Map<String, Object?> _archivedClassToJson(ArchivedClass a) => {
        'archivedId': a.archivedId,
        'sourceClassId': a.sourceClassId,
        'classSnapshot': _courseToJson(a.classSnapshot),
        'summarySnapshot': _summaryToJson(a.summarySnapshot),
        'rosterSnapshot': a.rosterSnapshot.map(_archivedStudentToJson).toList(growable: false),
        'archivedAt': a.archivedAt.toIso8601String(),
      };

  static ArchivedClass _archivedClassFromJson(Map<String, dynamic> json) => ArchivedClass(
        archivedId: json['archivedId']?.toString() ?? '',
        sourceClassId: json['sourceClassId']?.toString() ?? '',
        classSnapshot: _courseFromJson(
          json['classSnapshot'] is Map ? Map<String, dynamic>.from(json['classSnapshot'] as Map) : <String, dynamic>{},
        ),
        summarySnapshot: _summaryFromJson(
          json['summarySnapshot'] is Map ? Map<String, dynamic>.from(json['summarySnapshot'] as Map) : <String, dynamic>{},
        ),
        rosterSnapshot: _mapList(json['rosterSnapshot']).map(_archivedStudentFromJson).toList(growable: false),
        archivedAt: _date(json['archivedAt']),
      );
}
