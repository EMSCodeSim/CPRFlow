import 'dart:io';
import 'dart:typed_data';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/document_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/score_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:cpr_instructor_doc/domain/documents/class_package_service.dart';
import 'package:cpr_instructor_doc/domain/documents/document_storage_service.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ClassPackageService export ZIP then import creates a new class and restores docs', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final temp = await Directory.systemTemp.createTemp('ccf_pkg_test_');
    addTearDown(() => temp.delete(recursive: true));

    final classRepo = ClassRepository(db);
    final studentRepo = StudentRepository(db);
    final checklistRepo = ChecklistRepository(db);
    final ccfRepo = CcfRepository(db);
    final scoreRepo = ScoreRepository(db);
    final completion = StudentCompletionService.unwired()..wire(checklistRepository: checklistRepo, ccfRepository: ccfRepo);
    final report = ClassReportService(
      db: db,
      classRepository: classRepo,
      studentRepository: studentRepo,
      checklistRepository: checklistRepo,
      ccfRepository: ccfRepo,
      completionService: completion,
    );

    final docRepo = DocumentRepository(db);
    final storage = DocumentStorageService(db: db, repository: docRepo, rootDirectoryOverride: temp);
    final package = ClassPackageService(db: db, reportService: report, documentStorageService: storage);

    final now = DateTime.now();
    await db.into(db.classRecords).insert(
          ClassRecordsCompanion(
            id: const Value('c1'),
            className: const Value('Export Class'),
            courseType: const Value(CourseType.blsProvider),
            writtenTestRequired: const Value(false),
            ccfRequired: const Value(false),
            isActive: const Value(false),
            lifecycleStatus: const Value(ClassLifecycleStatus.active),
            finalizationStatus: const Value(ClassFinalizationStatus.notStarted),
            completionRuleVersion: const Value(1),
            checklistDefinitionVersion: const Value(1),
            workingCopyNumber: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db.into(db.studentRecords).insert(
          StudentRecordsCompanion(
            id: const Value('s1'),
            classId: const Value('c1'),
            displayName: const Value('Student 1'),
            nameNeedsReview: const Value(false),
            writtenTestingFinalized: const Value(false),
            manualResultOverride: const Value(ManualStudentResultOverride.none),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await storage.importBytes(
      classId: 'c1',
      studentId: 's1',
      documentType: DocumentType.studentPhoto,
      displayName: 'Photo',
      originalFilename: 'photo.jpg',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB]),
    );

    final exported = await package.exportLiveClassPackage(classId: 'c1');
    expect(await exported.file.exists(), isTrue);

    final zipBytes = await exported.file.readAsBytes();
    final newClassId = await package.importClassPackage(zipBytes: zipBytes);
    expect(newClassId, isNot('c1'));

    final importedDocs = await (db.select(db.classDocuments)..where((t) => t.classId.equals(newClassId))).get();
    expect(importedDocs.length, 1);
    final importedFile = await storage.openFile(importedDocs.single);
    expect(await importedFile.exists(), isTrue);
  });
}
