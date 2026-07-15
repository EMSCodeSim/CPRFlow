enum ReportSource {
  /// Uses current live class tables + current completion rules.
  liveClass,

  /// Uses a finalized snapshot row and its frozen segments only.
  finalizedSnapshot,

  /// Snapshot integrity failed (checksum/schema mismatch/etc). We still allow a
  /// clearly labeled preview, but it must not be presented as an official
  /// finalized report.
  legacySnapshotWarning,
}
