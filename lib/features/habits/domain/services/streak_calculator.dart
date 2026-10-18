/// ============================================================
/// STREAK CALCULATOR — current and best streak of one habit
/// ============================================================
///
/// Pure, O(days) streak computation for the habit cards (🔥 12 days), the
/// detail screen and Insights. Rules (the pause is ignored for history):
///   • Build habit, day-based schedule (every day / specific days / every
///     N days): walk the *scheduled* days. Done → +1; skipped → neutral;
///     not done → breaks, except today (the day is still in progress).
///     Unscheduled days are ignored entirely, even when they have a log.
///   • Build habit, N× per week: counted in weeks. A week is met when
///     done + skipped days ≥ N (the habit's first, partial week needs
///     `min(N, days from startDate to week end)`). The current week never
///     breaks the streak while it is not met yet.
///   • Quit habit: clean days since the last slip (or since the start
///     date), today included. A skipped day is clean.
/// Logs outside [startDate, today] are ignored; logs may be in any order.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';

/// What a [HabitStreak] counts: consecutive days, or consecutive met weeks
/// (N× per week habits).
enum StreakUnit { days, weeks }

/// Current and best streak of a habit.
@immutable
class HabitStreak {
  const HabitStreak({
    required this.current,
    required this.best,
    this.unit = StreakUnit.days,
    this.lastSlip,
  });

  /// Length of the streak that is still alive (ends today / this week).
  final int current;

  /// Longest streak over the whole history (≥ [current]).
  final int best;
  final StreakUnit unit;

  /// Quit habits: the last day with a slip (local midnight); null when the
  /// habit never slipped (and always null for build habits).
  final DateTime? lastSlip;

  /// No streak yet.
  static const zero = HabitStreak(current: 0, best: 0);

  /// "12 days", "1 day", "3 weeks", "1 week".
  String get label => '$current ${unitWord(current)}';

  /// "31 days" / "4 weeks" — the best streak with its unit.
  String get bestLabel => '$best ${unitWord(best)}';

  /// The unit for a count of [n]: "day" / "days" / "week" / "weeks".
  String unitWord(int n) {
    final word = unit == StreakUnit.weeks ? 'week' : 'day';
    return n == 1 ? word : '${word}s';
  }

  @override
  bool operator ==(Object other) =>
      other is HabitStreak &&
      other.current == current &&
      other.best == best &&
      other.unit == unit &&
      other.lastSlip == lastSlip;

  @override
  int get hashCode => Object.hash(current, best, unit, lastSlip);

  @override
  String toString() =>
      'HabitStreak(current: $current, best: $best, ${unit.name}'
      '${lastSlip == null ? '' : ', lastSlip: ${DateUtilsX.dayKey(lastSlip!)}'})';
}

/// Computes [HabitStreak]s. [weekStartsOn] (`DateTime.monday … sunday`,
/// from settings) defines the weeks of N× per week habits.
class StreakCalculator {
  const StreakCalculator({this.weekStartsOn = DateTime.monday});

  /// First day of the week (`DateTime.monday … DateTime.sunday`).
  final int weekStartsOn;

  /// Streak of [habit] as of [today] from the habit's [logs] (any order).
  HabitStreak calculate(Habit habit, Iterable<HabitLog> logs, DateTime today) =>
      calculateIndexed(habit, HabitSchedule.indexByDay(logs), today);

  /// Same as [calculate] for logs already indexed with
  /// [HabitSchedule.indexByDay] (lets callers that need several stats index
  /// the history once).
  ///
  /// The walk over the history is pure integer work: logs are placed in a
  /// list by their day offset from the start date once, and every rule
  /// ([HabitSchedule.isDueByNumber], weeks, slips) reads that list. The
  /// first version built a local `DateTime` and a `yyyy-MM-dd` string for
  /// every day since the start date — per habit, on every refresh of every
  /// screen that shows a habit — which is what made a long-lived habit list
  /// slow on every launch. Results are identical (see the reference
  /// implementation in test/features/habits/domain).
  HabitStreak calculateIndexed(
    Habit habit,
    Map<String, HabitLog> logsByDay,
    DateTime today,
  ) {
    final start = DateUtilsX.dateOnly(habit.startDate);
    final startNo = DateUtilsX.dayNumber(start);
    final span = DateUtilsX.dayNumber(today) - startNo;
    final frequency = habit.frequency;
    final weekly = !habit.isQuit && frequency is TimesPerWeekFrequency;
    if (span < 0) {
      return weekly
          ? const HabitStreak(current: 0, best: 0, unit: StreakUnit.weeks)
          : HabitStreak.zero;
    }
    final days = _byOffset(logsByDay, startNo, span);
    if (habit.isQuit) return _quit(habit, days, start, span);
    if (frequency is TimesPerWeekFrequency) {
      return _weekly(habit, days, startNo, span, frequency.times);
    }
    return _daily(habit, days, startNo, span);
  }

  /// [logsByDay] as a list indexed by days since the start date (0…[span]);
  /// logs outside that range (before the start, after today) are dropped.
  static List<HabitLog?> _byOffset(
    Map<String, HabitLog> logsByDay,
    int startNo,
    int span,
  ) {
    final days = List<HabitLog?>.filled(span + 1, null);
    for (final e in logsByDay.entries) {
      final int offset;
      try {
        offset = DateUtilsX.dayNumberOfKey(e.key) - startNo;
      } on FormatException {
        continue; // not a day key: nothing can look it up
      }
      if (offset >= 0 && offset <= span) days[offset] = e.value;
    }
    return days;
  }

  /// Day-based build habits: one forward pass over the scheduled days. The
  /// run left at the end is the current streak (today never breaks it).
  HabitStreak _daily(Habit habit, List<HabitLog?> days, int startNo, int span) {
    var run = 0;
    var best = 0;
    for (var i = 0; i <= span; i++) {
      if (!HabitSchedule.isDueByNumber(habit, startNo + i, i)) continue;
      final log = days[i];
      if (HabitSchedule.isDone(habit, log)) {
        run++;
        if (run > best) best = run;
      } else if ((log?.skipped ?? false) || i == span) {
        // Skipped days and the in-progress day (the last) neither add nor
        // break.
      } else {
        run = 0;
      }
    }
    return HabitStreak(current: run, best: best);
  }

  /// N× per week build habits, counted in met weeks. Works on integer day
  /// offsets from the start date, so no DateTime comparisons are needed.
  HabitStreak _weekly(
    Habit habit,
    List<HabitLog?> days,
    int startNo,
    int span,
    int times,
  ) {
    final perWeek = times.clamp(1, 7);
    // Days between the first week's start and the habit's start date.
    final lead =
        (HabitSchedule.weekdayOfNumber(startNo) - weekStartsOn + 7) % 7;
    final lastWeek = (span + lead) ~/ 7;
    var run = 0;
    var best = 0;
    for (var week = 0; week <= lastWeek; week++) {
      final weekFirst = week * 7 - lead;
      final from = weekFirst < 0 ? 0 : weekFirst;
      final to = weekFirst + 6 > span ? span : weekFirst + 6;
      var credited = 0;
      for (var i = from; i <= to; i++) {
        final log = days[i];
        if (HabitSchedule.isDone(habit, log) || (log?.skipped ?? false)) {
          credited++;
        }
      }
      // The first week may start mid-week: only the days from the start
      // date to the week's end can count.
      final available = weekFirst + 7 - from;
      final required = perWeek < available ? perWeek : available;
      if (credited >= required) {
        run++;
        if (run > best) best = run;
      } else if (week != lastWeek) {
        run = 0;
      }
    }
    return HabitStreak(current: run, best: best, unit: StreakUnit.weeks);
  }

  /// Quit habits: clean runs between slips, today included.
  HabitStreak _quit(
    Habit habit,
    List<HabitLog?> days,
    DateTime start,
    int span,
  ) {
    var run = 0;
    var best = 0;
    int? lastSlip; // offset from the start date
    for (var i = 0; i <= span; i++) {
      if (HabitSchedule.isSlip(habit, days[i])) {
        run = 0;
        lastSlip = i;
      } else {
        run++;
        if (run > best) best = run;
      }
    }
    return HabitStreak(
      current: run,
      best: best,
      lastSlip: lastSlip == null
          ? null
          : DateTime(start.year, start.month, start.day + lastSlip),
    );
  }
}
