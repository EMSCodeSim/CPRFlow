import 'dart:convert';

import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/domain/archive/class_working_copy_service.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_checksum.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArchivedClassDetailScreen extends StatelessWidget {
  const ArchivedClassDetailScreen({super.key, required this.snapshotId});
  final String snapshotId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final db = services.database;
    if (db == null) {
      return const SafeErrorScreen(title: 'Archive unavailable', message: 'Class data is disabled.', onRetryLocation: AppRoutes.home);
    }

    return FutureBuilder(
      future: (db.select(db.finalClassSnapshots)..where((t) => t.id.equals(snapshotId))).getSingleOrNull(),
      builder: (context, snap) {
        if (snap.hasError) return const SafeErrorScreen(title: 'Archive record unavailable', message: 'Snapshot could not be loaded.', onRetryLocation: AppRoutes.archive);
        final row = snap.data;
        if (row == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
          integrityOk = SnapshotChecksum.sha256HexFromUtf8(snapshot.canonicalJson()) == row.checksum;
        } catch (e, st) {
          debugPrint('Snapshot parse failed: $e\n$st');
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Finalized Snapshot — Read Only')),
          body: SafeArea(
            child: snapshot == null
                ? const SafeErrorScreen(title: 'Archive record unreadable', message: 'Snapshot parsing failed. The record remains read-only.', onRetryLocation: AppRoutes.archive)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _IntegrityBanner(ok: integrityOk),
                      const SizedBox(height: 12),
                      Text(snapshot.classData.className, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text('Snapshot #${snapshot.classData.snapshotNumber} • Finalized ${snapshot.finalizedAt.toLocal()}'),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Totals', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text('Passed: ${snapshot.totals.passedCount}'),
                              Text('Incomplete: ${snapshot.totals.incompleteCount}'),
                              Text('Failed: ${snapshot.totals.failedCount}'),
                              const SizedBox(height: 8),
                              Text('Manual overrides: ${snapshot.totals.manualOverrideCount}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Students', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...snapshot.students.map(
                                (s) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(s.displayName),
                                  subtitle: Text('Auto: ${s.automaticResult.name} • Final: ${s.finalResult.name}${s.manualOverride != 'none' ? ' • Override: ${s.manualOverride}' : ''}'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: integrityOk ? () => _openWorkingCopySheet(context, snapshotId) : null,
                          icon: const Icon(Icons.copy),
                          label: const Text('Create Working Copy'),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openWorkingCopySheet(BuildContext context, String snapshotId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _WorkingCopySheet(snapshotId: snapshotId),
    );
  }
}

class _IntegrityBanner extends StatelessWidget {
  const _IntegrityBanner({required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = ok ? cs.primaryContainer : cs.errorContainer;
    final fg = ok ? cs.onPrimaryContainer : cs.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(ok ? Icons.verified : Icons.error, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok ? 'Integrity check passed.' : 'Finalized record integrity check failed.',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkingCopySheet extends StatefulWidget {
  const _WorkingCopySheet({required this.snapshotId});
  final String snapshotId;

  @override
  State<_WorkingCopySheet> createState() => _WorkingCopySheetState();
}

class _WorkingCopySheetState extends State<_WorkingCopySheet> {
  bool copyClassInfo = true;
  bool copyRoster = true;
  bool copyScores = false;
  bool copyChecklist = false;
  bool copyDates = false;
  bool isWorking = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Working Copy', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SwitchListTile(value: copyClassInfo, onChanged: (v) => setState(() => copyClassInfo = v), title: const Text('Copy class information')),
          SwitchListTile(value: copyRoster, onChanged: (v) => setState(() => copyRoster = v), title: const Text('Copy roster')),
          SwitchListTile(value: copyScores, onChanged: (v) => setState(() => copyScores = v), title: const Text('Copy written scores')), 
          SwitchListTile(value: copyChecklist, onChanged: (v) => setState(() => copyChecklist = v), title: const Text('Copy checklist results')), 
          SwitchListTile(value: copyDates, onChanged: (v) => setState(() => copyDates = v), title: const Text('Copy completion dates')),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isWorking ? null : _create,
              child: isWorking ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      isWorking = true;
      error = null;
    });
    try {
      final services = AppScope.of(context);
      final svc = services.classWorkingCopyService;
      if (svc == null) throw StateError('Working copy service unavailable');
      final res = await svc.createWorkingCopy(
        snapshotId: widget.snapshotId,
        options: WorkingCopyOptions(
          copyClassInformation: copyClassInfo,
          copyRoster: copyRoster,
          copyWrittenScores: copyScores,
          copyChecklistResults: copyChecklist,
          copyCompletionDates: copyDates,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go(AppRoutes.today);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Working copy created')));
      debugPrint('Working copy new classId=${res.newClassId}');
    } catch (e, st) {
      debugPrint('Working copy failed: $e\n$st');
      setState(() => error = 'Could not create working copy. ${e.toString()}');
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }
}
