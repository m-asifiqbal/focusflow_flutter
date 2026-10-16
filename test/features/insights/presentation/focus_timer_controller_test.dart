/// Focus timer — pure transitions on a FakeClock, and the controller
/// recording sessions through FocusSessionsRepository (keyed temp DB).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/insights/domain/services/focus_timer.dart';
import 'package:focusflow/features/insights/presentation/providers/focus_timer_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  final t0 = DateTime(2026, 10, 15, 9);

  group('FocusTimer (pure)', () {
    test('elapsed comes from instants and pauses bank time', () {
      var s = FocusTimer.start(const FocusTimerState(), t0);
      expect(s.phase, FocusPhase.running);
      final t1 = t0.add(const Duration(minutes: 10));
      expect(s.remainingAt(t1), const Duration(minutes: 15));
      s = FocusTimer.pause(s, t1);
      // Paused time does not count.
      final t2 = t1.add(const Duration(hours: 1));
      expect(s.elapsedAt(t2), const Duration(minutes: 10));
      s = FocusTimer.resume(s, t2);
      final t3 = t2.add(const Duration(minutes: 15));
      expect(FocusTimer.isDue(s, t3), isTrue);
      expect(s.progressAt(t3), 1);
      // Never beyond the planned length.
      expect(s.elapsedAt(t3.add(const Duration(hours: 2))), s.planned);
    });

    test('lengths are clamped and only editable before starting', () {
      var s = FocusTimer.setMinutes(const FocusTimerState(), 1);
      expect(s.plannedMinutes, FocusTimer.minMinutes);
      s = FocusTimer.setMinutes(s, 999);
      expect(s.plannedMinutes, FocusTimer.maxMinutes);
      s = FocusTimer.start(FocusTimer.setMinutes(s, 45), t0);
      expect(FocusTimer.setMinutes(s, 60).plannedMinutes, 45);
    });

    test('finish records whole minutes, nothing under a minute', () {
      final s = FocusTimer.start(const FocusTimerState(), t0);
      final short = FocusTimer.finish(s, t0.add(const Duration(seconds: 59)));
      expect(short.phase, FocusPhase.finished);
      expect(short.savedMinutes, isNull);
      final long = FocusTimer.finish(
        s,
        t0.add(const Duration(minutes: 12, seconds: 40)),
      );
      expect(long.savedMinutes, 12);
      expect(FocusTimer.reset(long), const FocusTimerState());
    });
  });

  group('FocusTimerController', () {
    late TestHarness h;
    const target = (taskId: null, taskTitle: null);

    setUp(() async => h = await TestHarness.create(now: t0));
    tearDown(() => h.dispose());

    Future<List<int>> recorded() async => [
      for (final f
          in await h
              .read(focusSessionsRepositoryProvider)
              .watchRange(
                t0.subtract(const Duration(days: 1)),
                t0.add(const Duration(days: 1)),
              )
              .first)
        f.durationMinutes,
    ];

    test('stop after ≥ 1 min records the elapsed minutes', () async {
      final sub = h.container.listen(focusTimerProvider(target), (_, _) {});
      addTearDown(sub.close);
      final c = h.read(focusTimerProvider(target).notifier);
      c.start();
      h.clock.advance(const Duration(minutes: 7, seconds: 30));
      c.pause();
      h.clock.advance(const Duration(minutes: 30));
      c.resume();
      h.clock.advance(const Duration(minutes: 3));
      expect(await c.stop(), 10);
      expect(await recorded(), [10]);
      final s = h.read(focusTimerProvider(target));
      expect(s.phase, FocusPhase.finished);
      expect(s.savedMinutes, 10);
    });

    test(
      'tick finishes at the planned length; short stops save nothing',
      () async {
        final sub = h.container.listen(focusTimerProvider(target), (_, _) {});
        addTearDown(sub.close);
        final c = h.read(focusTimerProvider(target).notifier)..start();
        h.clock.advance(const Duration(minutes: 24));
        await c.tick();
        expect(h.read(focusTimerProvider(target)).phase, FocusPhase.running);
        h.clock.advance(const Duration(minutes: 2));
        await c.tick();
        expect(h.read(focusTimerProvider(target)).savedMinutes, 25);

        c
          ..reset()
          ..start();
        h.clock.advance(const Duration(seconds: 40));
        expect(await c.stop(), isNull);
        expect(await recorded(), [25]);
      },
    );

    test(
      'disposing mid-session (sheet closed) saves it with the task',
      () async {
        const forTask = (taskId: 'task-1', taskTitle: 'Write report');
        final sub = h.container.listen(focusTimerProvider(forTask), (_, _) {});
        h.read(focusTimerProvider(forTask).notifier).start();
        h.clock.advance(const Duration(minutes: 5));
        sub.close();
        await Future<void>.delayed(Duration.zero); // auto-dispose
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final sessions = await h
            .read(focusSessionsRepositoryProvider)
            .watchRange(t0, t0.add(const Duration(days: 1)))
            .first;
        expect(sessions.single.durationMinutes, 5);
        expect(sessions.single.taskId, 'task-1');
        expect(sessions.single.startedAt, t0);
      },
    );
  });
}
