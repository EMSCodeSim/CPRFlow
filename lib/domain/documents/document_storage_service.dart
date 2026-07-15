import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/document_repository.dart';
import 'package:cpr_instructor_doc/utils/id_generator.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UnsupportedDocumentTypeException implements Exception {
  UnsupportedDocumentTypeException(this.extension);
  final String extension;

  @override
  String toString() => 'UnsupportedDocumentTypeException(extension: $extension)';
}

class MissingStoredDocumentException implements Exception {
  MissingStoredDocumentException(this.documentId);
  final String documentId;

  @override
  String toString() => 'MissingStoredDocumentException(documentId: $documentId)';
}

class StorageHealthIssue {
  StorageHealthIssue({required this.kind, required this.message, this.documentId, this.storageFilename});

  final String kind;
  final String message;
  final String? documentId;
  final String? storageFilename;
}

class DocumentStorageService {
  DocumentStorageService({
    required AppDatabase db,
    required DocumentRepository repository,
    Directory? rootDirectoryOverride,
    IdGenerator? idGenerator,
  })  : _repository = repository,
        _db = db,
        _rootDirectoryOverride = rootDirectoryOverride,
        _idGenerator = idGenerator ?? IdGenerator();

  final DocumentRepository _repository;
  final AppDatabase _db;
  final Directory? _rootDirectoryOverride;
  final IdGenerator _idGenerator;

  static const supportedExtensions = <String>{'pdf', 'png', 'jpg', 'jpeg', 'heic', 'txt'};

  Future<Directory> _getRootDir() async {
    if (_rootDirectoryOverride != null) return _rootDirectoryOverride!;
    final dir = await getApplicationDocumentsDirectory();
    return Directory(p.join(dir.path, 'Documents'));
  }

  Future<Directory> _getClassDir(String classId) async {
    final root = await _getRootDir();
    final safeClassId = _sanitizeSegment(classId);
    final dir = Directory(p.join(root.path, safeClassId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes bytes into managed storage under `Documents/<classId>/<storageFilename>`.
  ///
  /// This does not create or update Drift rows.
  Future<File> writeManagedFile({required String classId, required String storageFilename, required Uint8List bytes}) async {
    final classDir = await _getClassDir(classId);
    final safeName = _sanitizeSegment(storageFilename);
    final file = File(p.join(classDir.path, safeName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _sanitizeSegment(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  String _extOf(String filename) => p.extension(filename).replaceFirst('.', '').toLowerCase();

  String _guessMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'heic':
        return 'image/heic';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> computeChecksumBytes(Uint8List bytes) async => sha256.convert(bytes).toString();

  Future<String> computeChecksumFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> validateImportFile({required String originalFilename, required Uint8List bytes}) async {
    final ext = _extOf(originalFilename);
    if (!supportedExtensions.contains(ext)) throw UnsupportedDocumentTypeException(ext);
    if (bytes.isEmpty) throw StateError('Cannot import empty file');
    if (ext == 'pdf') {
      final prefix = utf8.decode(bytes.take(4).toList(), allowMalformed: true);
      if (prefix != '%PDF') debugPrint('Warning: Imported PDF does not start with %PDF (filename=$originalFilename)');
    }
  }

  Future<ClassDocument> importBytes({
    required String classId,
    String? studentId,
    required DocumentType documentType,
    required String displayName,
    required String originalFilename,
    required Uint8List bytes,
    String? notes,
  }) async {
    await validateImportFile(originalFilename: originalFilename, bytes: bytes);
    final ext = _extOf(originalFilename);
    final mimeType = _guessMimeType(ext);
    final checksum = await computeChecksumBytes(bytes);
    final now = DateTime.now();
    final storageName = _buildStorageFilename(originalFilename: originalFilename, checksum: checksum);
    final classDir = await _getClassDir(classId);
    final file = File(p.join(classDir.path, storageName));
    await file.writeAsBytes(bytes, flush: true);
    final size = await file.length();

    final id = _idGenerator.newId(prefix: 'doc');
    final row = ClassDocumentsCompanion(
      id: Value(id),
      classId: Value(classId),
      studentId: Value(studentId),
      documentType: Value(documentType),
      displayName: Value(displayName),
      originalFilename: Value(originalFilename),
      storageFilename: Value(storageName),
      mimeType: Value(mimeType),
      fileSize: Value(size),
      pageCount: const Value.absent(),
      checksum: Value(checksum),
      notes: Value(notes),
      deleted: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.into(_db.classDocuments).insert(row);
    final created = await _repository.getById(id);
    if (created == null) throw StateError('Failed to persist imported document');
    return created;
  }

  String _buildStorageFilename({required String originalFilename, required String checksum}) {
    final ext = _extOf(originalFilename);
    final safeBase = _sanitizeSegment(p.basenameWithoutExtension(originalFilename));
    final shortHash = checksum.substring(0, 12);
    return '${safeBase}_$shortHash.$ext';
  }

  Future<File> openFile(ClassDocument doc) async {
    final dir = await _getClassDir(doc.classId);
    final file = File(p.join(dir.path, _sanitizeSegment(doc.storageFilename)));
    if (!await file.exists()) throw MissingStoredDocumentException(doc.id);
    return file;
  }

  Future<void> rename({required ClassDocument doc, required String newDisplayName}) async {
    final now = DateTime.now();
    await (_db.update(_db.classDocuments)..where((t) => t.id.equals(doc.id))).write(ClassDocumentsCompanion(displayName: Value(newDisplayName), updatedAt: Value(now)));
  }

  Future<void> move({required ClassDocument doc, required DocumentType newType, String? newStudentId}) async {
    final now = DateTime.now();
    await (_db.update(_db.classDocuments)..where((t) => t.id.equals(doc.id))).write(ClassDocumentsCompanion(documentType: Value(newType), studentId: Value(newStudentId), updatedAt: Value(now)));
  }

  Future<void> delete({required ClassDocument doc, bool hardDelete = false}) async {
    try {
      final file = await openFile(doc);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Document delete: could not delete file for ${doc.id}: $e');
    }

    if (hardDelete) {
      await _repository.hardDeleteById(doc.id);
    } else {
      await _repository.markDeleted(id: doc.id, deleted: true);
    }
  }

  Future<List<StorageHealthIssue>> auditStorage({required String classId, bool includeDeleted = false}) async {
    final issues = <StorageHealthIssue>[];
    final q = _db.select(_db.classDocuments)..where((t) => t.classId.equals(classId));
    if (!includeDeleted) q.where((t) => t.deleted.equals(false));
    final docs = await q.get();

    final classDir = await _getClassDir(classId);
    final onDisk = <String>{};
    if (await classDir.exists()) {
      await for (final ent in classDir.list(followLinks: false)) {
        if (ent is File) onDisk.add(p.basename(ent.path));
      }
    }

    final referenced = <String>{};
    for (final d in docs) {
      referenced.add(d.storageFilename);
      final f = File(p.join(classDir.path, d.storageFilename));
      if (!await f.exists()) {
        issues.add(StorageHealthIssue(kind: 'missing_file', message: 'Missing file for document ${d.displayName}', documentId: d.id, storageFilename: d.storageFilename));
        continue;
      }
      try {
        final checksum = await computeChecksumFile(f);
        if (checksum != d.checksum) {
          issues.add(StorageHealthIssue(kind: 'checksum_mismatch', message: 'Checksum mismatch for ${d.displayName}', documentId: d.id, storageFilename: d.storageFilename));
        }
      } catch (e) {
        issues.add(StorageHealthIssue(kind: 'checksum_error', message: 'Checksum error for ${d.displayName}: $e', documentId: d.id, storageFilename: d.storageFilename));
      }
    }

    for (final f in onDisk) {
      if (!referenced.contains(f)) {
        issues.add(StorageHealthIssue(kind: 'orphan_file', message: 'File exists on disk but is not referenced: $f', storageFilename: f));
      }
    }
    return issues;
  }

  Future<void> repairOrphans({required String classId}) async {
    // Conservative repair: delete orphan files only (never auto-create records).
    final issues = await auditStorage(classId: classId, includeDeleted: true);
    final classDir = await _getClassDir(classId);
    for (final i in issues.where((i) => i.kind == 'orphan_file' && i.storageFilename != null)) {
      try {
        final f = File(p.join(classDir.path, i.storageFilename!));
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Failed to delete orphan file ${i.storageFilename}: $e');
      }
    }
  }

  /// Writes a ZIP containing the class document folder.
  ///
  /// This is used by the full class package exporter.
  Future<void> exportClassDocumentsToArchive({required String classId, required Archive archive}) async {
    final classDir = await _getClassDir(classId);
    if (!await classDir.exists()) return;
    await for (final ent in classDir.list(followLinks: false)) {
      if (ent is! File) continue;
      final name = p.basename(ent.path);
      final bytes = await ent.readAsBytes();
      archive.addFile(ArchiveFile('Documents/${_sanitizeSegment(classId)}/$name', bytes.length, bytes));
    }
  }
}
