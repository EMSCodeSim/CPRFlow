enum CcfTimerPhase { idle, running, paused, finished }

class CcfTimerState {
  const CcfTimerState({
    required this.phase,
    required this.elapsed,
    required this.compression,
    required this.pause,
    required this.totalTarget,
    required this.passingThreshold,
  });

  final CcfTimerPhase phase;
  final Duration elapsed;
  final Duration compression;
  final Duration pause;
  final Duration totalTarget;
  final double passingThreshold; // 0-100

  double get ccfPercentage {
    final totalMs = elapsed.inMilliseconds;
    if (totalMs <= 0) return 0;
    return (compression.inMilliseconds / totalMs) * 100.0;
  }

  bool get isPassing => ccfPercentage >= passingThreshold;

  CcfTimerState copyWith({
    CcfTimerPhase? phase,
    Duration? elapsed,
    Duration? compression,
    Duration? pause,
    Duration? totalTarget,
    double? passingThreshold,
  }) =>
      CcfTimerState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        compression: compression ?? this.compression,
        pause: pause ?? this.pause,
        totalTarget: totalTarget ?? this.totalTarget,
        passingThreshold: passingThreshold ?? this.passingThreshold,
      );
}
