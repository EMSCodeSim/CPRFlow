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

/// Phase 3: Strongly-typed lifecycle states for a class.
enum ClassLifecycleStatus { active, finalizationInProgress, completed, completedIncomplete }

/// Phase 3: Tracks wizard progress without changing the class lifecycle.
enum ClassFinalizationStatus { notStarted, inProgress }

/// Phase 3: Stored on students, used only during finalization.
enum ManualStudentResultOverride { none, pass, incomplete, fail }

/// Phase 5: Document categories (not file types).
enum DocumentType {
  writtenTest,
  classRoster,
  atlasRoster,
  attendance,
  studentSkillSheet,
  studentEvaluation,
  studentPhoto,
  miscellaneous,
}

class DocumentTypeConverter extends TypeConverter<DocumentType, String> {
  const DocumentTypeConverter();

  @override
  DocumentType fromSql(String fromDb) {
    switch (fromDb) {
      case 'written_test':
        return DocumentType.writtenTest;
      case 'class_roster':
        return DocumentType.classRoster;
      case 'atlas_roster':
        return DocumentType.atlasRoster;
      case 'attendance':
        return DocumentType.attendance;
      case 'student_skill_sheet':
        return DocumentType.studentSkillSheet;
      case 'student_evaluation':
        return DocumentType.studentEvaluation;
      case 'student_photo':
        return DocumentType.studentPhoto;
      case 'miscellaneous':
        return DocumentType.miscellaneous;
      default:
        return DocumentType.miscellaneous;
    }
  }

  @override
  String toSql(DocumentType value) {
    switch (value) {
      case DocumentType.writtenTest:
        return 'written_test';
      case DocumentType.classRoster:
        return 'class_roster';
      case DocumentType.atlasRoster:
        return 'atlas_roster';
      case DocumentType.attendance:
        return 'attendance';
      case DocumentType.studentSkillSheet:
        return 'student_skill_sheet';
      case DocumentType.studentEvaluation:
        return 'student_evaluation';
      case DocumentType.studentPhoto:
        return 'student_photo';
      case DocumentType.miscellaneous:
        return 'miscellaneous';
    }
  }
}

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

class ClassLifecycleStatusConverter extends TypeConverter<ClassLifecycleStatus, String> {
  const ClassLifecycleStatusConverter();

  @override
  ClassLifecycleStatus fromSql(String fromDb) {
    switch (fromDb) {
      case 'active':
        return ClassLifecycleStatus.active;
      case 'finalization_in_progress':
        return ClassLifecycleStatus.finalizationInProgress;
      case 'completed':
        return ClassLifecycleStatus.completed;
      case 'completed_incomplete':
        return ClassLifecycleStatus.completedIncomplete;
      default:
        return ClassLifecycleStatus.active;
    }
  }

  @override
  String toSql(ClassLifecycleStatus value) {
    switch (value) {
      case ClassLifecycleStatus.active:
        return 'active';
      case ClassLifecycleStatus.finalizationInProgress:
        return 'finalization_in_progress';
      case ClassLifecycleStatus.completed:
        return 'completed';
      case ClassLifecycleStatus.completedIncomplete:
        return 'completed_incomplete';
    }
  }
}

class ClassFinalizationStatusConverter extends TypeConverter<ClassFinalizationStatus, String> {
  const ClassFinalizationStatusConverter();

  @override
  ClassFinalizationStatus fromSql(String fromDb) {
    switch (fromDb) {
      case 'not_started':
        return ClassFinalizationStatus.notStarted;
      case 'in_progress':
        return ClassFinalizationStatus.inProgress;
      default:
        return ClassFinalizationStatus.notStarted;
    }
  }

  @override
  String toSql(ClassFinalizationStatus value) {
    switch (value) {
      case ClassFinalizationStatus.notStarted:
        return 'not_started';
      case ClassFinalizationStatus.inProgress:
        return 'in_progress';
    }
  }
}

class ManualStudentResultOverrideConverter extends TypeConverter<ManualStudentResultOverride, String> {
  const ManualStudentResultOverrideConverter();

  @override
  ManualStudentResultOverride fromSql(String fromDb) {
    switch (fromDb) {
      case 'none':
        return ManualStudentResultOverride.none;
      case 'pass':
        return ManualStudentResultOverride.pass;
      case 'incomplete':
        return ManualStudentResultOverride.incomplete;
      case 'fail':
        return ManualStudentResultOverride.fail;
      default:
        return ManualStudentResultOverride.none;
    }
  }

  @override
  String toSql(ManualStudentResultOverride value) {
    switch (value) {
      case ManualStudentResultOverride.none:
        return 'none';
      case ManualStudentResultOverride.pass:
        return 'pass';
      case ManualStudentResultOverride.incomplete:
        return 'incomplete';
      case ManualStudentResultOverride.fail:
        return 'fail';
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

  // Phase 3 lifecycle/finalization fields.
  TextColumn get lifecycleStatus => text().map(const ClassLifecycleStatusConverter()).withDefault(const Constant('active'))();
  TextColumn get finalizationStatus => text().map(const ClassFinalizationStatusConverter()).withDefault(const Constant('not_started'))();
  DateTimeColumn get finalizedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get finalizedPassedCount => integer().nullable()();
  IntColumn get finalizedIncompleteCount => integer().nullable()();
  IntColumn get finalizedFailedCount => integer().nullable()();
  TextColumn get activeSnapshotId => text().nullable()();
  IntColumn get snapshotSchemaVersion => integer().nullable()();
  IntColumn get completionRuleVersion => integer().withDefault(const Constant(1))();
  IntColumn get checklistDefinitionVersion => integer().withDefault(const Constant(1))();
  TextColumn get reopenedFromClassId => text().nullable()();
  IntColumn get workingCopyNumber => integer().withDefault(const Constant(0))();

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

  // Phase 3 fields (manual overrides used during finalization only).
  TextColumn get manualResultOverride => text().map(const ManualStudentResultOverrideConverter()).withDefault(const Constant('none'))();
  TextColumn get manualResultReason => text().nullable()();
  DateTimeColumn get manualResultChangedAt => dateTime().nullable()();
  TextColumn get manualResultInstructorInitials => text().nullable()();

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

class FinalClassSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(ClassRecords, #id, onDelete: KeyAction.restrict)();
  IntColumn get snapshotNumber => integer()();
  IntColumn get schemaVersion => integer()();
  IntColumn get completionRuleVersion => integer()();
  IntColumn get checklistDefinitionVersion => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get finalizedAt => dateTime()();
  TextColumn get classDataJson => text()();
  TextColumn get studentDataJson => text()();
  TextColumn get checklistDataJson => text()();
  TextColumn get ccfDataJson => text()();
  TextColumn get scoreDataJson => text()();
  TextColumn get completionResultsJson => text()();
  TextColumn get totalsJson => text()();
  TextColumn get checksum => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class FinalizationAuditEntries extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(ClassRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get snapshotId => text().nullable().references(FinalClassSnapshots, #id, onDelete: KeyAction.setNull)();
  TextColumn get action => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get instructorName => text().nullable()();
  TextColumn get instructorInitials => text().nullable()();
  TextColumn get previousValueJson => text().nullable()();
  TextColumn get newValueJson => text().nullable()();
  TextColumn get reason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Phase 5: Securely managed documents stored in app-private storage.
///
/// IMPORTANT: No absolute paths are stored in Drift. Files are resolved via
/// DocumentStorageService using (classId, storageFilename).
class ClassDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(ClassRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get studentId => text().nullable().references(StudentRecords, #id, onDelete: KeyAction.setNull)();

  TextColumn get documentType => text().map(const DocumentTypeConverter())();
  TextColumn get displayName => text()();
  TextColumn get originalFilename => text()();
  TextColumn get storageFilename => text()();
  TextColumn get mimeType => text()();
  IntColumn get fileSize => integer()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get checksum => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {classId, storageFilename},
  ];
}

@DriftDatabase(tables: [ClassRecords, StudentRecords, ChecklistAttempts, ChecklistItemResults, CcfSessions, FinalClassSnapshots, FinalizationAuditEntries, ClassDocuments])
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
  int get schemaVersion => 5;

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

      await customStatement('CREATE INDEX IF NOT EXISTS final_class_snapshots_class_id_idx ON final_class_snapshots(class_id);');
      await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS final_class_snapshots_class_number_unique ON final_class_snapshots(class_id, snapshot_number);');
      await customStatement('CREATE INDEX IF NOT EXISTS finalization_audit_entries_class_id_idx ON finalization_audit_entries(class_id, timestamp);');

      // Phase 5: document indices for search and health checks.
      await customStatement('CREATE INDEX IF NOT EXISTS class_documents_class_id_idx ON class_documents(class_id, updated_at);');
      await customStatement('CREATE INDEX IF NOT EXISTS class_documents_student_id_idx ON class_documents(student_id, updated_at);');
      await customStatement('CREATE INDEX IF NOT EXISTS class_documents_type_idx ON class_documents(class_id, document_type, updated_at);');
      await customStatement('CREATE INDEX IF NOT EXISTS class_documents_deleted_idx ON class_documents(class_id, deleted);');
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

      if (from <= 2 && to >= 3) {
        // Phase 3 fields on class records.
        await m.addColumn(classRecords, classRecords.lifecycleStatus);
        await m.addColumn(classRecords, classRecords.finalizationStatus);
        await m.addColumn(classRecords, classRecords.finalizedAt);
        await m.addColumn(classRecords, classRecords.completedAt);
        await m.addColumn(classRecords, classRecords.archivedAt);
        await m.addColumn(classRecords, classRecords.finalizedPassedCount);
        await m.addColumn(classRecords, classRecords.finalizedIncompleteCount);
        await m.addColumn(classRecords, classRecords.finalizedFailedCount);
        await m.addColumn(classRecords, classRecords.activeSnapshotId);
        await m.addColumn(classRecords, classRecords.snapshotSchemaVersion);
        await m.addColumn(classRecords, classRecords.completionRuleVersion);
        await m.addColumn(classRecords, classRecords.checklistDefinitionVersion);
        await m.addColumn(classRecords, classRecords.reopenedFromClassId);
        await m.addColumn(classRecords, classRecords.workingCopyNumber);

        // Phase 3 fields on student records.
        await m.addColumn(studentRecords, studentRecords.manualResultOverride);
        await m.addColumn(studentRecords, studentRecords.manualResultReason);
        await m.addColumn(studentRecords, studentRecords.manualResultChangedAt);
        await m.addColumn(studentRecords, studentRecords.manualResultInstructorInitials);

        // New Phase 3 tables.
        await m.createTable(finalClassSnapshots);
        await m.createTable(finalizationAuditEntries);

        // Helpful lookup indices.
        await customStatement('CREATE INDEX IF NOT EXISTS final_class_snapshots_class_id_idx ON final_class_snapshots(class_id);');
        await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS final_class_snapshots_class_number_unique ON final_class_snapshots(class_id, snapshot_number);');
        await customStatement('CREATE INDEX IF NOT EXISTS finalization_audit_entries_class_id_idx ON finalization_audit_entries(class_id, timestamp);');
      }

      if (from <= 4 && to >= 5) {
        await m.createTable(classDocuments);
        await customStatement('CREATE INDEX IF NOT EXISTS class_documents_class_id_idx ON class_documents(class_id, updated_at);');
        await customStatement('CREATE INDEX IF NOT EXISTS class_documents_student_id_idx ON class_documents(student_id, updated_at);');
        await customStatement('CREATE INDEX IF NOT EXISTS class_documents_type_idx ON class_documents(class_id, document_type, updated_at);');
        await customStatement('CREATE INDEX IF NOT EXISTS class_documents_deleted_idx ON class_documents(class_id, deleted);');
      }
    },
  );
}
