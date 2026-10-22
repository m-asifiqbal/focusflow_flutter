/// InsightsAggregator — every number reconciles with the raw data it was
/// computed from: KPIs + deltas, window boundaries, DST-safe day buckets,
/// series / split totals, habit consistency vs HabitStatsCalculator,
/// streak rows and the empty state.
library;

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/domain/services/insights_aggregator.dart';

import 'insights_fixtures.dart';

void main() {
  const agg = InsightsAggregator();
  // Thursday 15 Oct 2026, 18:00.
  final now = DateTime(2026, 10, 15, 18);
  final today = DateUtilsX.dateOnly(now);
  final week = InsightsRange.initial.resolve(now); // Oct 9 … Oct 15
  DateTime day(int d, [int h = 0, int m = 0]) => DateTime(2026, 10, d, h, m);

  InsightsSnapshot run(InsightsSources s, [InsightsWindow? w]) =>
      agg.compute(s, w ?? week, now);

  group('empty data', () {
    test('no data → zeros, no rates, generic tip, no chart data', () {
      final s = run(const InsightsSources());
      expect(s.taskCompletion.current, RatioMetric.zero);
      expect(s.taskCompletion.current.rate, isNull);
      expect(s.habitConsistency.current.rate, isNull);
      expect(s.focusMinutes, const Kpi(current: 0, previous: 0));
      expect(s.notesCreated, const Kpi(current: 0, previous: 0));
      expect(s.series, hasLength(7));
      expect(s.series.every((p) => p.score == 0), isTrue);
      expect(s.hasSeriesData, isFalse);
      expect(s.hasSplitData, isFalse);
      expect(s.split.percents, [0, 0, 0, 0]);
      expect(s.streaks, isEmpty);
      expect(s.hasHabits, isFalse);
      expect(s.tip.isPersonal, isFalse);
    });

    test('Today range has a single point → never enough for a trend', () {
      final w = const InsightsRange.preset(InsightsPreset.today).resolve(now);
      final s = run(
        InsightsSources(tasksCompleted: [task(completedAt: now)]),
        w,
      );
      expect(s.series, hasLength(1));
      expect(s.hasSeriesData, isFalse);
      expect(s.split.tasks, 1);
    });
  });

  group('task completion', () {
    test('completed / due in the window, delta against previous', () {
      final s = run(
        InsightsSources(
          tasksDue: [
            task(due: day(9), completedAt: day(9, 10)),
            task(due: day(12), completedAt: day(13, 8)),
            task(due: day(15)),
            task(due: day(14), archivedAt: day(14)), // not active
            task(due: day(3), completedAt: day(3)), // previous window
            task(due: day(4)), // previous window
            task(), // no due date
          ],
        ),
      );
      expect(s.taskCompletion.current, const RatioMetric(done: 2, total: 3));
      expect(s.taskCompletion.previous, const RatioMetric(done: 1, total: 2));
    });

    test('window boundaries: start inclusive, end exclusive', () {
      final s = run(
        InsightsSources(
          tasksCompleted: [
            task(completedAt: week.start), // first instant → in
            task(completedAt: week.end.subtract(const Duration(seconds: 1))),
            task(completedAt: week.end), // tomorrow 00:00 → out
            task(completedAt: week.start.subtract(const Duration(seconds: 1))),
          ],
        ),
      );
      expect(s.split.tasks, 2);
      expect(s.series.first.tasks, 1);
      expect(s.series.last.tasks, 1);
    });
  });

  group('focus, notes, reminders', () {
    test('sum per window, deltas', () {
      final s = run(
        InsightsSources(
          focusSessions: [
            session(day(10, 9), 25),
            session(day(15, 7), 50),
            session(day(5, 9), 45), // previous
            session(day(16, 0), 60), // after window
          ],
          notesCreated: [day(9), day(11, 12), day(15, 23, 59), day(2)],
          reminders: [
            occurrence(day(12)),
            occurrence(day(13), done: false),
            occurrence(day(1)),
          ],
        ),
      );
      expect(s.focusMinutes, const Kpi(current: 75, previous: 45));
      expect(s.notesCreated, const Kpi(current: 3, previous: 1));
      expect(s.split.reminders, 1);
      expect(s.split.notes, 3);
    });
  });

  group('habits', () {
    test('check-ins: build habits only, not skipped, active only', () {
      final build = habit(name: 'Read');
      final quit = habit(name: 'No sugar', kind: HabitKind.quit);
      final archived = habit(archivedAt: day(1));
      final s = run(
        InsightsSources(
          habits: [build, quit], // archived habits never come from the repo
          habitLogs: [
            log(build, day(10)),
            log(build, day(11), skipped: true),
            log(build, day(12), count: 0),
            log(quit, day(12)), // a slip, not a check-in
            log(archived, day(13)),
          ],
        ),
      );
      expect(s.split.habits, 1);
      expect(s.series[1].habits, 1); // Oct 10
    });

    test('daily habit consistency equals HabitStatsCalculator', () {
      final h = habit(start: day(1));
      final logs = [
        log(h, day(9)),
        log(h, day(10)),
        log(h, day(11), skipped: true),
        log(h, day(13)),
        // Oct 12 and 14 missed; today (15) not done yet → not counted.
      ];
      final s = run(InsightsSources(habits: [h], habitLogs: logs));
      expect(s.habitConsistency.current, const RatioMetric(done: 3, total: 5));
      final expected = const HabitStatsCalculator().completionRate(
        h,
        logs,
        today,
        days: 7,
      );
      expect(s.habitConsistency.current.rate, closeTo(expected, 1e-9));
    });

    test('previous window, start date clip, paused and quit habits', () {
      final newer = habit(start: day(13)); // only 13–15 count
      final paused = habit(start: day(1), paused: true);
      final quit = habit(start: day(1), kind: HabitKind.quit);
      final s = run(
        InsightsSources(
          habits: [newer, paused, quit],
          habitLogs: [
            log(newer, day(13)),
            log(newer, day(15)),
            log(quit, day(10)), // one slip in 7 days
            log(quit, day(4)), // previous window slip
          ],
        ),
      );
      // newer: 13 ✓, 14 ✗, 15 ✓ (today, done) → 2/3; quit: 6/7.
      expect(s.habitConsistency.current, const RatioMetric(done: 8, total: 10));
      // previous window Oct 2–8: newer not started; quit 6 clean of 7.
      expect(s.habitConsistency.previous, const RatioMetric(done: 6, total: 7));
    });

    test('N× per week habits are measured against expected days', () {
      final h = habit(
        start: day(1),
        frequency: const HabitFrequency.timesPerWeek(3),
      );
      final s = run(
        InsightsSources(
          habits: [h],
          habitLogs: [log(h, day(9)), log(h, day(10)), log(h, day(12))],
        ),
      );
      // 6 measured days (today pending) → expected round(3×6/7) = 3.
      expect(s.habitConsistency.current, const RatioMetric(done: 3, total: 3));
    });

    test('streak rows: longest first, weeks weigh 7 days, all habits', () {
      final a = habit(name: 'Reading');
      final b = habit(name: 'Gym');
      final c = habit(name: 'Hydration');
      final d = habit(name: 'Stretch');
      final s = run(
        InsightsSources(
          habits: [a, b, c, d],
          habitStatuses: [
            status(a, const HabitStreak(current: 12, best: 20), today),
            status(
              b,
              const HabitStreak(current: 3, best: 3, unit: StreakUnit.weeks),
              today,
            ),
            status(c, const HabitStreak(current: 42, best: 42), today),
            status(d, const HabitStreak(current: 1, best: 9), today),
          ],
        ),
      );
      expect(s.streaks.map((r) => r.name), [
        'Hydration',
        'Gym',
        'Reading',
        'Stretch',
      ]);
      expect(s.streaks[0].progress, 1);
      expect(s.streaks[1].progress, closeTo(21 / 42, 1e-9));
      expect(s.streaks[1].streak.unit, StreakUnit.weeks);
      expect(s.streaks[2].progress, closeTo(12 / 42, 1e-9));
      expect(s.streaks[3].progress, closeTo(1 / 42, 1e-9));
    });
  });

  group('series and split reconcile', () {
    test('7-day series sums equal the split', () {
      final h = habit(start: day(1));
      final s = run(
        InsightsSources(
          habits: [h],
          tasksCompleted: [
            task(completedAt: day(9, 9)),
            task(completedAt: day(12, 14)),
            task(completedAt: day(12, 15)),
            task(completedAt: day(15, 8)),
          ],
          habitLogs: [log(h, day(9)), log(h, day(12)), log(h, day(14))],
        ),
      );
      expect(s.series.map((p) => p.tasks).sum, s.split.tasks);
      expect(s.series.map((p) => p.habits).sum, s.split.habits);
      expect(s.series[3].score, 3); // Oct 12: 2 tasks + 1 check-in
      expect(s.series.map((p) => p.start), week.dayList);
      expect(s.hasSeriesData, isTrue);
    });

    test('90 days are bucketed per week; totals still reconcile', () {
      final w = const InsightsRange.preset(InsightsPreset.quarter).resolve(now);
      final completions = [
        for (var i = 0; i < 90; i += 3)
          task(
            completedAt: DateUtilsX.addDays(
              w.start,
              i,
            ).add(const Duration(hours: 10)),
          ),
      ];
      final s = run(InsightsSources(tasksCompleted: completions), w);
      expect(s.series, hasLength(13));
      expect(s.series.map((p) => p.days).sum, 90);
      expect(s.series.last.days, 6);
      expect(s.series.map((p) => p.tasks).sum, 30);
      expect(s.split.tasks, 30);
    });

    test('percentages add up to 100', () {
      final s = run(
        InsightsSources(
          tasksCompleted: [
            for (var i = 0; i < 1; i++) task(completedAt: day(10)),
          ],
          notesCreated: [day(10), day(11)],
          reminders: [
            occurrence(day(11)),
            occurrence(day(12)),
            occurrence(day(13)),
          ],
        ),
      );
      expect(s.split.total, 6);
      expect(s.split.percents, [17, 0, 33, 50]);
      expect(s.split.percents.sum, 100);
      expect(const TimeSplit(tasks: 1, habits: 1, notes: 1).percents.sum, 100);
    });
  });

  group('DST-safe day bucketing', () {
    // Windows across the 2026 DST changes in Europe (Mar 29, Oct 25) and
    // the US (Mar 8, Nov 1). In a zone with DST, local midnights there are
    // 23 / 25 hours apart; bucketing must still be per calendar day.
    for (final (label, last) in [
      ('EU spring', DateTime(2026, 3, 31, 12)),
      ('EU autumn', DateTime(2026, 10, 27, 12)),
      ('US spring', DateTime(2026, 3, 10, 12)),
      ('US autumn', DateTime(2026, 11, 3, 12)),
    ]) {
      test(label, () {
        final w = InsightsRange.initial.resolve(last);
        expect(w.days, 7);
        expect(w.dayList.map(DateUtilsX.dayKey).toSet(), hasLength(7));
        final s = agg.compute(
          InsightsSources(
            tasksCompleted: [
              for (final d in w.dayList)
                task(completedAt: DateTime(d.year, d.month, d.day, 23, 30)),
            ],
          ),
          w,
          last,
        );
        expect(s.series.map((p) => p.tasks), List.filled(7, 1));
        expect(w.previous.days, 7);
        expect(w.previous.end, w.start);
      });
    }
  });
}
