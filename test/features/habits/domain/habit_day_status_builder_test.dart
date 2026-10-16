// Unit tests for HabitDayStatusBuilder: the day's progress/done/scheduled
// flags, the streak, the 7 week cells (future, before-start, skipped) and
// the progress labels the habit card shows.
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_day_status_builder.dart';

/// Saturday, 13 June 2026 — the fixed "today" of these tests.
final today = DateTime(2026, 6, 13);

/// 2026-06-[d].
DateTime june(int d) => DateTime(2026, 6, d);

Habit habit({
  HabitKind kind = HabitKind.build,
  int target = 1,
  String unit = 'times',
  HabitFrequency frequency = const HabitFrequency.everyDay(),
  DateTime? start,
  bool paused = false,
}) => Habit(
  id: 'h1',
  name: 'Test habit',
  kind: kind,
  targetCount: target,
  unit: unit,
  frequency: frequency,
  startDate: start ?? DateTime(2026, 1, 1),
  isPaused: paused,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

HabitLog log(DateTime date, {int count = 1, bool skipped = false}) => HabitLog(
  id: 'l$date',
  habitId: 'h1',
  date: date,
  count: count,
  skipped: skipped,
  createdAt: date,
  updatedAt: date,
);

void main() {
  group('build habit, mid-week day (Wed 10 June)', () {
    final h = habit(target: 8, unit: 'glasses');
    final logs = [
      log(june(8), count: 8),
      log(june(9), count: 3),
      log(june(10), count: 6),
      log(june(12), count: 8), // after the reference day
    ];
    final status = HabitDayStatusBuilder.build(h, logs, june(10));

    test('day fields', () {
      expect(status.day, june(10));
      expect(status.log, logs[2]);
      expect(status.count, 6);
      expect(status.progress, 0.75);
      expect(status.isDone, isFalse);
      expect(status.isScheduled, isTrue);
      expect(status.isSkipped, isFalse);
      expect(status.progressLabel, '6 / 8 glasses');
    });

    test('streak as of that day', () {
      // 10th open (no break), 9th missed → 0; best = the 8th.
      expect(status.currentStreak, 0);
      expect(status.streak.best, 1);
    });

    test('week cells Mon–Sun with future flags', () {
      expect(status.week.map((c) => c.day), [
        for (var d = 8; d <= 14; d++) june(d),
      ]);
      expect(status.week.map((c) => c.isFuture), [
        false, false, false, true, true, true, true, //
      ]);
      expect(status.week.map((c) => c.isDone), [
        true, false, false, false, false, false, false, //
      ]);
      expect(status.week.map((c) => c.progress), [
        1.0, 0.375, 0.75, 0, 0, 0, 0, //
      ]);
      expect(status.week.every((c) => c.isScheduled), isTrue);
    });

    test('week start from settings', () {
      final sunday = HabitDayStatusBuilder.build(
        h,
        logs,
        june(10),
        weekStartsOn: DateTime.sunday,
      );
      expect(sunday.week.first.day, june(7));
      expect(sunday.week.last.day, june(13));
    });

    test('value equality', () {
      expect(HabitDayStatusBuilder.build(h, logs, june(10)), status);
    });
  });

  group('labels', () {
    test('Completed', () {
      final h = habit(target: 8, unit: 'glasses');
      final logs = [
        log(june(11), count: 8),
        log(june(12), count: 9),
        log(today, count: 8),
      ];
      final s = HabitDayStatusBuilder.build(h, logs, today);
      expect(s.isDone, isTrue);
      expect(s.progress, 1.0);
      expect(s.progressLabel, 'Completed');
      expect(s.streak.label, '3 days');
    });

    test('Quit habit · day 9', () {
      final h = habit(kind: HabitKind.quit, start: june(1));
      final s = HabitDayStatusBuilder.build(h, [log(june(4), count: 2)], today);
      expect(s.progressLabel, 'Quit habit · day 9');
      expect(s.isDone, isTrue);
      expect(s.progress, 1.0);
      expect(s.streak.lastSlip, june(4));
      expect(s.week.map((c) => c.isDone), [
        true, true, true, true, true, true, false, //
      ]);
      expect(s.week.last.isFuture, isTrue);
    });

    test('quit habit with a slip today', () {
      final h = habit(kind: HabitKind.quit, start: june(1));
      final s = HabitDayStatusBuilder.build(h, [log(today)], today);
      expect(s.isDone, isFalse);
      expect(s.progress, 0);
      expect(s.count, 1);
      expect(s.progressLabel, 'Quit habit · day 0');
    });

    test('Rest day for a weekdays habit on Saturday', () {
      final h = habit(
        frequency: HabitFrequency.weekdays,
        target: 20,
        unit: 'min',
      );
      final s = HabitDayStatusBuilder.build(h, const [], today);
      expect(s.isScheduled, isFalse);
      expect(s.progressLabel, 'Rest day');
      expect(s.week.map((c) => c.isScheduled), [
        true, true, true, true, true, false, false, //
      ]);
    });

    test(
      'paused habit: not scheduled today ("Paused"), history cells still are',
      () {
        final h = habit(paused: true, target: 8, unit: 'glasses');
        final s = HabitDayStatusBuilder.build(h, const [], today);
        expect(s.isScheduled, isFalse);
        expect(s.progressLabel, 'Paused');
        expect(s.week.every((c) => c.isScheduled), isTrue);
      },
    );

    test('Skipped', () {
      final h = habit(target: 8, unit: 'glasses');
      final s = HabitDayStatusBuilder.build(h, [
        log(today, count: 2, skipped: true),
      ], today);
      expect(s.isSkipped, isTrue);
      expect(s.isDone, isFalse);
      expect(s.progress, 0);
      expect(s.progressLabel, 'Skipped');
      expect(s.week[5].isSkipped, isTrue);
      expect(s.week[4].isSkipped, isFalse);
    });

    test('yes/no habit not done shows the frequency', () {
      expect(
        HabitDayStatusBuilder.build(habit(), const [], today).progressLabel,
        'Every day',
      );
      final weekdays = habit(frequency: HabitFrequency.weekdays);
      expect(
        HabitDayStatusBuilder.build(weekdays, const [], june(12)).progressLabel,
        'Weekdays',
      );
    });
  });

  group('start date', () {
    test('cells before the start date are blank and unscheduled', () {
      // Quit habit: without the guard, empty days would count as clean.
      final h = habit(kind: HabitKind.quit, start: june(10));
      final s = HabitDayStatusBuilder.build(h, const [], june(12));
      expect(s.week.map((c) => c.isScheduled), [
        false, false, true, true, true, true, true, //
      ]);
      expect(s.week.map((c) => c.isDone), [
        false, false, true, true, true, false, false, //
      ]);
      expect(s.week.map((c) => c.progress), [0, 0, 1.0, 1.0, 1.0, 0, 0]);
      expect(s.week.map((c) => c.isFuture), [
        false, false, false, false, false, true, true, //
      ]);
      expect(s.progressLabel, 'Quit habit · day 3');
    });

    test('a day before the start date is neither scheduled nor done', () {
      final h = habit(kind: HabitKind.quit, start: june(10));
      final s = HabitDayStatusBuilder.build(h, const [], june(8));
      expect(s.isScheduled, isFalse);
      expect(s.isDone, isFalse);
      expect(s.progress, 0);
      expect(s.currentStreak, 0);
    });
  });

  test('3 years of daily logs build fast', () {
    final h = habit(start: DateTime(2023, 6, 13), target: 2);
    final logs = [
      for (var i = 0; i < 1097; i++) log(DateTime(2023, 6, 13 + i), count: 2),
    ];
    final sw = Stopwatch()..start();
    final s = HabitDayStatusBuilder.build(h, logs, today);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(200));
    expect(s.currentStreak, 1097);
    expect(s.progressLabel, 'Completed');
  });
}
