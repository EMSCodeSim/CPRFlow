import 'package:drift/drift.dart';

import 'package:cpr_instructor_doc/data/local/app_database_executor_io.dart'
    if (dart.library.html) 'package:cpr_instructor_doc/data/local/app_database_executor_web.dart';

/// Opens the platform-appropriate Drift [QueryExecutor].
///
/// - On Android/iOS/macOS/Windows/Linux: SQLite (ffi/native)
/// - On Web (Dreamflow preview): IndexedDB-backed database
Future<QueryExecutor> openAppDatabaseExecutor() => openExecutor();

/// A small executor intended for tests.
QueryExecutor openAppDatabaseTestExecutor() => openTestExecutor();
