import 'dart:async';

import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_state.dart';
import 'package:flutter/foundation.dart';

abstract class MonotonicClock {
  int nowMs();
}

class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();
  final Stopwatch _stopwatch;
  @override
  int nowMs() => _stopwatch.elapsedMilliseconds;
}

class CcfTimerController extends ChangeNotifier {
  CcfTimerController({
    Duration totalTarget = const Duration(minutes: 2),
    double passingThreshold = 80,
    MonotonicClock? clock,
  })  : _clock = clock ?? StopwatchClock(),
        _totalTarget = totalTarget,
        _passingThreshold = passingThreshold,
        state = CcfTimerState(
          phase: CcfTimerPhase.idle,
          elapsed: Duration.zero,
          compression: Duration.zero,
          pause: Duration.zero,
          totalTarget: totalTarget,
          passingThreshold: passingThreshold,
        );

  final MonotonicClock _clock;
  Duration _totalTarget;
  double _passingThreshold;
  Timer? _ticker;

  int? _startedAtMs;
  int? _lastResumedAtMs;
  int? _lastPausedAtMs;
  int _compressionAccumMs = 0;
  int _pauseAccumMs = 0;

  CcfTimerState state;

  DateTime? startedAtWall;
  DateTime? endedAtWall;

  void setPassingThreshold(double value) {
    _passingThreshold = value;
    state = state.copyWith(passingThreshold: value);
    notifyListeners();
  }

  void start() {
    if (state.phase != CcfTimerPhase.idle && state.phase != CcfTimerPhase.finished) return;
    _resetInternal();
    startedAtWall = DateTime.now();
    _startedAtMs = _clock.nowMs();
    _lastResumedAtMs = _startedAtMs;
    state = state.copyWith(phase: CcfTimerPhase.running);
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (state.phase != CcfTimerPhase.running) return;
    final now = _clock.nowMs();
    if (_lastResumedAtMs != null) _compressionAccumMs += now - _lastResumedAtMs!;
    _lastResumedAtMs = null;
    _lastPausedAtMs = now;
    state = state.copyWith(phase: CcfTimerPhase.paused);
    _recompute(nowMs: now);
    notifyListeners();
  }

  void resume() {
    if (state.phase != CcfTimerPhase.paused) return;
    final now = _clock.nowMs();
    if (_lastPausedAtMs != null) _pauseAccumMs += now - _lastPausedAtMs!;
    _lastPausedAtMs = null;
    _lastResumedAtMs = now;
    state = state.copyWith(phase: CcfTimerPhase.running);
    _recompute(nowMs: now);
    notifyListeners();
  }

  void refresh() {
    _recompute(nowMs: _clock.nowMs());
    if (state.phase != CcfTimerPhase.idle && state.phase != CcfTimerPhase.finished && state.elapsed >= _totalTarget) {
      finish();
      return;
    }
    notifyListeners();
  }

  void finish() {
    if (state.phase == CcfTimerPhase.finished || state.phase == CcfTimerPhase.idle) return;
    final now = _clock.nowMs();
    if (state.phase == CcfTimerPhase.running && _lastResumedAtMs != null) _compressionAccumMs += now - _lastResumedAtMs!;
    if (state.phase == CcfTimerPhase.paused && _lastPausedAtMs != null) _pauseAccumMs += now - _lastPausedAtMs!;
    _lastResumedAtMs = null;
    _lastPausedAtMs = null;
    endedAtWall = DateTime.now();
    _stopTicker();
    _recompute(nowMs: now, clampToTarget: true);
    state = state.copyWith(phase: CcfTimerPhase.finished);
    notifyListeners();
  }

  void reset() {
    _stopTicker();
    _resetInternal();
    notifyListeners();
  }

  void disposeTicker() => _stopTicker();

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  void _resetInternal() {
    endedAtWall = null;
    startedAtWall = null;
    _startedAtMs = null;
    _lastResumedAtMs = null;
    _lastPausedAtMs = null;
    _compressionAccumMs = 0;
    _pauseAccumMs = 0;
    state = CcfTimerState(
      phase: CcfTimerPhase.idle,
      elapsed: Duration.zero,
      compression: Duration.zero,
      pause: Duration.zero,
      totalTarget: _totalTarget,
      passingThreshold: _passingThreshold,
    );
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 120), (_) {
      _recompute(nowMs: _clock.nowMs());
      notifyListeners();
      if (state.phase != CcfTimerPhase.idle && state.phase != CcfTimerPhase.finished && state.elapsed >= _totalTarget) finish();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _recompute({required int nowMs, bool clampToTarget = false}) {
    final startedAt = _startedAtMs;
    if (startedAt == null) {
      state = state.copyWith(elapsed: Duration.zero, compression: Duration.zero, pause: Duration.zero);
      return;
    }
    var elapsedMs = nowMs - startedAt;
    if (clampToTarget) elapsedMs = elapsedMs.clamp(0, _totalTarget.inMilliseconds).toInt();

    var compressionMs = _compressionAccumMs;
    var pauseMs = _pauseAccumMs;
    if (state.phase == CcfTimerPhase.running && _lastResumedAtMs != null) compressionMs += nowMs - _lastResumedAtMs!;
    if (state.phase == CcfTimerPhase.paused && _lastPausedAtMs != null) pauseMs += nowMs - _lastPausedAtMs!;

    if (clampToTarget) {
      // IMPORTANT (Phase 2 stabilization):
      // When we auto-finish after passing the target duration, we must NOT
      // proportionally rescale previously completed time.
      //
      // Instead:
      //  - Clamp total elapsed time to the target.
      //  - Preserve fully completed intervals.
      //  - Remove overrun ONLY from the interval that was active when the
      //    target was reached (running => compression, paused => pause).

      final total = compressionMs + pauseMs;
      if (total > elapsedMs) {
        final overrun = total - elapsedMs;
        final activePhase = state.phase;
        if (activePhase == CcfTimerPhase.running) {
          compressionMs = (compressionMs - overrun).clamp(0, compressionMs).toInt();
        } else if (activePhase == CcfTimerPhase.paused) {
          pauseMs = (pauseMs - overrun).clamp(0, pauseMs).toInt();
        } else {
          // Shouldn't happen (finish() is only called from running/paused),
          // but keep totals consistent.
          pauseMs = (pauseMs - overrun).clamp(0, pauseMs).toInt();
        }

        // Rounding/clock jitter guard: ensure compression + pause == elapsed.
        final diff = elapsedMs - (compressionMs + pauseMs);
        if (diff != 0) {
          if (activePhase == CcfTimerPhase.running) {
            compressionMs = (compressionMs + diff).clamp(0, elapsedMs).toInt();
          } else {
            pauseMs = (pauseMs + diff).clamp(0, elapsedMs).toInt();
          }
        }
      }
    }

    state = state.copyWith(
      elapsed: Duration(milliseconds: elapsedMs),
      compression: Duration(milliseconds: compressionMs),
      pause: Duration(milliseconds: pauseMs),
      totalTarget: _totalTarget,
      passingThreshold: _passingThreshold,
    );
  }
}
