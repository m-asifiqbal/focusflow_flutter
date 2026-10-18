/// The streak rules written the plain way — one local `DateTime` and one
/// `yyyy-MM-dd` key per day of history — kept as the oracle for the
/// integer-based [StreakCalculator]: both must agree on every input.
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

class ReferenceStreakCalculator {
  const ReferenceStreakCalculator({this.weekStartsOn = DateTime.monday});

  final int weekStartsOn;

  HabitStreak calculate(Habit habit, Iterable<HabitLog> logs, DateTime today) {
    final logsByDay = HabitSchedule.indexByDay(logs);
    final start = DateUtilsX.dateOnly(habit.startDate);
    final end = DateUtilsX.dateOnly(today);
    final span = _daysBetween(start, end);
    final frequency = habit.frequency;
    final weekly = !habit.isQuit && frequency is TimesPerWeekFrequency;
    if (span < 0) {
      return weekly
          ? const HabitStreak(current: 0, best: 0, unit: StreakUnit.weeks)
          : HabitStreak.zero;
    }
    if (habit.isQuit) return _quit(habit, logsByDay, start, span);
    if (frequency is TimesPerWeekFrequency) {
      return _weekly(habit, logsByDay, start, span, frequency.times);
    }
    return _daily(habit, logsByDay, start, end);
  }

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Scheduled days in [from, to] the slow way (a `DateTime` per day).
  static List<DateTime> _scheduledDays(
    Habit habit,
    DateTime from,
    DateTime to,
  ) {
    final start = DateUtilsX.dateOnly(habit.startDate);
    final fromOffset = _daysBetween(start, from);
    final firstOffset = fromOffset < 0 ? 0 : fromOffset;
    final lastOffset = _daysBetween(start, to);
    final result = <DateTime>[];
    for (var i = firstOffset; i <= lastOffset; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (_isDue(habit, day, i)) result.add(day);
    }
    return result;
  }

  static bool _isDue(Habit habit, DateTime day, int offset) {
    if (habit.isQuit) return true;
    return switch (habit.frequency) {
      EveryDayFrequency() => true,
      final SpecificDaysFrequency f => f.includes(day.weekday),
      TimesPerWeekFrequency() => true,
      EveryNDaysFrequency(:final days) => days <= 1 || offset % days == 0,
    };
  }

  HabitStreak _daily(
    Habit habit,
    Map<String, HabitLog> logsByDay,
    DateTime start,
    DateTime end,
  ) {
    final days = _scheduledDays(habit, start, end);
    var run = 0;
    var best = 0;
    for (final day in days) {
      final log = logsByDay[DateUtilsX.dayKey(day)];
      if (HabitSchedule.isDone(habit, log)) {
        run++;
        if (run > best) best = run;
      } else if ((log?.skipped ?? false) || DateUtilsX.isSameDay(day, end)) {
        // Skipped days and the in-progress day neither add nor break.
      } else {
        run = 0;
      }
    }
    return HabitStreak(current: run, best: best);
  }

  HabitStreak _weekly(
    Habit habit,
    Map<String, HabitLog> logsByDay,
    DateTime start,
    int span,
    int times,
  ) {
    final perWeek = times.clamp(1, 7);
    final lead = (start.weekday - weekStartsOn + 7) % 7;
    final lastWeek = (span + lead) ~/ 7;
    var run = 0;
    var best = 0;
    for (var week = 0; week <= lastWeek; week++) {
      final weekFirst = week * 7 - lead;
      final from = weekFirst < 0 ? 0 : weekFirst;
      final to = weekFirst + 6 > span ? span : weekFirst + 6;
      var credited = 0;
      for (var i = from; i <= to; i++) {
        final day = DateTime(start.year, start.month, start.day + i);
        final log = logsByDay[DateUtilsX.dayKey(day)];
        if (HabitSchedule.isDone(habit, log) || (log?.skipped ?? false)) {
          credited++;
        }
      }
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

  HabitStreak _quit(
    Habit habit,
    Map<String, HabitLog> logsByDay,
    DateTime start,
    int span,
  ) {
    var run = 0;
    var best = 0;
    DateTime? lastSlip;
    for (var i = 0; i <= span; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (HabitSchedule.isSlip(habit, logsByDay[DateUtilsX.dayKey(day)])) {
        run = 0;
        lastSlip = day;
      } else {
        run++;
        if (run > best) best = run;
      }
    }
    return HabitStreak(current: run, best: best, lastSlip: lastSlip);
  }
}
