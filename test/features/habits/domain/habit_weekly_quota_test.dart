// N× per week habits stop being due once the week's quota is met
// (HabitSchedule.isDueOn): the card is a rest day ("Week goal met"), the
// day summary leaves it out (so it can't block the perfect day), the week
// squares mark the remaining days as rest days, and the streak is labelled
// in weeks. Also: stats rest days + total check-ins clipped to the start.
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_day_status_builder.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';
import 'package:focusflow/features/habits/domain/services/habits_day_summary.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

/// 2026-06-[d]. 8 June 2026 is a Monday.
DateTime june(int d) => DateTime(2026, 6, d);

Habit habit({
  String id = 'h1',
  HabitKind kind = HabitKind.build,
  HabitFrequency frequency = const HabitFrequency.timesPerWeek(3),
  DateTime? start,
}) => Habit(
  id: id,
  name: 'Habit $id',
  kind: kind,
  frequency: frequency,
  startDate: start ?? DateTime(2026, 1, 1),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

HabitLog log(
  DateTime date, {
  String habitId = 'h1',
  int count = 1,
  bool skipped = false,
}) => HabitLog(
  id: 'l$habitId$date',
  habitId: habitId,
  date: date,
  count: count,
  skipped: skipped,
  createdAt: date,
  updatedAt: date,
);

void main() {
  final weekly = habit();
  // Mon, Tue, Wed done → quota of 3 met before Thursday.
  final met = [log(june(8)), log(june(9)), log(june(10))];

  group('HabitSchedule.isDueOn', () {
    Map<String, HabitLog> idx(List<HabitLog> l) => HabitSchedule.indexByDay(l);

    test('due until the quota is met by earlier days of the week', () {
      expect(HabitSchedule.isDueOn(weekly, june(10), idx(met)), isTrue);
      expect(HabitSchedule.isDueOn(weekly, june(11), idx(met)), isFalse);
      expect(HabitSchedule.isDueOn(weekly, june(14), idx(met)), isFalse);
      // A new week starts on Monday 15 June.
      expect(HabitSchedule.isDueOn(weekly, june(15), idx(met)), isTrue);
    });

    test('a skipped day counts towards the quota, a partial week not', () {
      final two = [log(june(8)), log(june(9), skipped: true)];
      expect(HabitSchedule.isDueOn(weekly, june(10), idx(two)), isTrue);
      expect(
        HabitSchedule.isDueOn(weekly, june(11), idx([...two, log(june(10))])),
        isFalse,
      );
    });

    test('the week start comes from settings', () {
      // Weeks start on Sunday: Sun 7 + Mon 8 + Tue 9 done → Wed is rest.
      final logs = idx([log(june(7)), log(june(8)), log(june(9))]);
      expect(
        HabitSchedule.isDueOn(
          weekly,
          june(10),
          logs,
          weekStartsOn: DateTime.sunday,
        ),
        isFalse,
      );
      expect(HabitSchedule.isDueOn(weekly, june(10), logs), isTrue);
    });

    test('first partial week: only days from the start date count', () {
      // Starts Thursday 11 June; Thu, Fri, Sat done.
      final logs = idx([log(june(11)), log(june(12)), log(june(13))]);
      final three = habit(start: june(11));
      expect(HabitSchedule.isDueOn(three, june(14), logs), isFalse);
      // 5× per week can't be met in 4 days: Sunday stays due.
      final five = habit(
        start: june(11),
        frequency: const HabitFrequency.timesPerWeek(5),
      );
      expect(HabitSchedule.isDueOn(five, june(14), logs), isTrue);
      // A log before the start date never counts.
      final early = idx([log(june(8)), log(june(9)), log(june(10))]);
      expect(HabitSchedule.isDueOn(three, june(11), early), isTrue);
    });

    test('other schedules and quit habits are unaffected', () {
      final daily = habit(frequency: const HabitFrequency.everyDay());
      expect(HabitSchedule.isDueOn(daily, june(11), idx(met)), isTrue);
      final quit = habit(kind: HabitKind.quit);
      expect(HabitSchedule.isDueOn(quit, june(11), idx(met)), isTrue);
    });
  });

  group('card + day summary', () {
    final status = HabitDayStatusBuilder.build(weekly, met, june(11));

    test('quota met: rest day "Week goal met", still loggable', () {
      expect(status.isScheduled, isFalse);
      expect(status.isWeekGoalMet, isTrue);
      expect(status.progressLabel, 'Week goal met');
      // A bonus check-in still shows as done on the card.
      final bonus = HabitDayStatusBuilder.build(weekly, [
        ...met,
        log(june(11)),
      ], june(11));
      expect(bonus.isDone, isTrue);
      expect(bonus.progressLabel, 'Completed');
    });

    test('the quota-met habit neither counts as due nor blocks perfect', () {
      final daily = habit(id: 'h2', frequency: const HabitFrequency.everyDay());
      final dailyDone = HabitDayStatusBuilder.build(daily, [
        log(june(11), habitId: 'h2'),
      ], june(11));
      final summary = HabitsDaySummary.of([status, dailyDone]);
      expect(summary.due, 1);
      expect(summary.done, 1);
      expect(summary.isPerfect, isTrue);
    });

    test('quota not met yet: due and pending', () {
      final s = HabitDayStatusBuilder.build(weekly, met.take(2), june(11));
      expect(s.isScheduled, isTrue);
      expect(HabitsDaySummary.of([s]).due, 1);
      expect(HabitsDaySummary.of([s]).isPerfect, isFalse);
    });

    test('week cells after the quota are rest days', () {
      expect(status.week.map((c) => c.isScheduled), [
        true, true, true, false, false, false, false, //
      ]);
    });

    test('streak counts weeks and labels them', () {
      expect(status.streak.unit, StreakUnit.weeks);
      expect(status.streak.label, '1 week');
      const s = HabitStreak(current: 3, best: 5, unit: StreakUnit.weeks);
      expect(s.label, '3 weeks');
      expect(s.bestLabel, '5 weeks');
      expect(s.unitWord(1), 'week');
      expect(const HabitStreak(current: 1, best: 2).bestLabel, '2 days');
    });
  });

  group('stats', () {
    const calc = HabitStatsCalculator();

    test('total check-ins ignore logs before the start date', () {
      final h = habit(
        frequency: const HabitFrequency.everyDay(),
        start: june(10),
      );
      final logs = [log(june(5)), log(june(9)), log(june(10)), log(june(11))];
      expect(calc.totalCheckIns(h, logs, june(11)), 2);
      expect(calc.compute(h, logs, june(11)).totalCheckIns, 2);
    });

    test('heatmap rest days: off days of a specific-days habit', () {
      final h = habit(frequency: HabitFrequency.weekdays, start: june(1));
      final stats = calc.compute(h, [log(june(6))], june(14));
      // Weekends of 6/7 and 13/14 June; a bonus log keeps its value.
      expect(stats.restDays, {
        '2026-06-06',
        '2026-06-07',
        '2026-06-13',
        '2026-06-14',
      });
      expect(stats.heatmap['2026-06-06'], 1.0);
      expect(stats.heatmap['2026-06-08'], 0.0); // a miss, not a rest day
    });

    test('heatmap rest days: weekly quota met, quit habits have none', () {
      final stats = calc.compute(weekly, met, june(14));
      expect(stats.restDays, containsAll(['2026-06-11', '2026-06-14']));
      expect(stats.restDays.contains('2026-06-10'), isFalse);
      final quit = habit(kind: HabitKind.quit, start: june(1));
      expect(calc.compute(quit, const [], june(14)).restDays, isEmpty);
    });
  });
}
