import 'dart:convert';

import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/finalization/final_snapshot_models.dart';
import 'package:cpr_instructor_doc/domain/finalization/finalization_audit_actions.dart';
import 'package:cpr_instructor_doc/domain/finalization/snapshot_row_codec.dart';
import 'package:cpr_instructor_doc/utils/id_generator.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class WorkingCopyOptions {
  const WorkingCopyOptions({
    this.copyClassInformation = true,
    this.copyRoster = true,
    this.copyWrittenScores = false,
    this.copyChecklistResults = false,
    this.copyCompletionDates = false,
  });

  final bool copyClassInformation;
  final bool copyRoster;
  final bool copyWrittenScores;
  final bool copyChecklistResults;
  final bool copyCompletionDates;
}

class WorkingCopyResult {
  const WorkingCopyResult({required this.newClassId});
  final String newClassId;
}

class ClassWorkingCopyService {
  ClassWorkingCopyService(this._db);

  final AppDatabase _db;

  Future<WorkingCopyResult> createWorkingCopy({required String snapshotId, required WorkingCopyOptions options}) async {
    final ids = IdGenerator();
    return _db.transaction(() async {
      final snapshotRow = await (_db.select(_db.finalClassSnapshots)..where((t) => t.id.equals(snapshotId))).getSingleOrNull();
      if (snapshotRow == null) throw StateError('Snapshot not found');

      if (!SnapshotRowCodec.validate(snapshotRow)) {
        throw StateError('Snapshot checksum validation failed');
      }

      final active = await (_db.select(_db.classRecords)..where((t) => t.isActive.equals(true))).getSingleOrNull();
      if (active != null) throw StateError('Active class already exists');

      final classJson = jsonDecode(snapshotRow.classDataJson) as Map;
      final classSnap = FinalSnapshotClassV1.fromJson(classJson.cast<String, Object?>());
      final studentJson = jsonDecode(snapshotRow.studentDataJson) as List;
      final students = studentJson.cast<Map>().map((e) => FinalSnapshotStudentV1.fromJson(e.cast<String, Object?>())).toList(growable: false);

      final newClassId = ids.newId(prefix: 'class');
      final now = DateTime.now();

      // Load original class to carry some settings (passing score/requirements).
      final original = await (_db.select(_db.classRecords)..where((t) => t.id.equals(snapshotRow.classId))).getSingleOrNull();
      if (original == null) throw StateError('Original class not found');

      await _db.into(_db.classRecords).insert(
            ClassRecordsCompanion(
              id: Value(newClassId),
              className: Value(options.copyClassInformation ? classSnap.className : 'Working Copy'),
              courseType: Value(original.courseType),
              classDate: Value(original.classDate),
              startTime: Value(original.startTime),
              endTime: Value(original.endTime),
              location: Value(original.location),
              leadInstructor: Value(original.leadInstructor),
              additionalInstructor: Value(original.additionalInstructor),
              trainingCenter: Value(original.trainingCenter),
              trainingSite: Value(original.trainingSite),
              writtenTestRequired: Value(original.writtenTestRequired),
              passingScore: Value(original.passingScore),
              ccfRequired: Value(original.ccfRequired),
              defaultSkillsCheckOffDate: Value(original.defaultSkillsCheckOffDate),
              defaultIssueDate: Value(original.defaultIssueDate),
              isActive: const Value(true),
              lifecycleStatus: const Value(ClassLifecycleStatus.active),
              finalizationStatus: const Value(ClassFinalizationStatus.notStarted),
              completionRuleVersion: Value(original.completionRuleVersion),
              checklistDefinitionVersion: Value(original.checklistDefinitionVersion),
              reopenedFromClassId: Value(snapshotRow.classId),
              workingCopyNumber: Value(original.workingCopyNumber + 1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      if (options.copyRoster) {
        for (final s in students) {
          final newStudentId = ids.newId(prefix: 'student');
          await _db.into(_db.studentRecords).insert(
                StudentRecordsCompanion(
                  id: Value(newStudentId),
                  classId: Value(newClassId),
                  displayName: Value(s.displayName),
                  originalFullName: Value(s.originalFullName),
                  firstName: Value(s.firstName),
                  lastName: Value(s.lastName),
                  email: Value(s.email),
                  phone: Value(s.phone),
                  nameNeedsReview: Value(s.nameNeedsReview),
                  writtenTestScore: options.copyWrittenScores ? Value(s.writtenScore) : const Value.absent(),
                  writtenTestingFinalized: options.copyWrittenScores ? Value(s.writtenFinalized) : const Value(false),
                  skillsCheckOffDate: options.copyCompletionDates && s.effectiveSkillsCheckOffDate != null ? Value(DateTime.parse(s.effectiveSkillsCheckOffDate!)) : const Value.absent(),
                  issueDate: options.copyCompletionDates && s.effectiveIssueDate != null ? Value(DateTime.parse(s.effectiveIssueDate!)) : const Value.absent(),
                  manualResultOverride: const Value(ManualStudentResultOverride.none),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
      }

      await _db.into(_db.finalizationAuditEntries).insert(
            FinalizationAuditEntriesCompanion(
              id: Value(ids.newId(prefix: 'audit')),
              classId: Value(newClassId),
              snapshotId: Value(snapshotId),
              action: Value(FinalizationAuditAction.workingCopyCreated.sql),
              timestamp: Value(now),
              newValueJson: Value(jsonEncode({'options': {
                'copyClassInformation': options.copyClassInformation,
                'copyRoster': options.copyRoster,
                'copyWrittenScores': options.copyWrittenScores,
                'copyChecklistResults': options.copyChecklistResults,
                'copyCompletionDates': options.copyCompletionDates,
              }})),
            ),
          );

      debugPrint('Working copy created: $newClassId from snapshot $snapshotId');
      return WorkingCopyResult(newClassId: newClassId);
    });
  }

}