enum ChecklistStatus { notStarted, incomplete, passed, failed, notRequired }

enum RequirementStatus { notStarted, incomplete, passed, failed, notRequired }

enum OverallStudentResult { pass, incomplete, fail }

extension ChecklistStatusLabels on ChecklistStatus {
  String get label {
    switch (this) {
      case ChecklistStatus.passed:
        return 'Complete';
      case ChecklistStatus.failed:
        return 'Needs Work';
      case ChecklistStatus.notStarted:
        return 'Not Started';
      case ChecklistStatus.incomplete:
        return 'Incomplete';
      case ChecklistStatus.notRequired:
        return 'N/A';
    }
  }
}

extension RequirementStatusLabels on RequirementStatus {
  String get label {
    switch (this) {
      case RequirementStatus.passed:
        return 'Complete';
      case RequirementStatus.failed:
        return 'Needs Work';
      case RequirementStatus.notStarted:
        return 'Not Started';
      case RequirementStatus.incomplete:
        return 'Incomplete';
      case RequirementStatus.notRequired:
        return 'N/A';
    }
  }
}
