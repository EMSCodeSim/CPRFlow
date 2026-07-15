import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_export_service.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_template_service.dart';
import 'package:cpr_instructor_doc/domain/documents/document_storage_service.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_service.dart';
import 'package:cpr_instructor_doc/domain/reports/pdf/pdf_report_service.dart';
import 'package:cpr_instructor_doc/utils/id_generator.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';

class ClassPackageManifestFile {
  const ClassPackageManifestFile({required this.path, required this.size, required this.checksumSha256, required this.mimeType});
  final String path;
  final int size;
  final String checksumSha256;
  final String mimeType;

  Map<String, Object?> toJson() => {
        'path': path,
        'size': size,
        'checksumSha256': checksumSha256,
        'mimeType': mimeType,
      };

  static ClassPackageManifestFile fromJson(Map<String, Object?> json) => ClassPackageManifestFile(
        path: (json['path'] as String?) ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        checksumSha256: (json['checksumSha256'] as String?) ?? '',
        mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
      );
}

class ClassPackageManifest {
  const ClassPackageManifest({
    required this.packageVersion,
    required this.exportedAt,
    required this.appSchemaVersion,
    required this.source,
    required this.sourceId,
    required this.className,
    required this.files,
  });

  final int packageVersion;
  final DateTime exportedAt;
  final int appSchemaVersion;
  final String source;
  final String sourceId;
  final String className;
  final List<ClassPackageManifestFile> files;

  Map<String, Object?> toJson() => {
        'packageVersion': packageVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'appSchemaVersion': appSchemaVersion,
        'source': source,
        'sourceId': sourceId,
        'className': className,
        'checksumAlgorithm': 'sha256',
        'files': files.map((e) => e.toJson()).toList(growable: false),
      };

  static ClassPackageManifest fromJson(Map<String, Object?> json) => ClassPackageManifest(
        packageVersion: (json['packageVersion'] as num?)?.toInt() ?? 1,
        exportedAt: DateTime.tryParse((json['exportedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        appSchemaVersion: (json['appSchemaVersion'] as num?)?.toInt() ?? 0,
        source: (json['source'] as String?) ?? 'unknown',
        sourceId: (json['sourceId'] as String?) ?? '',
        className: (json['className'] as String?) ?? '',
        files: ((json['files'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ClassPackageManifestFile.fromJson(e.cast<String, Object?>()))
            .toList(growable: false),
      );
}

class ClassPackageBuildResult {
  const ClassPackageBuildResult({required this.file, required this.manifest});
  final File file;
  final ClassPackageManifest manifest;
}

class ClassPackageService {
  ClassPackageService({
    required AppDatabase db,
    required ClassReportService reportService,
    required DocumentStorageService documentStorageService,
    PdfReportService? pdfReportService,
    AtlasTemplateService? atlasTemplateService,
    AtlasExportService? atlasExportService,
    IdGenerator? idGenerator,
  })  : _db = db,
        _reportService = reportService,
        _documentStorageService = documentStorageService,
        _pdfReportService = pdfReportService ?? PdfReportService(),
        _atlasTemplateService = atlasTemplateService ?? AtlasTemplateService(),
        _atlasExportService = atlasExportService ?? const AtlasExportService(),
        _idGenerator = idGenerator ?? IdGenerator();

  final AppDatabase _db;
  final ClassReportService _reportService;
  final DocumentStorageService _documentStorageService;
  final PdfReportService _pdfReportService;
  final AtlasTemplateService _atlasTemplateService;
  final AtlasExportService _atlasExportService;
  final IdGenerator _idGenerator;

  Future<Directory> _exportsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(root.path, 'Exports'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _sha256(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<ClassPackageBuildResult> exportLiveClassPackage({required String classId}) async {
    final clazz = await (_db.select(_db.classRecords)..where((t) => t.id.equals(classId))).getSingleOrNull();
    if (clazz == null) throw StateError('Class not found');

    final archive = Archive();
    final manifestFiles = <ClassPackageManifestFile>[];
    void addBytes({required String path, required Uint8List bytes, required String mimeType}) {
      final norm = path.replaceAll('\\', '/');
      archive.addFile(ArchiveFile(norm, bytes.length, bytes));
      manifestFiles.add(ClassPackageManifestFile(path: norm, size: bytes.length, checksumSha256: _sha256(bytes), mimeType: mimeType));
    }

    // 1) Snapshot: DB tables (schema v5) for full restore.
    final snapshot = await _buildLiveSnapshot(classId: classId);
    addBytes(path: 'Snapshot/snapshot.json', bytes: Uint8List.fromList(utf8.encode(jsonEncode(snapshot))), mimeType: 'application/json');

    // 2) Reports (PDF)
    final reportData = await _reportService.buildForLiveClass(classId: classId);
    final masterSkills = await _pdfReportService.buildMasterSkillsChecklist(data: reportData, paperSize: ReportPaperSize.letter);
    addBytes(path: 'Reports/${masterSkills.filename}', bytes: masterSkills.bytes, mimeType: 'application/pdf');
    final masterClass = await _pdfReportService.buildMasterClassList(data: reportData, paperSize: ReportPaperSize.letter);
    addBytes(path: 'Reports/${masterClass.filename}', bytes: masterClass.bytes, mimeType: 'application/pdf');
    final studentIds = reportData.studentRows.map((e) => e.studentId).toList(growable: false);
    if (studentIds.isNotEmpty) {
      final studentPdf = await _pdfReportService.buildStudentReports(data: reportData, studentIds: studentIds, paperSize: ReportPaperSize.letter);
      addBytes(path: 'Reports/${studentPdf.filename}', bytes: studentPdf.bytes, mimeType: 'application/pdf');
    }

    // 3) Atlas CSV (best-effort; export-ready only)
    try {
      final template = await _atlasTemplateService.load();
      final atlas = _atlasExportService.export(data: reportData, template: template, readyOnly: true);
      addBytes(path: 'Atlas/${atlas.filename}', bytes: Uint8List.fromList(utf8.encode(atlas.csv)), mimeType: 'text/csv');
    } catch (e) {
      debugPrint('Atlas export skipped: $e');
    }

    // 4) Documents folder
    await _documentStorageService.exportClassDocumentsToArchive(
      classId: classId,
      archive: archive,
      onFileAdded: (path, bytes, mimeType) {
        manifestFiles.add(
          ClassPackageManifestFile(
            path: path,
            size: bytes.length,
            checksumSha256: _sha256(bytes),
            mimeType: mimeType,
          ),
        );
      },
    );

    // 5) Manifest
    final manifest = ClassPackageManifest(
      packageVersion: 1,
      exportedAt: DateTime.now(),
      appSchemaVersion: _db.schemaVersion,
      source: 'liveClass',
      sourceId: classId,
      className: clazz.className,
      files: manifestFiles,
    );
    addBytes(path: 'Manifest.json', bytes: Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest.toJson()))), mimeType: 'application/json');

    final outDir = await _exportsDir();
    final filename = 'ClassPackage_${clazz.className.replaceAll(RegExp(r"[^A-Za-z0-9 _-]"), '').replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.zip';
    final outFile = File(p.join(outDir.path, filename));
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw StateError('Failed to encode zip');
    await outFile.writeAsBytes(zipBytes, flush: true);
    return ClassPackageBuildResult(file: outFile, manifest: manifest);
  }

  Future<Map<String, Object?>> _buildLiveSnapshot({required String classId}) async {
    final clazz = await (_db.select(_db.classRecords)..where((t) => t.id.equals(classId))).getSingle();
    final students = await (_db.select(_db.studentRecords)..where((t) => t.classId.equals(classId))).get();
    final attempts = await (_db.select(_db.checklistAttempts)..where((t) => t.classId.equals(classId))).get();
    final attemptIds = attempts.map((e) => e.id).toList(growable: false);
    final itemResults = attemptIds.isEmpty ? <ChecklistItemResult>[] : await (_db.select(_db.checklistItemResults)..where((t) => t.attemptId.isIn(attemptIds))).get();
    final ccf = await (_db.select(_db.ccfSessions)..where((t) => t.classId.equals(classId))).get();
    final docs = await (_db.select(_db.classDocuments)
          ..where((t) => t.classId.equals(classId) & t.deleted.equals(false)))
        .get();

    return {
      'schemaVersion': 5,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'classRecords': [clazz.toJson()],
        'studentRecords': students.map((e) => e.toJson()).toList(growable: false),
        'checklistAttempts': attempts.map((e) => e.toJson()).toList(growable: false),
        'checklistItemResults': itemResults.map((e) => e.toJson()).toList(growable: false),
        'ccfSessions': ccf.map((e) => e.toJson()).toList(growable: false),
        'classDocuments': docs.map((e) => e.toJson()).toList(growable: false),
      },
    };
  }

  Future<String> importClassPackage({required Uint8List zipBytes}) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final manifestEntry = archive.files.where((f) => f.name == 'Manifest.json').firstOrNull;
    if (manifestEntry == null) throw StateError('Manifest.json not found');
    final manifestJson = utf8.decode(manifestEntry.content as List<int>);
    final manifest = ClassPackageManifest.fromJson((jsonDecode(manifestJson) as Map).cast<String, Object?>());
    if (manifest.packageVersion != 1) throw StateError('Unsupported package version ${manifest.packageVersion}');

    final snapshotEntry = archive.files.where((f) => f.name == 'Snapshot/snapshot.json').firstOrNull;
    if (snapshotEntry == null) throw StateError('Snapshot not found in package');
    final snapshotJson = utf8.decode(snapshotEntry.content as List<int>);
    final snapshot = (jsonDecode(snapshotJson) as Map).cast<String, Object?>();
    final schemaVersion = (snapshot['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion != 5) throw StateError('Unsupported snapshot schema version $schemaVersion');

    // Validate every manifest entry before writing database rows or files.
    for (final f in manifest.files) {
      final entry = archive.files.where((e) => e.name == f.path).firstOrNull;
      if (entry == null || !entry.isFile) {
        throw StateError('Package is missing required file ${f.path}');
      }
      final bytes = Uint8List.fromList(entry.content as List<int>);
      if (bytes.length != f.size) throw StateError('File size validation failed for ${f.path}');
      final sha = _sha256(bytes);
      if (sha != f.checksumSha256) throw StateError('Checksum validation failed for ${f.path}');
    }

    final existingActive = await (_db.select(_db.classRecords)..where((t) => t.isActive.equals(true))).getSingleOrNull();
    if (existingActive != null) {
      throw StateError('Finalize or leave the current active class before importing a class package.');
    }

    final newClassId = _idGenerator.newId(prefix: 'class');
    final restoredFiles = <File>[];
    try {
      await _db.transaction(() async {
        await _restoreSnapshot(
          snapshot: snapshot,
          archive: archive,
          newClassId: newClassId,
          restoredFiles: restoredFiles,
        );
      });
      return newClassId;
    } catch (_) {
      for (final file in restoredFiles.reversed) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {
          // A later storage audit can remove any file that could not be cleaned.
        }
      }
      rethrow;
    }
  }

  Future<void> _restoreSnapshot({
    required Map<String, Object?> snapshot,
    required Archive archive,
    required String newClassId,
    required List<File> restoredFiles,
  }) async {
    final tables = (snapshot['tables'] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
    final classMaps = ((tables['classRecords'] as List?) ?? const []).whereType<Map>().toList();
    if (classMaps.isEmpty) throw StateError('Snapshot contains no class record');
    final originalClass = classMaps.first.cast<String, Object?>();
    final originalClassId = (originalClass['id'] as String?) ?? '';
    final className = (originalClass['className'] as String?) ?? 'Imported Class';
    final courseTypeRaw = originalClass['courseType'];
    final courseType = _courseTypeFromJson(courseTypeRaw);

    final classToInsert = ClassRecordsCompanion(
      id: Value(newClassId),
      className: Value(className),
      courseType: Value(courseType),
      classDate: Value(_dt(originalClass['classDate'])),
      startTime: Value(_dt(originalClass['startTime'])),
      endTime: Value(_dt(originalClass['endTime'])),
      location: Value(originalClass['location'] as String?),
      leadInstructor: Value(originalClass['leadInstructor'] as String?),
      additionalInstructor: Value(originalClass['additionalInstructor'] as String?),
      trainingCenter: Value(originalClass['trainingCenter'] as String?),
      trainingSite: Value(originalClass['trainingSite'] as String?),
      writtenTestRequired: Value(_bool(originalClass['writtenTestRequired'], fallback: false)),
      passingScore: Value((originalClass['passingScore'] as num?)?.toInt()),
      ccfRequired: Value(_bool(originalClass['ccfRequired'], fallback: false)),
      defaultSkillsCheckOffDate: Value(_dt(originalClass['defaultSkillsCheckOffDate'])),
      defaultIssueDate: Value(_dt(originalClass['defaultIssueDate'])),
      isActive: const Value(true),
      lifecycleStatus: const Value(ClassLifecycleStatus.active),
      finalizationStatus: const Value(ClassFinalizationStatus.notStarted),
      finalizedAt: const Value.absent(),
      completedAt: const Value.absent(),
      archivedAt: const Value.absent(),
      finalizedPassedCount: const Value.absent(),
      finalizedIncompleteCount: const Value.absent(),
      finalizedFailedCount: const Value.absent(),
      activeSnapshotId: const Value.absent(),
      snapshotSchemaVersion: const Value.absent(),
      completionRuleVersion: Value((originalClass['completionRuleVersion'] as num?)?.toInt() ?? 1),
      checklistDefinitionVersion: Value((originalClass['checklistDefinitionVersion'] as num?)?.toInt() ?? 1),
      reopenedFromClassId: Value(originalClassId.isEmpty ? null : originalClassId),
      workingCopyNumber: const Value(0),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );
    await _db.into(_db.classRecords).insert(classToInsert);

    // Students
    final studentMaps = ((tables['studentRecords'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, Object?>()).toList(growable: false);
    final studentIdMap = <String, String>{};
    for (final s in studentMaps) {
      final newStudentId = _idGenerator.newId(prefix: 'stu');
      final oldId = (s['id'] as String?) ?? '';
      studentIdMap[oldId] = newStudentId;
      final comp = StudentRecordsCompanion(
        id: Value(newStudentId),
        classId: Value(newClassId),
        displayName: Value((s['displayName'] as String?) ?? 'Student'),
        originalFullName: Value(s['originalFullName'] as String?),
        firstName: Value(s['firstName'] as String?),
        lastName: Value(s['lastName'] as String?),
        email: Value(s['email'] as String?),
        phone: Value(s['phone'] as String?),
        nameNeedsReview: Value(_bool(s['nameNeedsReview'], fallback: false)),
        writtenTestScore: Value((s['writtenTestScore'] as num?)?.toInt()),
        writtenTestingFinalized: Value(_bool(s['writtenTestingFinalized'], fallback: false)),
        skillsCheckOffDate: Value(_dt(s['skillsCheckOffDate'])),
        issueDate: Value(_dt(s['issueDate'])),
        manualResultOverride: Value(_manualOverrideFromJson(s['manualResultOverride'])),
        manualResultReason: Value(s['manualResultReason'] as String?),
        manualResultChangedAt: Value(_dt(s['manualResultChangedAt'])),
        manualResultInstructorInitials: Value(s['manualResultInstructorInitials'] as String?),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.studentRecords).insert(comp);
    }

    // Checklist attempts + item results
    final attemptMaps = ((tables['checklistAttempts'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, Object?>()).toList(growable: false);
    final attemptIdMap = <String, String>{};
    for (final a in attemptMaps) {
      final newAttemptId = _idGenerator.newId(prefix: 'att');
      final oldId = (a['id'] as String?) ?? '';
      attemptIdMap[oldId] = newAttemptId;
      final oldStudentId = (a['studentId'] as String?) ?? '';
      final comp = ChecklistAttemptsCompanion(
        id: Value(newAttemptId),
        classId: Value(newClassId),
        studentId: Value(studentIdMap[oldStudentId] ?? oldStudentId),
        checklistType: Value(_checklistTypeFromJson(a['checklistType'])),
        status: Value(_attemptStatusFromJson(a['status'])),
        finalized: Value(_bool(a['finalized'], fallback: false)),
        finalizedAt: Value(_dt(a['finalizedAt'])),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.checklistAttempts).insert(comp);
    }

    final itemMaps = ((tables['checklistItemResults'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, Object?>()).toList(growable: false);
    for (final r in itemMaps) {
      final oldAttemptId = (r['attemptId'] as String?) ?? '';
      final newAttemptId = attemptIdMap[oldAttemptId];
      if (newAttemptId == null) continue;
      final comp = ChecklistItemResultsCompanion(
        id: Value((r['id'] as String?) ?? _idGenerator.newId(prefix: 'item')),
        attemptId: Value(newAttemptId),
        itemId: Value((r['itemId'] as String?) ?? ''),
        result: Value(_itemResultFromJson(r['result'])),
        notes: Value(r['notes'] as String?),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.checklistItemResults).insertOnConflictUpdate(comp);
    }

    // CCF
    final ccfMaps = ((tables['ccfSessions'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, Object?>()).toList(growable: false);
    for (final s in ccfMaps) {
      final oldStudentId = s['studentId'] as String?;
      final comp = CcfSessionsCompanion(
        id: Value(_idGenerator.newId(prefix: 'ccf')),
        classId: Value(newClassId),
        studentId: Value(oldStudentId == null ? null : (studentIdMap[oldStudentId] ?? oldStudentId)),
        startedAt: Value(_dt(s['startedAt']) ?? DateTime.now()),
        endedAt: Value(_dt(s['endedAt'])),
        totalDurationMilliseconds: Value((s['totalDurationMilliseconds'] as num?)?.toInt() ?? 0),
        compressionDurationMilliseconds: Value((s['compressionDurationMilliseconds'] as num?)?.toInt() ?? 0),
        pauseDurationMilliseconds: Value((s['pauseDurationMilliseconds'] as num?)?.toInt() ?? 0),
        ccfPercentage: Value((s['ccfPercentage'] as num?)?.toDouble() ?? 0),
        passingThreshold: Value((s['passingThreshold'] as num?)?.toDouble() ?? 0),
        finalized: Value(_bool(s['finalized'], fallback: false)),
        result: Value(_ccfResultFromJson(s['result'])),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.ccfSessions).insert(comp);
    }

    // Documents: restore metadata + extracted files.
    final docMaps = ((tables['classDocuments'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, Object?>()).toList(growable: false);
    for (final d in docMaps) {
      // Extract file from ZIP (stored under old classId folder).
      final oldDocClassId = (d['classId'] as String?) ?? originalClassId;
      final storageFilename = (d['storageFilename'] as String?) ?? '';
      if (storageFilename.isEmpty) continue;
      final fileEntry = archive.files.where((e) => e.name == 'Documents/$oldDocClassId/$storageFilename').firstOrNull;
      if (fileEntry == null || !fileEntry.isFile) continue;
      final bytes = Uint8List.fromList(fileEntry.content as List<int>);
      final checksum = _sha256(bytes);
      final expected = (d['checksum'] as String?) ?? '';
      if (expected.isNotEmpty && checksum != expected) {
        throw StateError('Checksum validation failed for document $storageFilename');
      }
      final restoredFile = await _documentStorageService.writeManagedFile(
        classId: newClassId,
        storageFilename: storageFilename,
        bytes: bytes,
      );
      restoredFiles.add(restoredFile);

      final newDocId = _idGenerator.newId(prefix: 'doc');
      final oldStudentId = d['studentId'] as String?;
      final comp = ClassDocumentsCompanion(
        id: Value(newDocId),
        classId: Value(newClassId),
        studentId: Value(oldStudentId == null ? null : (studentIdMap[oldStudentId] ?? oldStudentId)),
        documentType: Value(_documentTypeFromJson(d['documentType'])),
        displayName: Value((d['displayName'] as String?) ?? storageFilename),
        originalFilename: Value((d['originalFilename'] as String?) ?? storageFilename),
        storageFilename: Value(storageFilename),
        mimeType: Value((d['mimeType'] as String?) ?? 'application/octet-stream'),
        fileSize: Value(bytes.length),
        pageCount: Value((d['pageCount'] as num?)?.toInt()),
        checksum: Value(checksum),
        notes: Value(d['notes'] as String?),
        deleted: Value(_bool(d['deleted'], fallback: false)),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.classDocuments).insert(comp);
    }
  }
}

DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v) : null;
bool _bool(Object? v, {required bool fallback}) => v is bool ? v : fallback;

CourseType _courseTypeFromJson(Object? v) {
  if (v is String) {
    if (v == 'blsProvider' || v == 'bls_provider') return CourseType.blsProvider;
  }
  return CourseType.blsProvider;
}

ManualStudentResultOverride _manualOverrideFromJson(Object? v) {
  if (v is String) {
    return switch (v) {
      'none' => ManualStudentResultOverride.none,
      'pass' => ManualStudentResultOverride.pass,
      'incomplete' => ManualStudentResultOverride.incomplete,
      'fail' => ManualStudentResultOverride.fail,
      _ => ManualStudentResultOverride.none,
    };
  }
  return ManualStudentResultOverride.none;
}

ChecklistType _checklistTypeFromJson(Object? v) {
  if (v is String) {
    if (v == 'adult' || v == 'ChecklistType.adult') return ChecklistType.adult;
    if (v == 'infantChild' || v == 'infant_child' || v == 'ChecklistType.infantChild') return ChecklistType.infantChild;
  }
  return ChecklistType.adult;
}

ChecklistAttemptStatus _attemptStatusFromJson(Object? v) {
  if (v is String) {
    return switch (v) {
      'notStarted' => ChecklistAttemptStatus.notStarted,
      'inProgress' => ChecklistAttemptStatus.inProgress,
      'passed' => ChecklistAttemptStatus.passed,
      'failed' => ChecklistAttemptStatus.failed,
      'not_started' => ChecklistAttemptStatus.notStarted,
      'in_progress' => ChecklistAttemptStatus.inProgress,
      _ => ChecklistAttemptStatus.notStarted,
    };
  }
  return ChecklistAttemptStatus.notStarted;
}

ChecklistItemResultValue _itemResultFromJson(Object? v) {
  if (v is String) {
    return switch (v) {
      'notEvaluated' => ChecklistItemResultValue.notEvaluated,
      'passed' => ChecklistItemResultValue.passed,
      'needsRemediation' => ChecklistItemResultValue.needsRemediation,
      'not_evaluated' => ChecklistItemResultValue.notEvaluated,
      'needs_remediation' => ChecklistItemResultValue.needsRemediation,
      _ => ChecklistItemResultValue.notEvaluated,
    };
  }
  return ChecklistItemResultValue.notEvaluated;
}

CcfResultValue _ccfResultFromJson(Object? v) {
  if (v is String) {
    return switch (v) {
      'incomplete' => CcfResultValue.incomplete,
      'passed' => CcfResultValue.passed,
      'failed' => CcfResultValue.failed,
      _ => CcfResultValue.incomplete,
    };
  }
  return CcfResultValue.incomplete;
}

DocumentType _documentTypeFromJson(Object? v) {
  if (v is String) {
    return switch (v) {
      'writtenTest' => DocumentType.writtenTest,
      'written_test' => DocumentType.writtenTest,
      'classRoster' => DocumentType.classRoster,
      'class_roster' => DocumentType.classRoster,
      'atlasRoster' => DocumentType.atlasRoster,
      'atlas_roster' => DocumentType.atlasRoster,
      'attendance' => DocumentType.attendance,
      'studentSkillSheet' => DocumentType.studentSkillSheet,
      'student_skill_sheet' => DocumentType.studentSkillSheet,
      'studentEvaluation' => DocumentType.studentEvaluation,
      'student_evaluation' => DocumentType.studentEvaluation,
      'studentPhoto' => DocumentType.studentPhoto,
      'student_photo' => DocumentType.studentPhoto,
      'miscellaneous' => DocumentType.miscellaneous,
      _ => DocumentType.miscellaneous,
    };
  }
  return DocumentType.miscellaneous;
}

extension _ArchiveFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
