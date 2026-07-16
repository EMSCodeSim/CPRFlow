import 'dart:typed_data';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/document_repository.dart';
import 'package:share_plus/share_plus.dart';

class UnsupportedDocumentTypeException implements Exception {
  UnsupportedDocumentTypeException(this.extension);
  final String extension;
}
class MissingStoredDocumentException implements Exception {
  MissingStoredDocumentException(this.documentId);
  final String documentId;
}
class InvalidDocumentException implements Exception {
  InvalidDocumentException(this.message);
  final String message;
}
class DuplicateDocumentException implements Exception {
  DuplicateDocumentException(this.existingDocumentId);
  final String existingDocumentId;
}
class ArchivedDocumentRecordIsReadOnlyException implements Exception {
  ArchivedDocumentRecordIsReadOnlyException(this.classId);
  final String classId;
}
class StorageHealthIssue {
  StorageHealthIssue({required this.kind, required this.message, this.documentId, this.storageFilename});
  final String kind;
  final String message;
  final String? documentId;
  final String? storageFilename;
}

/// Safe Dreamflow/web fallback. Native document storage remains available on
/// Android and iOS. The preview can start without loading dart:io.
class DocumentStorageService {
  DocumentStorageService({required AppDatabase db, required DocumentRepository repository, Object? rootDirectoryOverride, Object? idGenerator});

  static const supportedExtensions = <String>{'pdf', 'png', 'jpg', 'jpeg', 'heic', 'txt'};

  Never _unsupported() => throw UnsupportedError(
      'Local class-document storage is available in the Android and iOS app, not in the web preview.');

  Future<ClassDocument> importBytes({required String classId, String? studentId, required DocumentType documentType, required String displayName, required String originalFilename, required Uint8List bytes, String? notes}) async => _unsupported();
  Future<XFile> openFile(ClassDocument doc) async => _unsupported();
  Future<void> rename({required ClassDocument doc, required String newDisplayName}) async => _unsupported();
  Future<void> updateDetails({required ClassDocument doc, required String displayName, required DocumentType documentType, String? studentId, String? notes}) async => _unsupported();
  Future<void> move({required ClassDocument doc, required DocumentType newType, String? newStudentId}) async => _unsupported();
  Future<void> delete({required ClassDocument doc, bool hardDelete = false}) async => _unsupported();
  Future<List<StorageHealthIssue>> auditStorage({required String classId, bool includeDeleted = false}) async => const [];
  Future<void> repairOrphans({required String classId}) async => _unsupported();
  Future<String> computeChecksumBytes(Uint8List bytes) async => _unsupported();
  Future<void> validateImportFile({required String originalFilename, required Uint8List bytes}) async => _unsupported();
  Future<XFile> writeManagedFile({required String classId, required String storageFilename, required Uint8List bytes}) async => _unsupported();
  Future<void> exportClassDocumentsToArchive({required String classId, required dynamic archive, required List<dynamic> manifestFiles}) async => _unsupported();
}
