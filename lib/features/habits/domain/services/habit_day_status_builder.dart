/// ============================================================
/// HABIT DAY STATUS BUILDER — one habit card's model for one day
/// ============================================================
///
/// Turns a habit and its logs into a [HabitDayStatus]: the day's log, ring
/// progress, done/scheduled flags, the streak as of that day and the seven
/// weekday squares of the card footer.
///
/// Why pure: Home and the Habits list stream these for every habit; keeping
/// the assembly out of the repository and widgets makes it unit-testable
/// and guarantees the card, the streak and the stats use the same rules
/// ([HabitSchedule], [StreakCalculator]).
///
/// The reference [day] is treated as "today": week cells after it are
/// future cells (empty, never done).
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

abstract final class HabitDayStatusBuilder {
  /// Builds the card model of [habit] for [day] (assumed ≤ today).
  ///
  /// * `log` — the log of [day]; `progress` / `isDone` from that log
  ///   ([HabitSchedule.progress] / [HabitSchedule.isDone], i.e.
  ///   `Habit.progressWith` / `Habit.isDoneWith`); a day before the start
  ///   date is never done and has no progress;
  /// * `isScheduled` — [HabitSchedule.isScheduledOn] (respects the pause);
  /// * `streak` — [StreakCalculator] as of [day];
  /// * `week` — the 7 days of the week containing [day] (starting on
  ///   [weekStartsOn]); cells after [day] are future (not done, progress 0),
  ///   cells before the start date are not done and not scheduled; cell
  ///   scheduling ([HabitSchedule.isDueOn]) ignores the pause (history view).
  static HabitDayStatus build(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime day, {
    int weekStartsOn = DateTime.monday,
  }) {
    final ref = DateUtilsX.dateOnly(day);
    final byDay = HabitSchedule.indexByDay(logs);
    final log = byDay[DateUtilsX.dayKey(ref)];
    final started = HabitSchedule.daysBetween(habit.startDate, ref) >= 0;
    return HabitDayStatus(
      habit: habit,
      day: ref,
      log: log,
      progress: started ? HabitSchedule.progress(habit, log) : 0,
      isDone: started && HabitSchedule.isDone(habit, log),
      isScheduled: HabitSchedule.isDueOn(
        habit,
        ref,
        byDay,
        weekStartsOn: weekStartsOn,
      ),
      streak: StreakCalculator(
        weekStartsOn: weekStartsOn,
      ).calculateIndexed(habit, byDay, ref),
      week: [
        for (final cellDay in DateUtilsX.weekDays(ref, weekStartsOn))
          _cell(habit, byDay, cellDay, ref, weekStartsOn),
      ],
    );
  }

  /// One weekday square relative to the reference day [ref].
  static HabitDayCell _cell(
    Habit habit,
    Map<String, HabitLog> byDay,
    DateTime cellDay,
    DateTime ref,
    int weekStartsOn,
  ) {
    final log = byDay[DateUtilsX.dayKey(cellDay)];
    final isFuture = HabitSchedule.daysBetween(ref, cellDay) > 0;
    final started = HabitSchedule.daysBetween(habit.startDate, cellDay) >= 0;
    final counts = started && !isFuture;
    return HabitDayCell(
      day: cellDay,
      isDone: counts && HabitSchedule.isDone(habit, log),
      isScheduled: HabitSchedule.isDueOn(
        habit,
        cellDay,
        byDay,
        weekStartsOn: weekStartsOn,
        ignorePause: true,
      ),
      isSkipped: log?.skipped ?? false,
      isFuture: isFuture,
      progress: counts ? HabitSchedule.progress(habit, log) : 0,
    );
  }
}
