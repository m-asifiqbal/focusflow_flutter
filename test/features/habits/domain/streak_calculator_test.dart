// Unit tests for StreakCalculator / HabitStreak: daily, specific-day,
// every-N-days, N×-per-week (weeks) and quit-habit streaks, skips, best
// streaks, messy input and a 3-year history.
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

/// Saturday, 13 June 2026 — the fixed "today" of these tests.
final today = DateTime(2026, 6, 13);

/// A day relative to [today] (DST-safe).
DateTime day(int offset) => DateTime(2026, 6, 13 + offset);

/// 2026-06-[d].
DateTime june(int d) => DateTime(2026, 6, d);

Habit habit({
  HabitKind kind = HabitKind.build,
  int target = 1,
  HabitFrequency frequency = const HabitFrequency.everyDay(),
  DateTime? start,
  bool paused = false,
}) => Habit(
  id: 'h1',
  name: 'Test habit',
  kind: kind,
  targetCount: target,
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

/// Done logs for every day in [from, to] (offsets from today).
List<HabitLog> doneRange(int from, int to, {int count = 1}) => [
  for (var i = from; i <= to; i++) log(day(i), count: count),
];

const calc = StreakCalculator();

void main() {
  group('HabitStreak', () {
    test('label', () {
      expect(const HabitStreak(current: 12, best: 12).label, '12 days');
      expect(const HabitStreak(current: 1, best: 3).label, '1 day');
      expect(HabitStreak.zero.label, '0 days');
      const weeks = HabitStreak(current: 3, best: 3, unit: StreakUnit.weeks);
      expect(weeks.label, '3 weeks');
      expect(
        const HabitStreak(current: 1, best: 1, unit: StreakUnit.weeks).label,
        '1 week',
      );
    });

    test('value equality', () {
      expect(
        HabitStreak(current: 2, best: 5, lastSlip: june(1)),
        HabitStreak(current: 2, best: 5, lastSlip: june(1)),
      );
      expect(
        HabitStreak(current: 2, best: 5, lastSlip: june(1)).hashCode,
        HabitStreak(current: 2, best: 5, lastSlip: june(1)).hashCode,
      );
      expect(
        const HabitStreak(current: 2, best: 5),
        isNot(const HabitStreak(current: 2, best: 5, unit: StreakUnit.weeks)),
      );
    });
  });

  group('build habit, every day', () {
    test('today not done yet does not break the streak', () {
      final s = calc.calculate(habit(), doneRange(-5, -1), today);
      expect(s, const HabitStreak(current: 5, best: 5));
    });

    test('today done adds to the streak', () {
      expect(calc.calculate(habit(), doneRange(-5, 0), today).current, 6);
    });

    test('yesterday missed breaks the streak', () {
      final logs = [...doneRange(-6, -2), log(today)];
      final s = calc.calculate(habit(), logs, today);
      expect(s.current, 1);
      expect(s.best, 5);
      expect(calc.calculate(habit(), doneRange(-6, -2), today).current, 0);
    });

    test('below target is not done', () {
      final h = habit(target: 8);
      final logs = [...doneRange(-3, -1, count: 8), log(day(-4), count: 7)];
      expect(calc.calculate(h, logs, today).current, 3);
    });

    test('a skipped day neither breaks nor adds', () {
      final logs = [
        ...doneRange(-5, -4),
        log(day(-3), skipped: true),
        ...doneRange(-2, -1),
      ];
      expect(calc.calculate(habit(), logs, today).current, 4);
    });

    test('skipped with a count still counts as skipped', () {
      final logs = [
        ...doneRange(-3, -2),
        log(day(-1), count: 5, skipped: true),
      ];
      expect(calc.calculate(habit(), logs, today).current, 2);
    });

    test('today skipped does not break', () {
      final logs = [...doneRange(-3, -1), log(today, skipped: true)];
      expect(calc.calculate(habit(), logs, today).current, 3);
    });

    test('best streak longer than current', () {
      final h = habit(start: june(1));
      final logs = [
        for (var d = 1; d <= 10; d++) log(june(d)),
        log(june(12)),
        log(june(13)),
      ];
      expect(
        calc.calculate(h, logs, today),
        const HabitStreak(current: 2, best: 10),
      );
    });

    test('a 45-day streak', () {
      final logs = doneRange(-44, 0);
      expect(
        calc.calculate(habit(), logs, today),
        const HabitStreak(current: 45, best: 45),
      );
    });

    test('streak never extends before the start date', () {
      final h = habit(start: june(10));
      final s = calc.calculate(h, doneRange(-20, 0), today);
      expect(s, const HabitStreak(current: 4, best: 4));
    });

    test('pause is ignored for history', () {
      final h = habit(paused: true);
      expect(calc.calculate(h, doneRange(-3, -1), today).current, 3);
    });

    test('logs out of order, outside the range and in the future', () {
      final h = habit(start: june(5));
      final logs = [
        log(june(12)),
        log(day(5)), // future
        log(june(9)),
        log(june(1)), // before start
        log(june(11)),
        log(june(10)),
        log(june(14)), // tomorrow
      ]..shuffle();
      expect(
        calc.calculate(h, logs, today),
        const HabitStreak(current: 4, best: 4),
      );
    });

    test('today before the start date → zero', () {
      final h = habit(start: day(3));
      expect(calc.calculate(h, doneRange(-3, 0), today), HabitStreak.zero);
    });
  });

  group('build habit, specific days', () {
    test('weekdays-only habit does not break over a weekend', () {
      final h = habit(frequency: HabitFrequency.weekdays, start: june(1));
      final logs = [
        for (final d in [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]) log(june(d)),
      ];
      // Saturday: not scheduled, ignored.
      expect(calc.calculate(h, logs, today).current, 10);
      // Monday 15th, not done yet: the empty weekend still doesn't break.
      expect(calc.calculate(h, logs, june(15)).current, 10);
      // Tuesday 16th: Monday was missed → broken.
      expect(
        calc.calculate(h, logs, june(16)),
        const HabitStreak(current: 0, best: 10),
      );
    });

    test('logs on unscheduled days are ignored', () {
      final h = habit(frequency: HabitFrequency.weekdays, start: june(1));
      final logs = [
        for (final d in [8, 9, 10, 11, 12]) log(june(d)),
        log(june(6)), // Saturday
        log(june(7)), // Sunday
      ];
      expect(calc.calculate(h, logs, today).current, 5);
    });

    test('Mon / Wed / Fri habit', () {
      final h = habit(
        frequency: HabitFrequency.onWeekdays(const [
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        ]),
        start: june(1),
      );
      final all = [
        for (final d in [1, 3, 5, 8, 10, 12]) log(june(d)),
      ];
      expect(calc.calculate(h, all, today).current, 6);

      final missedWed = all.where((l) => l.date != june(10)).toList();
      expect(
        calc.calculate(h, missedWed, today),
        const HabitStreak(current: 1, best: 4),
      );
    });
  });

  group('build habit, every N days', () {
    test('only every second day counts', () {
      final h = habit(
        frequency: const HabitFrequency.everyNDays(2),
        start: june(1),
      );
      final logs = [
        for (final d in [1, 3, 5, 7, 9, 11]) log(june(d)),
        log(june(12)), // unscheduled, ignored
      ];
      // 13th is scheduled and still open.
      expect(calc.calculate(h, logs, today).current, 6);
      final missed = logs.where((l) => l.date != june(7)).toList();
      expect(
        calc.calculate(h, missed, today),
        const HabitStreak(current: 2, best: 3),
      );
    });
  });

  group('build habit, times per week (weeks)', () {
    // Weeks (Monday start): May 18–24, May 25–31, June 1–7, June 8–14.
    final h = habit(
      frequency: const HabitFrequency.timesPerWeek(3),
      start: DateTime(2026, 5, 18),
    );

    List<HabitLog> threeIn(DateTime monday) => [
      for (final i in [0, 2, 4])
        log(DateTime(monday.year, monday.month, monday.day + i)),
    ];

    test('current week in progress does not break', () {
      final logs = [
        ...threeIn(DateTime(2026, 5, 18)),
        ...threeIn(DateTime(2026, 5, 25)),
        ...threeIn(june(1)),
        log(june(8)),
      ];
      final s = calc.calculate(h, logs, today);
      expect(s, const HabitStreak(current: 3, best: 3, unit: StreakUnit.weeks));
      expect(s.label, '3 weeks');
    });

    test('current week met counts', () {
      final logs = [
        ...threeIn(DateTime(2026, 5, 25)),
        ...threeIn(june(1)),
        ...threeIn(june(8)),
      ];
      expect(calc.calculate(h, logs, today).current, 3);
    });

    test('an unmet past week breaks', () {
      final logs = [
        ...threeIn(DateTime(2026, 5, 18)),
        log(DateTime(2026, 5, 25)),
        log(DateTime(2026, 5, 26)),
        ...threeIn(june(1)),
      ];
      expect(
        calc.calculate(h, logs, today),
        const HabitStreak(current: 1, best: 1, unit: StreakUnit.weeks),
      );
    });

    test('skipped days count towards the week', () {
      final logs = [log(june(1)), log(june(2)), log(june(3), skipped: true)];
      expect(calc.calculate(h, logs, today).current, 1);
    });

    test('partial first week needs only the days available', () {
      // Starts Saturday 6 June: only Sat + Sun left in that week → 2 needed.
      final late = habit(
        frequency: const HabitFrequency.timesPerWeek(3),
        start: june(6),
      );
      final logs = [log(june(6)), log(june(7)), ...threeIn(june(8))];
      expect(calc.calculate(late, logs, today).current, 2);
      // One check-in in the 2-day first week is not enough.
      expect(calc.calculate(late, logs.skip(1), today).current, 1);
    });

    test('partial first week with plenty of days still needs N', () {
      // Starts Thursday 4 June: 4 days left → min(3, 4) = 3 needed.
      final h4 = habit(
        frequency: const HabitFrequency.timesPerWeek(3),
        start: june(4),
      );
      expect(
        calc.calculate(h4, [log(june(4)), log(june(5))], today).current,
        0,
      );
      expect(
        calc.calculate(h4, [
          log(june(4)),
          log(june(5)),
          log(june(7)),
        ], today).current,
        1,
      );
    });

    test('week start from settings changes the buckets', () {
      // Sunday weeks: May 31–June 6 contains only the start day (Sat 6th).
      final late = habit(
        frequency: const HabitFrequency.timesPerWeek(3),
        start: june(6),
      );
      const sundayCalc = StreakCalculator(weekStartsOn: DateTime.sunday);
      final logs = [log(june(6)), log(june(7)), log(june(8))];
      // Week 1 (1 day) met with 1 check-in; week June 7–13 has 2 → current
      // week still in progress.
      expect(sundayCalc.calculate(late, logs, today).current, 1);
      // Monday weeks: June 1–7 met (2 of 2), June 8–14 in progress.
      expect(calc.calculate(late, logs, today).current, 1);
      expect(calc.calculate(late, logs.take(1), today).current, 0);
      expect(sundayCalc.calculate(late, logs.take(1), today).current, 1);
    });
  });

  group('quit habit', () {
    Habit quit({DateTime? start}) =>
        habit(kind: HabitKind.quit, start: start ?? june(1));

    test('never slipped → days since start, today included', () {
      final s = calc.calculate(quit(), const [], today);
      expect(s, const HabitStreak(current: 13, best: 13));
      expect(s.lastSlip, isNull);
    });

    test('slip on D, today = D + 9 → 9 clean days', () {
      final s = calc.calculate(quit(), [log(june(4), count: 2)], today);
      expect(s.current, 9);
      expect(s.best, 9);
      expect(s.lastSlip, june(4));
    });

    test('slip today → 0', () {
      final s = calc.calculate(quit(), [log(today)], today);
      expect(s.current, 0);
      expect(s.best, 12);
      expect(s.lastSlip, today);
    });

    test('best clean run between slips', () {
      final s = calc.calculate(quit(start: DateTime(2026, 5, 1)), [
        log(DateTime(2026, 5, 21)),
        log(june(3)),
      ], today);
      // May 1–20 = 20, May 22 – June 2 = 12, June 4–13 = 10.
      expect(s, HabitStreak(current: 10, best: 20, lastSlip: june(3)));
    });

    test('count 0 and skipped logs are clean', () {
      final logs = [
        log(june(10), count: 0),
        log(june(11), count: 3, skipped: true),
      ];
      expect(calc.calculate(quit(), logs, today).current, 13);
    });

    test('slips before start or in the future are ignored', () {
      final logs = [log(DateTime(2026, 5, 20)), log(day(2)), log(june(14))];
      final s = calc.calculate(quit(), logs, today);
      expect(s, const HabitStreak(current: 13, best: 13));
    });

    test('frequency is ignored for quit habits', () {
      final h = habit(
        kind: HabitKind.quit,
        start: june(1),
        frequency: const HabitFrequency.timesPerWeek(2),
      );
      expect(
        calc.calculate(h, const [], today),
        const HabitStreak(current: 13, best: 13),
      );
    });
  });

  test('3 years of daily logs compute fast', () {
    final start = DateTime(2023, 6, 13);
    final logs = [
      for (var i = 0; i < 1097; i++)
        if (i % 100 != 50) log(DateTime(2023, 6, 13 + i), count: 2),
    ]..shuffle();
    final h = habit(start: start, target: 2);
    final quitHabit = habit(kind: HabitKind.quit, start: start);
    final sw = Stopwatch()..start();
    final s = calc.calculate(h, logs, today);
    final q = calc.calculate(quitHabit, logs, today);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(200));
    expect(s.best, greaterThanOrEqualTo(s.current));
    expect(s.best, 99);
    expect(q.current, 0);
  });
}
