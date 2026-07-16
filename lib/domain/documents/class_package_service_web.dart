import 'dart:typed_data';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/documents/document_storage_service.dart';
import 'package:cpr_instructor_doc/domain/reports/class_report_service.dart';
import 'package:share_plus/share_plus.dart';

class ClassPackageManifestFile {
  const ClassPackageManifestFile({required this.path, required this.size, required this.checksumSha256, required this.mimeType});
  final String path; final int size; final String checksumSha256; final String mimeType;
}
class ClassPackageManifest {
  const ClassPackageManifest({required this.packageVersion, required this.exportedAt, required this.appSchemaVersion, required this.source, required this.sourceId, required this.className, required this.files});
  final int packageVersion; final DateTime exportedAt; final int appSchemaVersion; final String source; final String sourceId; final String className; final List<ClassPackageManifestFile> files;
}
class ClassPackageBuildResult {
  const ClassPackageBuildResult({required this.file, required this.manifest});
  final XFile file;
  final ClassPackageManifest manifest;
}
class ClassPackageService {
  ClassPackageService({required AppDatabase db, required ClassReportService reportService, required DocumentStorageService documentStorageService, Object? pdfReportService, Object? atlasTemplateService, Object? atlasExportService, Object? idGenerator});
  Never _unsupported() => throw UnsupportedError('Class package export/import is available in the Android and iOS app, not in the web preview.');
  Future<ClassPackageBuildResult> exportLiveClassPackage({required String classId}) async => _unsupported();
  Future<String> importClassPackage({required Uint8List zipBytes}) async => _unsupported();
}
