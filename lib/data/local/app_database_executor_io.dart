import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openExecutor() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'ccf_timer_v1.sqlite'));
  return LazyDatabase(
    () async => NativeDatabase(
      file,
      setup: (db) async {
        db.execute('PRAGMA foreign_keys = ON;');
        final rows = db.select('PRAGMA foreign_keys;');
        // Expected: [{foreign_keys: 1}]
        if (rows.isEmpty || rows.first.values.first != 1) {
          throw StateError('Failed to enable SQLite foreign keys');
        }
      },
    ),
  );
}

QueryExecutor openTestExecutor() => NativeDatabase.memory(
      setup: (db) async {
        db.execute('PRAGMA foreign_keys = ON;');
      },
    );
