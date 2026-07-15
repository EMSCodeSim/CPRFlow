import 'dart:io';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _createV1DbFile() async {
  final dir = await Directory.systemTemp.createTemp('ccf_timer_test_');
  final file = File('${dir.path}/v1.sqlite');
  final db = NativeDatabase(file);

  // Minimal v1 schema: class_records + student_records.
  final executor = db;
  await executor.runCustom('PRAGMA foreign_keys = ON;');
  await executor.runCustom('PRAGMA user_version = 1;');

  await executor.runCustom('''
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

  await executor.runCustom('''
CREATE TABLE student_records (
  id TEXT NOT NULL PRIMARY KEY,
  class_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  original_full_name TEXT NULL,
  first_name TEXT NULL,
  last_name TEXT NULL,
  email TEXT NULL,
  phone TEXT NULL,
  name_needs_review INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

  final now = DateTime(2025, 1, 1).millisecondsSinceEpoch;
  await executor.runCustom(
    "INSERT INTO class_records(id, class_name, course_type, is_active, created_at, updated_at) VALUES('c1','Test Class','bls_provider',1,$now,$now);",
  );
  await executor.runCustom(
    "INSERT INTO student_records(id, class_id, display_name, name_needs_review, created_at, updated_at) VALUES('s1','c1','Student One',0,$now,$now);",
  );

  await db.close();
  return file;
}

void main() {
  test('Real v1 database migrates to v2 without data loss', () async {
    final file = await _createV1DbFile();
    final appDb = AppDatabase(NativeDatabase(file));

    // Trigger open + migration.
    await appDb.verifyConnection();

    final active = await (appDb.select(appDb.classRecords)..where((t) => t.isActive.equals(true))).getSingleOrNull();
    expect(active, isNotNull);
    expect(active!.id, 'c1');

    final student = await (appDb.select(appDb.studentRecords)..where((t) => t.id.equals('s1'))).getSingleOrNull();
    expect(student, isNotNull);
    expect(student!.displayName, 'Student One');

    // New columns exist and use safe defaults.
    expect(student.writtenTestScore, isNull);
    expect(student.writtenTestingFinalized, isFalse);
    expect(student.skillsCheckOffDate, isNull);
    expect(student.issueDate, isNull);

    // New tables exist.
    final tables = await appDb.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
    final tableNames = tables.map((r) => r.read<String>('name')).toSet();
    expect(tableNames, containsAll(['checklist_attempts', 'checklist_item_results', 'ccf_sessions']));

    await appDb.close();
  });
}
