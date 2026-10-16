/// ============================================================
/// HABIT STATS CALCULATOR — numbers for the habit detail screen
/// ============================================================
///
/// Pure aggregation over one habit's logs: completion rate (last 30 days),
/// total check-ins, monthly completion bars, the year heatmap and today's
/// ring. [HabitStatsCalculator.compute] bundles everything into one
/// [HabitStats] value so the detail screen needs a single provider.
///
/// Shared rules (why they look the way they do):
///   • An in-progress today never lowers a rate: it only joins the
///     denominator once it is done.
///   • Skipped days are rest days: they leave the denominator.
///   • N× per week habits are measured against `N × days / 7` expected
///     check-ins, capped at 100 %.
///   • Quit habits: clean days / days (today included).
/// "Done", "slip" and progress come from [HabitSchedule] so the stats agree
/// with the streak and the habit cards.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

/// Completion of one calendar month (a bar in the monthly chart).
@immutable
class MonthlyCompletion {
  const MonthlyCompletion({
    required this.month,
    required this.rate,
    required this.isCurrent,
  });

  /// First day of the month (local midnight).
  final DateTime month;

  /// 0…1.
  final double rate;

  /// The month containing "today" (highlighted, still in progress).
  final bool isCurrent;

  @override
  bool operator ==(Object other) =>
      other is MonthlyCompletion &&
      other.month == month &&
      other.rate == rate &&
      other.isCurrent == isCurrent;

  @override
  int get hashCode => Object.hash(month, rate, isCurrent);

  @override
  String toString() =>
      'MonthlyCompletion(${DateUtilsX.dayKey(month)}, $rate'
      '${isCurrent ? ', current' : ''})';
}

/// Everything the habit detail screen shows, computed in one pass.
@immutable
class HabitStats {
  const HabitStats({
    required this.streak,
    required this.completionRate,
    required this.completionDays,
    required this.totalCheckIns,
    required this.monthly,
    required this.heatmap,
    required this.todayProgress,
    this.todayLog,
    this.restDays = const <String>{},
  });

  /// Stats of a habit without any history (loading / brand-new habit).
  static const empty = HabitStats(
    streak: HabitStreak.zero,
    completionRate: 0,
    completionDays: 30,
    totalCheckIns: 0,
    monthly: <MonthlyCompletion>[],
    heatmap: <String, double>{},
    todayProgress: 0,
  );

  final HabitStreak streak;

  /// 0…1 over the last [completionDays] days.
  final double completionRate;

  /// Window of [completionRate] in days ("Last 30 days").
  final int completionDays;

  /// Build: days with a check-in; quit: clean days.
  final int totalCheckIns;

  /// Oldest month first; the last entry is the current month.
  final List<MonthlyCompletion> monthly;

  /// `yyyy-MM-dd` → 0…1 progress.
  final Map<String, double> heatmap;

  /// `yyyy-MM-dd` keys of [heatmap] days the habit was not due (rest days:
  /// off-schedule weekdays, every-N-days gaps, an N× per week habit after
  /// its weekly quota). The heatmap draws them as "not scheduled", not as
  /// misses.
  final Set<String> restDays;

  /// 0…1 ring progress of today.
  final double todayProgress;
  final HabitLog? todayLog;

  static const _monthlyEq = ListEquality<MonthlyCompletion>();
  static const _heatmapEq = MapEquality<String, double>();
  static const _restEq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is HabitStats &&
      other.streak == streak &&
      other.completionRate == completionRate &&
      other.completionDays == completionDays &&
      other.totalCheckIns == totalCheckIns &&
      _monthlyEq.equals(other.monthly, monthly) &&
      _heatmapEq.equals(other.heatmap, heatmap) &&
      _restEq.equals(other.restDays, restDays) &&
      other.todayProgress == todayProgress &&
      other.todayLog == todayLog;

  @override
  int get hashCode => Object.hash(
    streak,
    completionRate,
    completionDays,
    totalCheckIns,
    _monthlyEq.hash(monthly),
    _heatmapEq.hash(heatmap),
    _restEq.hash(restDays),
    todayProgress,
    todayLog,
  );

  @override
  String toString() =>
      'HabitStats($streak, rate: $completionRate/$completionDays d, '
      'checkIns: $totalCheckIns, today: $todayProgress)';
}

/// Computes [HabitStats] and its parts. [weekStartsOn] (from settings) is
/// passed on to the [StreakCalculator].
class HabitStatsCalculator {
  const HabitStatsCalculator({this.weekStartsOn = DateTime.monday});

  /// First day of the week (`DateTime.monday … DateTime.sunday`).
  final int weekStartsOn;

  /// Completion 0…1 over the last [days] days ending [today] (the window is
  /// clipped to the habit's start date).
  ///
  /// Day-based build habits: done scheduled days / scheduled days, where
  /// skipped days leave the denominator and today only counts once done.
  /// N× per week: done days / `max(1, round(N × days / 7))`, capped at 1
  /// (skipped days and an unfinished today don't count as days).
  /// Quit habits: clean days / days in the window, today included.
  /// Returns 0 when there is nothing to measure.
  double completionRate(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime today, {
    int days = 30,
  }) {
    if (days <= 0) return 0;
    final end = DateUtilsX.dateOnly(today);
    return _rate(
      habit,
      HabitSchedule.indexByDay(logs),
      DateUtilsX.addDays(end, -(days - 1)),
      end,
      end,
    );
  }

  /// Build: number of days in [start date, today] with a check-in
  /// (count > 0, not skipped) — logs before the start date (kept when the
  /// start date moves later) don't count. Quit: number of clean days from
  /// the start date to [today].
  int totalCheckIns(Habit habit, Iterable<HabitLog> logs, DateTime today) =>
      _totalCheckIns(habit, HabitSchedule.indexByDay(logs), today);

  /// The last [months] calendar months, oldest first; the current month is
  /// last and flagged `isCurrent`. Each rate follows [completionRate]'s
  /// rules restricted to that month (the current month up to [today];
  /// months before the start date → 0).
  List<MonthlyCompletion> monthlyCompletion(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime today, {
    int months = 6,
  }) => _monthly(habit, HabitSchedule.indexByDay(logs), today, months);

  /// `yyyy-MM-dd` → 0…1 progress for every day in [from, to] that is on or
  /// after the start date and not after [today]. Build: count / target
  /// (capped; skipped → 0). Quit: 1 clean / 0 slip. Other days are omitted.
  Map<String, double> heatmap(
    Habit habit,
    Iterable<HabitLog> logs, {
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) => _heatmap(habit, HabitSchedule.indexByDay(logs), from, to, today);

  /// 0…1 ring progress for today's log (`Habit.progressWith`; a skipped
  /// quit day counts as clean, see [HabitSchedule.progress]).
  double todayProgress(Habit habit, HabitLog? todayLog) =>
      HabitSchedule.progress(habit, todayLog);

  /// Everything for the habit detail screen: streak, completion rate over
  /// [completionDays], total check-ins, the last [months] months and the
  /// heatmap over the last [heatmapDays] days ending [today].
  HabitStats compute(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime today, {
    int completionDays = 30,
    int heatmapDays = 365,
    int months = 6,
  }) {
    final end = DateUtilsX.dateOnly(today);
    final byDay = HabitSchedule.indexByDay(logs);
    final todayLog = byDay[DateUtilsX.dayKey(end)];
    return HabitStats(
      streak: StreakCalculator(
        weekStartsOn: weekStartsOn,
      ).calculateIndexed(habit, byDay, end),
      completionRate: completionDays <= 0
          ? 0
          : _rate(
              habit,
              byDay,
              DateUtilsX.addDays(end, -(completionDays - 1)),
              end,
              end,
            ),
      completionDays: completionDays,
      totalCheckIns: _totalCheckIns(habit, byDay, end),
      monthly: _monthly(habit, byDay, end, months),
      heatmap: heatmapDays <= 0
          ? <String, double>{}
          : _heatmap(
              habit,
              byDay,
              DateUtilsX.addDays(end, -(heatmapDays - 1)),
              end,
              end,
            ),
      todayProgress: todayProgress(habit, todayLog),
      todayLog: todayLog,
      restDays: heatmapDays <= 0
          ? const <String>{}
          : _restDays(
              habit,
              byDay,
              DateUtilsX.addDays(end, -(heatmapDays - 1)),
              end,
              end,
            ),
    );
  }

  // ---------------------------------------------------------------- helpers

  /// Rate over [from, to] clipped to [startDate, today]; see
  /// [completionRate] for the rules.
  double _rate(
    Habit habit,
    Map<String, HabitLog> byDay,
    DateTime from,
    DateTime to,
    DateTime today,
  ) {
    final start = DateUtilsX.dateOnly(habit.startDate);
    final first = HabitSchedule.daysBetween(start, from) < 0
        ? start
        : DateUtilsX.dateOnly(from);
    final last = HabitSchedule.daysBetween(today, to) > 0
        ? DateUtilsX.dateOnly(today)
        : DateUtilsX.dateOnly(to);
    final count = HabitSchedule.daysBetween(first, last) + 1;
    if (count <= 0) return 0;

    final frequency = habit.frequency;
    if (habit.isQuit) {
      var clean = 0;
      for (var i = 0; i < count; i++) {
        if (HabitSchedule.isDone(habit, byDay[_key(first, i)])) clean++;
      }
      return clean / count;
    }

    final perWeek = frequency is TimesPerWeekFrequency
        ? frequency.times.clamp(1, 7)
        : null;
    final days = perWeek == null
        ? HabitSchedule.scheduledDaysBetween(habit, first, last)
        : [for (var i = 0; i < count; i++) _day(first, i)];
    var measured = 0;
    var done = 0;
    for (final day in days) {
      final log = byDay[DateUtilsX.dayKey(day)];
      if (HabitSchedule.isDone(habit, log)) {
        done++;
        measured++;
      } else if (!(log?.skipped ?? false) &&
          !DateUtilsX.isSameDay(day, today)) {
        measured++;
      }
    }
    if (measured == 0) return 0;
    if (perWeek == null) return done / measured;
    final expected = math.max(1, (perWeek * measured / 7).round());
    return math.min(1, done / expected).toDouble();
  }

  int _totalCheckIns(Habit habit, Map<String, HabitLog> byDay, DateTime today) {
    if (habit.isQuit) {
      final span = HabitSchedule.daysBetween(habit.startDate, today);
      final start = DateUtilsX.dateOnly(habit.startDate);
      var clean = 0;
      for (var i = 0; i <= span; i++) {
        if (HabitSchedule.isDone(habit, byDay[_key(start, i)])) clean++;
      }
      return clean;
    }
    return byDay.values
        .where(
          (log) =>
              log.count > 0 &&
              !log.skipped &&
              HabitSchedule.daysBetween(habit.startDate, log.date) >= 0 &&
              HabitSchedule.daysBetween(log.date, today) >= 0,
        )
        .length;
  }

  List<MonthlyCompletion> _monthly(
    Habit habit,
    Map<String, HabitLog> byDay,
    DateTime today,
    int months,
  ) {
    final end = DateUtilsX.dateOnly(today);
    return [
      for (var back = months - 1; back >= 0; back--)
        _month(habit, byDay, DateTime(end.year, end.month - back), end),
    ];
  }

  MonthlyCompletion _month(
    Habit habit,
    Map<String, HabitLog> byDay,
    DateTime month,
    DateTime today,
  ) {
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    return MonthlyCompletion(
      month: month,
      rate: _rate(habit, byDay, month, monthEnd, today),
      isCurrent: month.year == today.year && month.month == today.month,
    );
  }

  Map<String, double> _heatmap(
    Habit habit,
    Map<String, HabitLog> byDay,
    DateTime from,
    DateTime to,
    DateTime today,
  ) {
    final start = DateUtilsX.dateOnly(habit.startDate);
    final first = HabitSchedule.daysBetween(start, from) < 0
        ? start
        : DateUtilsX.dateOnly(from);
    final last = HabitSchedule.daysBetween(today, to) > 0 ? today : to;
    final count = HabitSchedule.daysBetween(first, last) + 1;
    return {
      for (var i = 0; i < count; i++)
        _key(first, i): HabitSchedule.progress(habit, byDay[_key(first, i)]),
    };
  }

  /// Keys of the days in [from, to] (clipped like [_heatmap]) on which
  /// [habit] was not due — HabitSchedule.isDueOn, pause ignored (history).
  Set<String> _restDays(
    Habit habit,
    Map<String, HabitLog> byDay,
    DateTime from,
    DateTime to,
    DateTime today,
  ) {
    if (habit.isQuit) return const <String>{};
    final start = DateUtilsX.dateOnly(habit.startDate);
    final first = HabitSchedule.daysBetween(start, from) < 0
        ? start
        : DateUtilsX.dateOnly(from);
    final last = HabitSchedule.daysBetween(today, to) > 0 ? today : to;
    final count = HabitSchedule.daysBetween(first, last) + 1;
    return {
      for (var i = 0; i < count; i++)
        if (!HabitSchedule.isDueOn(
          habit,
          _day(first, i),
          byDay,
          weekStartsOn: weekStartsOn,
          ignorePause: true,
        ))
          _key(first, i),
    };
  }

  /// The day [offset] days after [base] (DST-safe local midnight).
  static DateTime _day(DateTime base, int offset) =>
      DateTime(base.year, base.month, base.day + offset);

  static String _key(DateTime base, int offset) =>
      DateUtilsX.dayKey(_day(base, offset));
}
