import 'dart:convert';

import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_checksum.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FinalizationSuccessScreen extends StatelessWidget {
  const FinalizationSuccessScreen({super.key, required this.snapshotId});
  final String snapshotId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final db = services.database;
    if (db == null) {
      return const SafeErrorScreen(title: 'Class data disabled', message: 'Archive is unavailable in recovery mode.', onRetryLocation: AppRoutes.home);
    }

    return FutureBuilder(
      future: (db.select(db.finalClassSnapshots)..where((t) => t.id.equals(snapshotId))).getSingleOrNull(),
      builder: (context, snap) {
        final row = snap.data;
        if (snap.hasError) {
          return const SafeErrorScreen(title: 'Finalization complete', message: 'Snapshot could not be loaded.', onRetryLocation: AppRoutes.archive);
        }
        if (row == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        FinalClassSnapshotV1? snapshot;
        bool integrityOk = false;
        try {
          final classJson = jsonDecode(row.classDataJson) as Map;
          final studentJson = jsonDecode(row.studentDataJson) as List;
          final totalsJson = jsonDecode(row.totalsJson) as Map;
          snapshot = FinalClassSnapshotV1(
            schemaVersion: row.schemaVersion,
            completionRuleVersion: row.completionRuleVersion,
            checklistDefinitionVersion: row.checklistDefinitionVersion,
            createdAt: row.createdAt,
            finalizedAt: row.finalizedAt,
            classData: FinalSnapshotClassV1.fromJson(classJson.cast<String, Object?>()),
            students: studentJson.cast<Map>().map((e) => FinalSnapshotStudentV1.fromJson(e.cast<String, Object?>())).toList(growable: false),
            totals: FinalSnapshotTotalsV1.fromJson(totalsJson.cast<String, Object?>()),
          );
          final checksum = SnapshotChecksum.sha256HexFromUtf8(snapshot.canonicalJson());
          integrityOk = checksum == row.checksum;
        } catch (e, st) {
          debugPrint('Failed to parse snapshot: $e\n$st');
        }

        final totals = snapshot?.totals;
        return Scaffold(
          appBar: AppBar(title: const Text('Finalized'), automaticallyImplyLeading: false),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snapshot?.classData.className ?? 'Class finalized', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Passed: ${totals?.passedCount ?? '-'}'),
                          Text('Incomplete: ${totals?.incompleteCount ?? '-'}'),
                          Text('Failed: ${totals?.failedCount ?? '-'}'),
                          const SizedBox(height: 10),
                          Text(integrityOk ? 'Integrity: OK' : 'Integrity: Warning', style: TextStyle(color: integrityOk ? null : Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('${AppRoutes.archivedClassDetail}/$snapshotId'),
                      icon: const Icon(Icons.archive),
                      label: const Text('View Archived Class'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Return Home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
