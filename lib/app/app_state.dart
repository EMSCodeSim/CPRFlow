import 'package:flutter/foundation.dart';

import 'package:ccf_timer_low_risk_test/app/completion_evaluator.dart';
import 'package:ccf_timer_low_risk_test/app/models.dart';
import 'package:ccf_timer_low_risk_test/utils/id_generator.dart';

/// Single source of truth for the restoration-stage workflow.
///
/// IMPORTANT: This is intentionally in-memory only. All workflow data resets
/// when Dreamflow Preview restarts.
class AppState extends ChangeNotifier {
  AppState({IdGenerator? idGenerator}) : _ids = idGenerator ?? IdGenerator();

  final IdGenerator _ids;

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
    notifyListeners();
    return id;
  }

  bool hasCurrentClass() => _currentClass != null;

  bool currentClassHasAnyWork() {
    final c = _currentClass;
    if (c == null) return false;
    final students = studentsForCurrentClass();
    if (students.isNotEmpty) return true;
    // If no students, treat as no work.
    return false;
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
      final anyTest = s.testScore.scorePercent != null || s.testScore.decision != ChecklistDecision.notDecided || s.testScore.instructorNotes.trim().isNotEmpty;
      if (anyAdult || anyInfant || anyCcf || anyTest) return true;
    }
    return true;
  }

  /// Select an existing in-memory class as the current active class.
  ///
  /// This does not create a copy and does not change archive state.
  bool selectActiveClass(String classId) {
    final c = _classes[classId];
    if (c == null) return false;
    _currentClass = c;
    notifyListeners();
    return true;
  }

  /// Clears the current class pointer only (does not delete any in-memory objects).
  void clearCurrentClassSelection() {
    _currentClass = null;
    notifyListeners();
  }

  /// Permanently discards the current active class and all associated in-memory data.
  ///
  /// This is a restoration-stage destructive action.
  void discardCurrentClassAndData() {
    final c = _currentClass;
    if (c == null) return;
    _removeClassData(classId: c.id);
    _currentClass = null;
    notifyListeners();
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

    notifyListeners();
    return id;
  }

  void removeStudent(String studentId) {
    final current = _currentClass;
    if (current == null) return;
    _studentsById.remove(studentId);
    _studentIdsByClassId[current.id]?.remove(studentId);
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  void updateCcfEvaluation({
    required String studentId,
    required CcfEvaluation evaluation,
  }) {
    final s = _studentsById[studentId];
    if (s == null) return;
    _studentsById[studentId] = s.copyWith(ccf: evaluation.copyWith(updatedAt: DateTime.now()), updatedAt: DateTime.now());
    notifyListeners();
  }

  void updateTestScore({
    required String studentId,
    required TestScore score,
  }) {
    final s = _studentsById[studentId];
    if (s == null) return;
    _studentsById[studentId] = s.copyWith(testScore: score.copyWith(updatedAt: DateTime.now()), updatedAt: DateTime.now());
    notifyListeners();
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

  /// Archives the current class by storing a frozen snapshot and removing the
  /// active editable in-memory data for that class.
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

    _archive.insert(0, ArchivedClass(
      archivedId: _ids.newId(prefix: 'arch'),
      sourceClassId: c.id,
      classSnapshot: c,
      summarySnapshot: summary,
      rosterSnapshot: rosterSnapshot,
      archivedAt: DateTime.now(),
    ));

    // Remove editable data so no inaccessible active classes remain.
    _removeClassData(classId: c.id);
    _currentClass = null;
    notifyListeners();
  }

  /// Creates a new class using archived metadata only.
  ///
  /// Does NOT copy students, checklists, notes, scores, or any completion data.
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
}
