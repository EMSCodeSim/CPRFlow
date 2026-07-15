import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_controller.dart';
import 'package:cpr_instructor_doc/domain/ccf/ccf_timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock implements MonotonicClock {
  int _ms = 0;
  void advance(int deltaMs) => _ms += deltaMs;
  @override
  int nowMs() => _ms;
}

void main() {
  test('Tracks compression and pause durations accurately', () {
    final clock = FakeClock();
    final c = CcfTimerController(totalTarget: const Duration(minutes: 2), clock: clock);

    c.start();
    expect(c.state.phase, CcfTimerPhase.running);

    clock.advance(10 * 1000);
    c.refresh();
    expect(c.state.elapsed.inSeconds, 10);
    expect(c.state.compression.inSeconds, 10);

    c.pause();
    clock.advance(5 * 1000);
    c.refresh();
    expect(c.state.pause.inSeconds, 5);

    c.resume();
    clock.advance(15 * 1000);
    c.refresh();
    expect(c.state.compression.inSeconds, 25);

    c.finish();
    expect(c.state.phase, CcfTimerPhase.finished);
    expect(c.state.ccfPercentage, closeTo((25 / 30) * 100, 0.2));
  });

  test('Auto-finishes when target duration reached while paused', () {
    final clock = FakeClock();
    final c = CcfTimerController(totalTarget: const Duration(seconds: 10), clock: clock);

    c.start();
    clock.advance(3 * 1000);
    c.refresh();
    c.pause();

    // Advance past target while still paused.
    clock.advance(10 * 1000);
    c.refresh();
    expect(c.state.phase, CcfTimerPhase.finished);
    expect(c.state.elapsed.inSeconds, 10);
    // Compression should stop at pause point.
    expect(c.state.compression.inSeconds, 3);
    expect(c.state.pause.inSeconds, 7);
    expect(c.state.ccfPercentage, closeTo((3 / 10) * 100, 0.3));
  });

  test('Auto-finishes when target duration reached while running', () {
    final clock = FakeClock();
    final c = CcfTimerController(totalTarget: const Duration(seconds: 10), clock: clock);

    c.start();
    c.pause();
    clock.advance(3 * 1000);
    c.refresh();
    c.resume();

    // Advance past target while running.
    clock.advance(10 * 1000);
    c.refresh();
    expect(c.state.phase, CcfTimerPhase.finished);
    expect(c.state.elapsed.inSeconds, 10);
    // Pause is fully completed before resuming, and must be preserved.
    expect(c.state.pause.inSeconds, 3);
    expect(c.state.compression.inSeconds, 7);
    expect(c.state.ccfPercentage, closeTo((7 / 10) * 100, 0.3));
  });

  test('Multiple pause/resume periods preserve completed intervals at auto-finish', () {
    final clock = FakeClock();
    final c = CcfTimerController(totalTarget: const Duration(seconds: 10), clock: clock);

    c.start();
    clock.advance(2 * 1000);
    c.refresh();
    c.pause();

    clock.advance(3 * 1000);
    c.refresh();
    c.resume();

    clock.advance(4 * 1000);
    c.refresh();
    c.pause();

    // Now paused again at t=9s elapsed. Advance beyond target.
    clock.advance(5 * 1000);
    c.refresh();

    expect(c.state.phase, CcfTimerPhase.finished);
    expect(c.state.elapsed.inSeconds, 10);
    // Completed: 2s compression + 3s pause + 4s compression = 9s.
    // Active at target: pause interval clipped to 1s.
    expect(c.state.compression.inSeconds, 6);
    expect(c.state.pause.inSeconds, 4);
    expect(c.state.compression + c.state.pause, c.state.elapsed);
  });

  test('Background/resume after passing target produces same clipped totals', () {
    final clock = FakeClock();
    final c = CcfTimerController(totalTarget: const Duration(seconds: 10), clock: clock);

    c.start();
    clock.advance(3 * 1000);
    c.refresh();
    c.pause();
    // Simulate the app being in background: no refresh calls.
    clock.advance(15 * 1000);
    // On resume, refresh clips correctly.
    c.refresh();
    expect(c.state.phase, CcfTimerPhase.finished);
    expect(c.state.compression.inSeconds, 3);
    expect(c.state.pause.inSeconds, 7);
  });
}
