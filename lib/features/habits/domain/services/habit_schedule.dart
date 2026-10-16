/// ============================================================
/// HABIT SCHEDULE — which days a habit is due, plus shared day rules
/// ============================================================
///
/// Pure calendar logic used by every habit service (StreakCalculator,
/// HabitStatsCalculator, HabitDayStatusBuilder) so they all agree on:
///   • when a habit is due ([isScheduledOn], [scheduledDaysBetween], and
///     [isDueOn], which also retires N× per week habits for the rest of a
///     week once its quota is met);
///   • what a single day "counts as" ([isDone], [isSlip], [progress]);
///   • how logs are looked up ([indexByDay]) and how far apart two calendar
///     days are ([daysBetween]).
///
/// Why a separate class: the schedule rules are needed by the streak, the
/// stats and the card builder; keeping them here avoids three slightly
/// different interpretations of "due" and "done".
///
/// All calendar math is DST-safe: days are built with `DateTime(y, m, d + i)`
/// and differences are measured on UTC dates, never by adding `Duration`s to
/// local times.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';

abstract final class HabitSchedule {
  /// Is [habit] due on [day]?
  ///
  /// * false before `habit.startDate`;
  /// * false while the habit is paused, unless [ignorePause] (history views
  ///   and streaks ignore the pause so pausing never rewrites the past);
  /// * every day → true; specific days → the weekday is in the mask;
  ///   N× per week → true (any day may count towards the week);
  ///   every N days → `(days since startDate) % n == 0` (n ≤ 1 → every day).
  ///
  /// Quit habits ignore their frequency: abstaining is due every day.
  static bool isScheduledOn(
    Habit habit,
    DateTime day, {
    bool ignorePause = false,
  }) {
    final offset = daysBetween(habit.startDate, day);
    if (offset < 0) return false;
    if (habit.isPaused && !ignorePause) return false;
    return _isDue(habit, DateUtilsX.dateOnly(day), offset);
  }

  /// Is [habit] actually due on [day], given its logs ([byDay], from
  /// [indexByDay])?
  ///
  /// Same as [isScheduledOn], except that an N× per week build habit stops
  /// being due once the week's quota is met by the days *before* [day]
  /// (done or skipped days count, as in the weekly streak; a first partial
  /// week needs `min(N, days from the start date to the week's end)`). Such
  /// a day is a rest day for "x of y done today", the perfect day and the
  /// week squares — it can still be logged as a bonus. [day]'s own log never
  /// changes whether [day] is due, so completing the quota today keeps
  /// today due (and done).
  static bool isDueOn(
    Habit habit,
    DateTime day,
    Map<String, HabitLog> byDay, {
    int weekStartsOn = DateTime.monday,
    bool ignorePause = false,
  }) {
    if (!isScheduledOn(habit, day, ignorePause: ignorePause)) return false;
    final f = habit.frequency;
    if (habit.isQuit || f is! TimesPerWeekFrequency) return true;
    final d = DateUtilsX.dateOnly(day);
    final lead = (d.weekday - weekStartsOn + 7) % 7;
    final weekFirst = DateTime(d.year, d.month, d.day - lead);
    final startOffset = daysBetween(weekFirst, habit.startDate);
    final available = startOffset > 0 ? 7 - startOffset : 7;
    final perWeek = f.times.clamp(1, 7);
    final required = perWeek < available ? perWeek : available;
    var credited = 0;
    for (var i = 1; i <= lead; i++) {
      final prev = DateTime(d.year, d.month, d.day - i);
      if (daysBetween(habit.startDate, prev) < 0) break;
      final log = byDay[DateUtilsX.dayKey(prev)];
      if (isDone(habit, log) || (log?.skipped ?? false)) credited++;
    }
    return credited < required;
  }

  /// Scheduled days in [from, to] (inclusive) as local midnights, ascending.
  ///
  /// Days before the habit's start date are never included. Unlike
  /// [isScheduledOn], the pause is ignored by default because this is used
  /// for history (streaks, completion rates).
  static List<DateTime> scheduledDaysBetween(
    Habit habit,
    DateTime from,
    DateTime to, {
    bool ignorePause = true,
  }) {
    if (habit.isPaused && !ignorePause) return <DateTime>[];
    final start = DateUtilsX.dateOnly(habit.startDate);
    final fromOffset = daysBetween(start, from);
    final firstOffset = fromOffset < 0 ? 0 : fromOffset;
    final lastOffset = daysBetween(start, to);
    final result = <DateTime>[];
    for (var i = firstOffset; i <= lastOffset; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (_isDue(habit, day, i)) result.add(day);
    }
    return result;
  }

  /// Whole calendar days from [from] to [to] (negative when [to] is
  /// earlier). Time of day is ignored; DST-safe.
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Logs keyed by their `yyyy-MM-dd` day (one log per habit and day; if the
  /// input has duplicates, the last one wins).
  static Map<String, HabitLog> indexByDay(Iterable<HabitLog> logs) => {
    for (final log in logs) log.dayKey: log,
  };

  /// Whether [log] records a slip of a quit habit: a positive count that is
  /// not marked as skipped. Always false for build habits.
  static bool isSlip(Habit habit, HabitLog? log) =>
      habit.isQuit && log != null && !log.skipped && log.count > 0;

  /// Whether the day of [log] counts as done for [habit].
  ///
  /// Build: `Habit.isDoneWith` (count ≥ target and not skipped).
  /// Quit: clean unless a slip is logged — a skipped quit day is clean, so
  /// skipping never breaks a streak (this is the one case where it differs
  /// from `Habit.isDoneWith`, which ignores `skipped` for quit habits).
  static bool isDone(Habit habit, HabitLog? log) =>
      habit.isQuit ? !isSlip(habit, log) : habit.isDoneWith(log);

  /// 0…1 progress of one day: `Habit.progressWith` for build habits
  /// (count / target, capped; skipped → 0); 1 clean / 0 slip for quit
  /// habits (consistent with [isDone]).
  static double progress(Habit habit, HabitLog? log) {
    if (habit.isQuit) return isSlip(habit, log) ? 0 : 1;
    return habit.progressWith(log);
  }

  /// Frequency rule for a day that is [offset] days after the start date.
  static bool _isDue(Habit habit, DateTime day, int offset) {
    if (habit.isQuit) return true;
    return switch (habit.frequency) {
      EveryDayFrequency() => true,
      final SpecificDaysFrequency f => f.includes(day.weekday),
      TimesPerWeekFrequency() => true,
      EveryNDaysFrequency(:final days) => days <= 1 || offset % days == 0,
    };
  }
}
