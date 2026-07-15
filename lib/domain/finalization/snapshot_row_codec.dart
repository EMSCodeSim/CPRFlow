import 'dart:convert';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_checksum.dart';

/// Canonical serializer and integrity verifier for a persisted snapshot row.
/// Includes every frozen segment, not only class/student/totals data.
class SnapshotRowCodec {
  const SnapshotRowCodec._();

  static String canonicalFromSegments({
    required FinalClassSnapshotV1 snapshot,
    required Object? checklistData,
    required Object? ccfData,
    required Object? scoreData,
    required Object? completionResults,
  }) {
    final map = <String, Object?>{
      'snapshot': jsonDecode(snapshot.canonicalJson()),
      'checklists': _canonicalize(checklistData),
      'ccf': _canonicalize(ccfData),
      'scores': _canonicalize(scoreData),
      'completionResults': _canonicalize(completionResults),
    };
    return jsonEncode(_canonicalize(map));
  }

  static String canonicalFromRow(FinalClassSnapshot row) {
    final snapshot = FinalClassSnapshotV1(
      schemaVersion: row.schemaVersion,
      completionRuleVersion: row.completionRuleVersion,
      checklistDefinitionVersion: row.checklistDefinitionVersion,
      createdAt: row.createdAt,
      finalizedAt: row.finalizedAt,
      classData: FinalSnapshotClassV1.fromJson(
        (jsonDecode(row.classDataJson) as Map).cast<String, Object?>(),
      ),
      students: (jsonDecode(row.studentDataJson) as List)
          .cast<Map>()
          .map((e) => FinalSnapshotStudentV1.fromJson(e.cast<String, Object?>()))
          .toList(growable: false),
      totals: FinalSnapshotTotalsV1.fromJson(
        (jsonDecode(row.totalsJson) as Map).cast<String, Object?>(),
      ),
    );

    return canonicalFromSegments(
      snapshot: snapshot,
      checklistData: jsonDecode(row.checklistDataJson),
      ccfData: jsonDecode(row.ccfDataJson),
      scoreData: jsonDecode(row.scoreDataJson),
      completionResults: jsonDecode(row.completionResultsJson),
    );
  }

  static bool validate(FinalClassSnapshot row) {
    final canonical = canonicalFromRow(row);
    return SnapshotChecksum.sha256HexFromUtf8(canonical) == row.checksum;
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}
