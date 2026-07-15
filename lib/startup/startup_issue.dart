enum StartupIssueKind {
  requiredInitFailed,
  requiredInitTimedOut,
  databaseOpenFailed,
  databaseHealthCheckFailed,
  unexpected,
}

class StartupIssue {
  StartupIssue({required this.kind, required this.message, this.stackTrace});

  final StartupIssueKind kind;
  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => 'StartupIssue(kind: $kind, message: $message)';
}
