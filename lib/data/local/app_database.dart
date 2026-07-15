import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:cpr_instructor_doc/data/local/app_database_executor.dart';

// Use an absolute package: URI for the generated part so analyzers consistently
// resolve it the same way across IDEs/build systems.
part 'package:cpr_instructor_doc/data/local/app_database.g.dart';

enum CourseType { blsProvider }

enum ChecklistType { adult, infantChild }
enum ChecklistAttemptStatus { notStarted, inProgress, passed, failed }
enum ChecklistItemResultValue { notEvaluated, passed, needsRemediation }
enum CcfResultValue { incomplete, passed, failed }

class CourseTypeConverter extends TypeConverter<CourseType, String> {
  const CourseTypeConverter();

  @override
  CourseType fromSql(String fromDb) {
    switch (fromDb) {
      case 'bls_provider':
        return CourseType.blsProvider;
      default:
        return CourseType.blsProvider;
    }
  }

  @override
  String toSql(CourseType value) {
    switch (value) {
      case CourseType.blsProvider:
        return 'bls_provider';
    }
  }
}

class ChecklistTypeConverter extends TypeConverter<ChecklistType, String> {
  const ChecklistTypeConverter();

  @override
  ChecklistType fromSql(String fromDb) {
    switch (fromDb) {
      case 'adult':
        return ChecklistType.adult;
      case 'infant_child':
        return ChecklistType.infantChild;
      default:
        return ChecklistType.adult;
    }
  }

  @override
  String toSql(ChecklistType value) {
    switch (value) {
      case ChecklistType.adult:
        return 'adult';
      case ChecklistType.infantChild:
        return 'infant_child';
    }
  }
}

class ChecklistAttemptStatusConverter extends TypeConverter<ChecklistAttemptStatus, String> {
  const ChecklistAttemptStatusConverter();

  @override
  ChecklistAttemptStatus fromSql(String fromDb) {
    switch (fromDb) {
      case 'not_started':
        return ChecklistAttemptStatus.notStarted;
      case 'in_progress':
        return ChecklistAttemptStatus.inProgress;
      case 'passed':
        return ChecklistAttemptStatus.passed;
      case 'failed':
        return ChecklistAttemptStatus.failed;
      default:
        return ChecklistAttemptStatus.notStarted;
    }
  }

  @override
  String toSql(ChecklistAttemptStatus value) {
    switch (value) {
      case ChecklistAttemptStatus.notStarted:
        return 'not_started';
      case ChecklistAttemptStatus.inProgress:
        return 'in_progress';
      case ChecklistAttemptStatus.passed:
        return 'passed';
      case ChecklistAttemptStatus.failed:
        return 'failed';
    }
  }
}

class ChecklistItemResultValueConverter extends TypeConverter<ChecklistItemResultValue, String> {
  const ChecklistItemResultValueConverter();

  @override
  ChecklistItemResultValue fromSql(String fromDb) {
    switch (fromDb) {
      case 'not_evaluated':
        return ChecklistItemResultValue.notEvaluated;
      case 'passed':
        return ChecklistItemResultValue.passed;
      case 'needs_remediation':
        return ChecklistItemResultValue.needsRemediation;
      default:
        return ChecklistItemResultValue.notEvaluated;
    }
  }

  @override
  String toSql(ChecklistItemResultValue value) {
    switch (value) {
      case ChecklistItemResultValue.notEvaluated:
        return 'not_evaluated';
      case ChecklistItemResultValue.passed:
        return 'passed';
      case ChecklistItemResultValue.needsRemediation:
        return 'needs_remediation';
    }
  }
}

class CcfResultValueConverter extends TypeConverter<CcfResultValue, String> {
  const CcfResultValueConverter();

  @override
  CcfResultValue fromSql(String fromDb) {
    switch (fromDb) {
      case 'incomplete':
        return CcfResultValue.incomplete;
      case 'passed':
        return CcfResultValue.passed;
      case 'failed':
        return CcfResultValue.failed;
      default:
        return CcfResultValue.incomplete;
    }
  }

  @override
  String toSql(CcfResultValue value) {
    switch (value) {
      case CcfResultValue.incomplete:
        return 'incomplete';
      case CcfResultValue.passed:
        return 'passed';
      case CcfResultValue.failed:
        return 'failed';
    }
  }
}

class ClassRecords extends Table {
  TextColumn get id => text()();
  TextColumn get className => text()();
  TextColumn get courseType => text().map(const CourseTypeConverter())();

  DateTimeColumn get classDate => dateTime().nullable()();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();

  TextColumn get location => text().nullable()();
  TextColumn get leadInstructor => text().nullable()();
  TextColumn get additionalInstructor => text().nullable()();
  TextColumn get trainingCenter => text().nullable()();
  TextColumn get trainingSite => text().nullable()();

  BoolColumn get writtenTestRequired => boolean().withDefault(const Constant(false))();
  IntColumn get passingScore => integer().nullable()();
  BoolColumn get ccfRequired => boolean().withDefault(const Constant(false))();
  DateTimeColumn get defaultSkillsCheckOffDate => dateTime().nullable()();
  DateTimeColumn get defaultIssueDate => dateTime().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class StudentRecords extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(ClassRecords, #id, onDelete: KeyAction.restrict)();

  TextColumn get displayName => text()();
  TextColumn get originalFullName => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get nameNeedsReview => boolean().withDefault(const Constant(false))();

  // Phase 2 fields
  IntColumn get writtenTestScore => integer().nullable()();
  BoolColumn get writtenTestingFinalized => boolean().withDefault(const Constant(false))();
  DateTimeColumn get skillsCheckOffDate => dateTime().nullable()();
  DateTimeColumn get issueDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChecklistAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(ClassRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get studentId => text().references(StudentRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get checklistType => text().map(const ChecklistTypeConverter())();
  TextColumn get status => text().map(const ChecklistAttemptStatusConverter())();
  BoolColumn get finalized => boolean().withDefault(const Constant(false))();
  DateTimeColumn get finalizedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChecklistItemResults extends Table {
  TextColumn get id => text()();
  TextColumn get attemptId => text().references(ChecklistAttempts, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemId => text()();
  TextColumn get result => text().map(const ChecklistItemResultValueConverter())();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {attemptId, itemId},
  ];

  @override
  Set<Column> get primaryKey => {id};
}

class CcfSessions extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().nullable().references(ClassRecords, #id, onDelete: KeyAction.setNull)();
  TextColumn get studentId => text().nullable().references(StudentRecords, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get totalDurationMilliseconds => integer()();
  IntColumn get compressionDurationMilliseconds => integer()();
  IntColumn get pauseDurationMilliseconds => integer()();
  RealColumn get ccfPercentage => real()();
  RealColumn get passingThreshold => real()();
  BoolColumn get finalized => boolean().withDefault(const Constant(false))();
  TextColumn get result => text().map(const CcfResultValueConverter())();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ClassRecords, StudentRecords, ChecklistAttempts, ChecklistItemResults, CcfSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  static Future<AppDatabase> open() async {
    try {
      final executor = await openAppDatabaseExecutor();
      return AppDatabase(executor);
    } catch (e, st) {
      debugPrint('Failed to open database: $e\n$st');
      rethrow;
    }
  }

  /// Test helper: lightweight DB for unit/widget tests.
  factory AppDatabase.inMemory() => AppDatabase(openAppDatabaseTestExecutor());

  /// Forces the underlying database connection to open and validates that the
  /// schema can be accessed.
  ///
  /// This is intentionally "harmless": it does not migrate, delete, or
  /// recreate the database.
  Future<void> verifyConnection() async {
    try {
      // Forces a real connection open.
      await customSelect('SELECT 1').getSingle();

      // Forces Drift to access the schema / a real table.
      await (select(classRecords)..limit(1)).get();
    } catch (e, st) {
      debugPrint('Database verifyConnection failed: $e\n$st');
      rethrow;
    }
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // One active attempt per (student, checklistType).
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS checklist_attempts_active_unique '
        'ON checklist_attempts(student_id, checklist_type) '
        'WHERE finalized = 0;',
      );

      // One item result per (attempt, itemId).
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS checklist_item_results_unique '
        'ON checklist_item_results(attempt_id, item_id);',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        // IMPORTANT: Drift already runs schema migrations inside a transaction.
        // Do not nest another manual transaction here.
        await m.addColumn(studentRecords, studentRecords.writtenTestScore);
        await m.addColumn(studentRecords, studentRecords.writtenTestingFinalized);
        await m.addColumn(studentRecords, studentRecords.skillsCheckOffDate);
        await m.addColumn(studentRecords, studentRecords.issueDate);

        await m.createTable(checklistAttempts);
        await m.createTable(checklistItemResults);
        await m.createTable(ccfSessions);

        // One unfinalized attempt per (student, checklistType).
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS checklist_attempts_active_unique '
          'ON checklist_attempts(student_id, checklist_type) '
          'WHERE finalized = 0;',
        );

        // One item result per (attempt, itemId).
        // (Also enforced by a table-level UNIQUE constraint for non-partial cases.)
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS checklist_item_results_unique '
          'ON checklist_item_results(attempt_id, item_id);',
        );
      }
    },
  );
}
