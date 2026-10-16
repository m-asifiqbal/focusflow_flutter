// Unit tests for HabitStatsCalculator: completion rate (in-progress today,
// skips, schedules, N× per week, quit habits), total check-ins, monthly
// completion, heatmap values and the bundled HabitStats.
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';
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
}) => Habit(
  id: 'h1',
  name: 'Test habit',
  kind: kind,
  targetCount: target,
  frequency: frequency,
  startDate: start ?? DateTime(2026, 1, 1),
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

const calc = HabitStatsCalculator();

void main() {
  group('completionRate', () {
    // Window: 15 May – 13 June. Days −29…−21 missed, −20…−1 done.
    final missedNine = doneRange(-20, -1);

    test('today not done does not lower the rate', () {
      expect(
        calc.completionRate(habit(), missedNine, today),
        closeTo(20 / 29, 1e-9),
      );
    });

    test('today done joins numerator and denominator', () {
      final logs = [...missedNine, log(today)];
      expect(calc.completionRate(habit(), logs, today), closeTo(21 / 30, 1e-9));
    });

    test('skipped days leave the denominator', () {
      final logs = [
        ...missedNine,
        log(day(-29), skipped: true),
        log(day(-28), count: 1, skipped: true),
      ];
      expect(calc.completionRate(habit(), logs, today), closeTo(20 / 27, 1e-9));
    });

    test('window clipped to the start date', () {
      final h = habit(start: june(4));
      final logs = [for (var d = 4; d <= 8; d++) log(june(d))];
      expect(calc.completionRate(h, logs, today), closeTo(5 / 9, 1e-9));
    });

    test('only scheduled days count (weekdays)', () {
      final h = habit(frequency: HabitFrequency.weekdays);
      // Window 31 May – 13 June: 10 weekdays.
      final logs = [
        for (final d in [1, 2, 3, 4, 5, 8, 9, 10]) log(june(d)),
        log(june(6)), // Saturday — ignored
      ];
      expect(calc.completionRate(h, logs, today, days: 14), closeTo(0.8, 1e-9));
    });

    test('times per week: done days / expected, capped at 1', () {
      final h = habit(frequency: const HabitFrequency.timesPerWeek(3));
      // 28-day window, today open → 27 days → round(3 × 27 / 7) = 12.
      expect(calc.completionRate(h, doneRange(-6, -1), today, days: 28), 0.5);
      expect(calc.completionRate(h, doneRange(-12, -1), today, days: 28), 1.0);
      expect(calc.completionRate(h, doneRange(-20, -1), today, days: 28), 1.0);
    });

    test('quit habit: clean days / days, today included', () {
      final h = habit(kind: HabitKind.quit);
      final logs = [log(day(-3)), log(day(-10), count: 2), log(day(-40))];
      expect(calc.completionRate(h, logs, today), closeTo(28 / 30, 1e-9));
      expect(
        calc.completionRate(h, [...logs, log(today)], today),
        closeTo(27 / 30, 1e-9),
      );
    });

    test('0 when there is nothing to measure', () {
      expect(calc.completionRate(habit(start: today), const [], today), 0);
      expect(
        calc.completionRate(habit(start: day(1)), doneRange(-3, 0), today),
        0,
      );
      expect(calc.completionRate(habit(), doneRange(-3, 0), today, days: 0), 0);
    });
  });

  group('totalCheckIns', () {
    test('build: days with a check-in up to today', () {
      final logs = [
        log(day(-1), count: 2),
        log(day(-2)),
        log(day(-3), count: 0),
        log(day(-4), skipped: true),
        log(today),
        log(day(1)), // future
      ];
      expect(calc.totalCheckIns(habit(), logs, today), 3);
    });

    test('quit: clean days from start to today', () {
      final h = habit(kind: HabitKind.quit, start: june(1));
      expect(calc.totalCheckIns(h, [log(june(4)), log(today)], today), 11);
    });
  });

  group('monthlyCompletion', () {
    final h = habit(start: DateTime(2026, 3, 15));
    final logs = [
      for (
        var d = DateTime(2026, 3, 15);
        d.isBefore(today);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        log(d),
    ];

    test('6 months, oldest first, current flagged', () {
      final months = calc.monthlyCompletion(h, logs, today);
      expect(months.map((m) => m.month), [
        for (var m = 1; m <= 6; m++) DateTime(2026, m),
      ]);
      expect(months.map((m) => m.rate), [0, 0, 1, 1, 1, 1]);
      expect(months.map((m) => m.isCurrent), [
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
    });

    test('rate per month uses the completion rules', () {
      final partial = logs
          .where((l) => !(l.date.month == 4 && l.date.day <= 15))
          .toList();
      final months = calc.monthlyCompletion(h, partial, today);
      expect(
        months[3],
        MonthlyCompletion(
          month: DateTime(2026, 4),
          rate: 0.5,
          isCurrent: false,
        ),
      );
    });

    test('crosses the year boundary', () {
      final months = calc.monthlyCompletion(
        h,
        logs,
        DateTime(2026, 2, 10),
        months: 3,
      );
      expect(months.map((m) => m.month), [
        DateTime(2025, 12),
        DateTime(2026, 1),
        DateTime(2026, 2),
      ]);
      expect(months.last.isCurrent, isTrue);
    });
  });

  group('heatmap', () {
    test(
      'build habit: partial, capped, skipped, clipped to start and today',
      () {
        final h = habit(target: 8, start: june(5));
        final logs = [
          log(june(3), count: 8), // before start
          log(june(10), count: 6),
          log(june(11), count: 10),
          log(june(12), count: 4, skipped: true),
          log(june(14), count: 8), // future
        ];
        final map = calc.heatmap(
          h,
          logs,
          from: june(1),
          to: june(20),
          today: today,
        );
        expect(map.keys, [
          for (var d = 5; d <= 13; d++)
            '2026-06-${d.toString().padLeft(2, '0')}',
        ]);
        expect(map['2026-06-10'], 0.75);
        expect(map['2026-06-11'], 1.0);
        expect(map['2026-06-12'], 0.0);
        expect(map['2026-06-09'], 0.0);
        expect(map.containsKey('2026-06-03'), isFalse);
        expect(map.containsKey('2026-06-14'), isFalse);
      },
    );

    test('quit habit: 1 clean / 0 slip', () {
      final h = habit(kind: HabitKind.quit, start: june(10));
      final map = calc.heatmap(
        h,
        [log(june(11), count: 2)],
        from: june(1),
        to: today,
        today: today,
      );
      expect(map, {
        '2026-06-10': 1.0,
        '2026-06-11': 0.0,
        '2026-06-12': 1.0,
        '2026-06-13': 1.0,
      });
    });
  });

  group('compute', () {
    test('bundles every stat for the detail screen', () {
      final h = habit(target: 2, start: DateTime(2025, 1, 1));
      final logs = [...doneRange(-400, -1, count: 2), log(today, count: 1)];
      final stats = calc.compute(h, logs, today);
      expect(stats.streak, const HabitStreak(current: 400, best: 400));
      expect(stats.completionRate, 1.0);
      expect(stats.completionDays, 30);
      expect(stats.totalCheckIns, 401);
      expect(stats.monthly, hasLength(6));
      expect(stats.monthly.last.isCurrent, isTrue);
      expect(stats.heatmap, hasLength(365));
      expect(stats.heatmap.keys.first, '2025-06-14');
      expect(stats.heatmap.keys.last, '2026-06-13');
      expect(stats.todayLog, logs.last);
      expect(stats.todayProgress, 0.5);
      expect(calc.todayProgress(h, logs.last), 0.5);
      expect(calc.compute(h, logs, today), stats);
      expect(calc.compute(h, logs, today).hashCode, stats.hashCode);
    });

    test('young habit: heatmap starts at the start date', () {
      final stats = calc.compute(
        habit(start: june(1)),
        doneRange(-3, -1),
        today,
      );
      expect(stats.heatmap, hasLength(13));
      expect(stats.todayLog, isNull);
      expect(stats.todayProgress, 0);
      expect(stats.streak.current, 3);
    });

    test('empty stats', () {
      expect(HabitStats.empty.streak, HabitStreak.zero);
      expect(HabitStats.empty.heatmap, isEmpty);
      expect(HabitStats.empty.monthly, isEmpty);
    });

    test('3 years of daily logs compute fast', () {
      final h = habit(start: DateTime(2023, 6, 13), target: 3);
      final logs = [
        for (var i = 0; i < 1097; i++)
          log(DateTime(2023, 6, 13 + i), count: i % 4),
      ];
      final sw = Stopwatch()..start();
      final stats = calc.compute(h, logs, today, months: 12);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(200));
      expect(stats.heatmap, hasLength(365));
      expect(stats.monthly, hasLength(12));
    });
  });
}
