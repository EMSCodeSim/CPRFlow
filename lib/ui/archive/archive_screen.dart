import 'dart:convert';

import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_checksum.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String _query = '';
  ClassLifecycleStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final db = services.database;
    if (db == null) {
      return const SafeErrorScreen(title: 'Archive unavailable', message: 'Class data is disabled.', onRetryLocation: AppRoutes.home);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () async {
              final q = await showSearch<String?>(context: context, delegate: _ArchiveSearchDelegate(initial: _query));
              if (q != null) setState(() => _query = q);
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: _filter == ClassLifecycleStatus.completed,
                    onSelected: (_) => setState(() => _filter = ClassLifecycleStatus.completed),
                  ),
                  ChoiceChip(
                    label: const Text('Completed + Incomplete'),
                    selected: _filter == ClassLifecycleStatus.completedIncomplete,
                    onSelected: (_) => setState(() => _filter = ClassLifecycleStatus.completedIncomplete),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ClassRecord>>(
                stream: services.classRepository.watchArchivedClasses(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const SafeErrorScreen(title: 'Archive unavailable', message: 'Archived classes could not be loaded.', onRetryLocation: AppRoutes.home);
                  }
                  final classes = snap.data ?? const <ClassRecord>[];
                  final filtered = classes.where((c) {
                    if (_filter != null && c.lifecycleStatus != _filter) return false;
                    if (_query.trim().isEmpty) return true;
                    final q = _query.toLowerCase();
                    return c.className.toLowerCase().contains(q) ||
                        (c.location ?? '').toLowerCase().contains(q) ||
                        (c.leadInstructor ?? '').toLowerCase().contains(q) ||
                        (c.additionalInstructor ?? '').toLowerCase().contains(q);
                  }).toList(growable: false);

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No archived classes yet.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ArchiveClassCard(clazz: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveClassCard extends StatelessWidget {
  const _ArchiveClassCard({required this.clazz});
  final ClassRecord clazz;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final db = services.database;
    final snapshotId = clazz.activeSnapshotId;
    return Card(
      child: InkWell(
        onTap: snapshotId == null ? null : () => context.push('${AppRoutes.archivedClassDetail}/$snapshotId'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(clazz.className, style: Theme.of(context).textTheme.titleMedium)),
                  _LifecycleLabel(status: clazz.lifecycleStatus),
                ],
              ),
              const SizedBox(height: 6),
              Text('${clazz.classDate?.toLocal().toString() ?? '—'}  •  ${clazz.location ?? '—'}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              if (db != null && snapshotId != null)
                FutureBuilder(
                  future: (db.select(db.finalClassSnapshots)..where((t) => t.id.equals(snapshotId))).getSingleOrNull(),
                  builder: (context, snap) {
                    final row = snap.data;
                    if (row == null) return const SizedBox.shrink();
                    bool ok = false;
                    try {
                      final classJson = jsonDecode(row.classDataJson) as Map;
                      final studentsJson = jsonDecode(row.studentDataJson) as List;
                      final totalsJson = jsonDecode(row.totalsJson) as Map;
                      final s = FinalClassSnapshotV1(
                        schemaVersion: row.schemaVersion,
                        completionRuleVersion: row.completionRuleVersion,
                        checklistDefinitionVersion: row.checklistDefinitionVersion,
                        createdAt: row.createdAt,
                        finalizedAt: row.finalizedAt,
                        classData: FinalSnapshotClassV1.fromJson(classJson.cast<String, Object?>()),
                        students: studentsJson.cast<Map>().map((e) => FinalSnapshotStudentV1.fromJson(e.cast<String, Object?>())).toList(growable: false),
                        totals: FinalSnapshotTotalsV1.fromJson(totalsJson.cast<String, Object?>()),
                      );
                      ok = SnapshotChecksum.sha256HexFromUtf8(s.canonicalJson()) == row.checksum;
                    } catch (e, st) {
                      debugPrint('Snapshot parse failed in archive list: $e\n$st');
                    }
                    final integrity = ok ? 'Integrity OK' : 'Integrity warning';
                    final color = ok ? null : Theme.of(context).colorScheme.error;
                    return Text('Snapshot #${row.snapshotNumber} • $integrity', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color));
                  },
                )
              else
                Text('Snapshot missing', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CountPill(label: 'Pass', value: clazz.finalizedPassedCount),
                  const SizedBox(width: 8),
                  _CountPill(label: 'Inc', value: clazz.finalizedIncompleteCount),
                  const SizedBox(width: 8),
                  _CountPill(label: 'Fail', value: clazz.finalizedFailedCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.value});
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
      child: Text('$label: ${value ?? '—'}', style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _LifecycleLabel extends StatelessWidget {
  const _LifecycleLabel({required this.status});
  final ClassLifecycleStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      ClassLifecycleStatus.completed => 'Completed',
      ClassLifecycleStatus.completedIncomplete => 'Completed (Incomplete)',
      ClassLifecycleStatus.active => 'Active',
      ClassLifecycleStatus.finalizationInProgress => 'Finalizing',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _ArchiveSearchDelegate extends SearchDelegate<String?> {
  _ArchiveSearchDelegate({required String initial}) : super(searchFieldLabel: 'Search archive') {
    query = initial;
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            onPressed: () => query = '',
            icon: const Icon(Icons.close),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Search by class name, instructor, or location.', style: Theme.of(context).textTheme.bodyMedium),
      );
}
