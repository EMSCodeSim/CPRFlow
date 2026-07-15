import 'package:cpr_instructor_doc/startup/startup_issue.dart';

enum StartupPhase { idle, initializing, ready, recovery }

class StartupState {
  const StartupState._({required this.phase, this.issues = const []});

  final StartupPhase phase;
  final List<StartupIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  const StartupState.idle() : this._(phase: StartupPhase.idle);
  const StartupState.initializing() : this._(phase: StartupPhase.initializing);
  const StartupState.ready() : this._(phase: StartupPhase.ready);
  const StartupState.recovery(List<StartupIssue> issues) : this._(phase: StartupPhase.recovery, issues: issues);
}
