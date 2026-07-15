/// Phase 3: Audit actions saved in [FinalizationAuditEntries].
///
/// Stored as stable strings inside the audit table.
enum FinalizationAuditAction {
  finalizationStarted,
  studentOverrideAdded,
  studentOverrideChanged,
  studentOverrideRemoved,
  finalizationCancelled,
  classFinalized,
  classFinalizedWithIncompleteStudents,
  workingCopyCreated,
}

extension FinalizationAuditActionSql on FinalizationAuditAction {
  String get sql {
    switch (this) {
      case FinalizationAuditAction.finalizationStarted:
        return 'finalizationStarted';
      case FinalizationAuditAction.studentOverrideAdded:
        return 'studentOverrideAdded';
      case FinalizationAuditAction.studentOverrideChanged:
        return 'studentOverrideChanged';
      case FinalizationAuditAction.studentOverrideRemoved:
        return 'studentOverrideRemoved';
      case FinalizationAuditAction.finalizationCancelled:
        return 'finalizationCancelled';
      case FinalizationAuditAction.classFinalized:
        return 'classFinalized';
      case FinalizationAuditAction.classFinalizedWithIncompleteStudents:
        return 'classFinalizedWithIncompleteStudents';
      case FinalizationAuditAction.workingCopyCreated:
        return 'workingCopyCreated';
    }
  }
}
