import 'dart:io';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _createV2DbFile() async {
  final dir = await Directory.systemTemp.createTemp('ccf_timer_test_v2_');
  final file = File('${dir.path}/v2.sqlite');
  final db = NativeDatabase(file);
  await db.runCustom('PRAGMA foreign_keys = ON;');
  await db.runCustom('PRAGMA user_version = 2;');

  // v2 schema as it existed in Phase 2.
  await db.runCustom('''
CREATE TABLE class_records (
  id TEXT NOT NULL PRIMARY KEY,
  class_name TEXT NOT NULL,
  course_type TEXT NOT NULL,
  class_date INTEGER NULL,
  start_time INTEGER NULL,
  end_time INTEGER NULL,
  location TEXT NULL,
  lead_instructor TEXT NULL,
  additional_instructor TEXT NULL,
  training_center TEXT NULL,
  training_site TEXT NULL,
  written_test_required INTEGER NOT NULL DEFAULT 0,
  passing_score INTEGER NULL,
  ccf_required INTEGER NOT NULL DEFAULT 0,
  default_skills_check_off_date INTEGER NULL,
  default_issue_date INTEGER NULL,
  is_active INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

  await db.runCustom('''
CREATE TABLE student_records (
  id TEXT NOT NULL PRIMARY KEY,
  class_id TEXT NOT NULL REFERENCES class_records(id) ON DELETE RESTRICT,
  display_name TEXT NOT NULL,
  original_full_name TEXT NULL,
  first_name TEXT NULL,
  last_name TEXT NULL,
  email TEXT NULL,
  phone TEXT NULL,
  name_needs_review INTEGER NOT NULL DEFAULT 0,
  written_test_score INTEGER NULL,
  written_testing_finalized INTEGER NOT NULL DEFAULT 0,
  skills_check_off_date INTEGER NULL,
  issue_date INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

  await db.runCustom('''
CREATE TABLE checklist_attempts (
  id TEXT NOT NULL PRIMARY KEY,
  class_id TEXT NOT NULL REFERENCES class_records(id) ON DELETE RESTRICT,
  student_id TEXT NOT NULL REFERENCES student_records(id) ON DELETE RESTRICT,
  checklist_type TEXT NOT NULL,
  status TEXT NOT NULL,
  finalized INTEGER NOT NULL DEFAULT 0,
  finalized_at INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
  await db.runCustom('''
CREATE TABLE checklist_item_results (
  id TEXT NOT NULL PRIMARY KEY,
  attempt_id TEXT NOT NULL REFERENCES checklist_attempts(id) ON DELETE RESTRICT,
  item_id TEXT NOT NULL,
  result TEXT NOT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
  await db.runCustom('''
CREATE TABLE ccf_sessions (
  id TEXT NOT NULL PRIMARY KEY,
  class_id TEXT NULL REFERENCES class_records(id) ON DELETE SET NULL,
  student_id TEXT NULL REFERENCES student_records(id) ON DELETE SET NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NULL,
  total_duration_milliseconds INTEGER NOT NULL,
  compression_duration_milliseconds INTEGER NOT NULL,
  pause_duration_milliseconds INTEGER NOT NULL,
  ccf_percentage REAL NOT NULL,
  passing_threshold REAL NOT NULL,
  finalized INTEGER NOT NULL DEFAULT 0,
  result TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

  await db.runCustom('''
CREATE UNIQUE INDEX IF NOT EXISTS checklist_attempts_active_unique
ON checklist_attempts(student_id, checklist_type)
WHERE finalized = 0;
''');

  final now = DateTime(2025, 1, 2).millisecondsSinceEpoch;
  await db.runCustom("INSERT INTO class_records(id, class_name, course_type, is_active, created_at, updated_at) VALUES('c2','V2 Class','bls_provider',1,$now,$now);");
  await db.runCustom("INSERT INTO student_records(id, class_id, display_name, name_needs_review, created_at, updated_at) VALUES('s2','c2','Student Two',0,$now,$now);");

  await db.close();
  return file;
}

void main() {
  test('Real v2 database migrates to v3 with safe defaults and preserved records', () async {
    final file = await _createV2DbFile();
    final appDb = AppDatabase(NativeDatabase(file));

    await appDb.verifyConnection();

    final active = await (appDb.select(appDb.classRecords)..where((t) => t.isActive.equals(true))).getSingleOrNull();
    expect(active, isNotNull);
    expect(active!.id, 'c2');
    expect(active.lifecycleStatus, ClassLifecycleStatus.active);
    expect(active.finalizationStatus, ClassFinalizationStatus.notStarted);

    final student = await (appDb.select(appDb.studentRecords)..where((t) => t.id.equals('s2'))).getSingleOrNull();
    expect(student, isNotNull);
    expect(student!.manualResultOverride, ManualStudentResultOverride.none);

    final tables = await appDb.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('final_class_snapshots'));
    expect(names, contains('finalization_audit_entries'));

    await appDb.close();
  });
}
