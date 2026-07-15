import 'dart:io';
import 'dart:typed_data';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/document_repository.dart';
import 'package:cpr_instructor_doc/domain/documents/document_storage_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DocumentStorageService import -> file exists -> delete removes file and marks deleted', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final temp = await Directory.systemTemp.createTemp('ccf_docs_test_');
    addTearDown(() => temp.delete(recursive: true));

    // Minimal class + student so FK constraints pass.
    final now = DateTime.now();
    await db.into(db.classRecords).insert(
          ClassRecordsCompanion(
            id: const Value('c1'),
            className: const Value('Test Class'),
            courseType: const Value(CourseType.blsProvider),
            writtenTestRequired: const Value(false),
            ccfRequired: const Value(false),
            isActive: const Value(true),
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

    final repo = DocumentRepository(db);
    final storage = DocumentStorageService(db: db, repository: repo, rootDirectoryOverride: temp);

    final bytes = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]); // "%PDF-1"
    final doc = await storage.importBytes(
      classId: 'c1',
      studentId: 's1',
      documentType: DocumentType.writtenTest,
      displayName: 'Written Test',
      originalFilename: 'written_test.pdf',
      bytes: bytes,
      notes: 'Unit test',
    );

    final file = await storage.openFile(doc);
    expect(await file.exists(), isTrue);

    await storage.rename(doc: doc, newDisplayName: 'Written Test (Renamed)');
    final updated = await repo.getById(doc.id);
    expect(updated?.displayName, 'Written Test (Renamed)');

    await storage.delete(doc: doc);
    expect(await file.exists(), isFalse);
    final deleted = await repo.getById(doc.id);
    expect(deleted?.deleted, isTrue);
  });
}
