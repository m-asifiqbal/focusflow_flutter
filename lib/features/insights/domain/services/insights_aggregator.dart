/// ============================================================
/// INSIGHTS AGGREGATOR — raw repository data → InsightsSnapshot
/// ============================================================
///
/// Pure Dart (no widgets, no Drift): the provider hands over plain lists
/// covering the current *and* previous window, and this class filters,
/// buckets and counts them. Definitions (shown nowhere else, so read
/// these when a number looks odd):
///   • Task completion — tasks *due* in the window (active ones); done =
///     those with a completion. Rate = done / due; no due tasks → no data.
///   • Focus hours — minutes of focus sessions that *started* in the
///     window.
///   • Habit consistency — pooled over active, not paused habits, by the
///     same rules as HabitStatsCalculator's completion rate: scheduled
///     days (HabitSchedule) from the habit's start date to today; done →
///     counted + done; skipped → left out; not done → counted, except
///     today (still in progress). N× per week habits contribute
///     `max(1, round(N × days / 7))` expected days (done capped at it);
///     quit habits contribute every day (clean = done).
///   • Notes created — active notes created in the window.
///   • Check-ins — logs of active *build* habits with count > 0 and not
///     skipped (as "total check-ins" on the habit detail). Quit habits log
///     slips, so they never add check-ins.
///   • Productivity score per day = tasks completed + habit check-ins;
///     ranges over 31 days are bucketed per 7 days.
///   • Where your time went — tasks completed, check-ins, notes created
///     and reminder occurrences marked done, in the window.
/// Day bucketing uses calendar-day differences (DateUtilsX.daysBetween),
/// so a 23- or 25-hour DST day is still one bucket.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/insights/domain/entities/focus_session.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/domain/entities/insights_timeline.dart';
import 'package:focusflow/features/insights/domain/services/insights_tips.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

/// The raw data for one range. Lists may contain items outside the
/// windows — the aggregator filters by date itself.
@immutable
class InsightsSources {
  const InsightsSources({
    this.tasksDue = const [],
    this.tasksCompleted = const [],
    this.focusSessions = const [],
    this.habits = const [],
    this.habitLogs = const [],
    this.notesCreated = const [],
    this.reminders = const [],
    this.habitStatuses = const [],
  });

  /// Active tasks due in [previous.start, current.end).
  final List<TaskItem> tasksDue;

  /// Active tasks completed in [previous.start, current.end).
  final List<TaskItem> tasksCompleted;
  final List<FocusSession> focusSessions;

  /// Active habits (paused ones included).
  final List<Habit> habits;

  /// Logs of every habit for the days of both windows.
  final List<HabitLog> habitLogs;

  /// Creation instants of active notes.
  final List<DateTime> notesCreated;

  /// Reminder occurrences of the current window.
  final List<ReminderOccurrence> reminders;

  /// Today's habit cards (streaks over the whole history).
  final List<HabitDayStatus> habitStatuses;
}

class InsightsAggregator {
  const InsightsAggregator({this.maxStreakRows});

  /// Optional cap on rows in "Habit streaks" (null = all habits).
  final int? maxStreakRows;

  /// Ranges longer than this are plotted per week.
  static const int dailyBucketMaxDays = 31;

  /// Computes the snapshot of [window] (deltas against
  /// `window.previous`) as of [now].
  InsightsSnapshot compute(
    InsightsSources s,
    InsightsWindow window,
    DateTime now,
  ) {
    final prev = window.previous;
    final today = DateUtilsX.dateOnly(now);
    final habitsById = {for (final h in s.habits) h.id: h};
    final checkIns = _checkIns(s.habitLogs, habitsById);
    final completed = [
      for (final t in s.tasksCompleted)
        if (t.completedAt != null) t.completedAt!,
    ];

    final tasksNow = _tasksInWindow(s.tasksCompleted, window);
    final checkInsNow = checkIns.where((l) => window.contains(l.date)).length;
    final notesNow = s.notesCreated.where(window.contains).length;
    final remindersNow = s.reminders
        .where((o) => o.isDone && window.contains(o.at))
        .length;
    final split = TimeSplit(
      tasks: tasksNow,
      habits: checkInsNow,
      notes: notesNow,
      reminders: remindersNow,
    );

    final daily = _daily(window, completed, checkIns);
    final consistency = Kpi(
      current: habitConsistency(s.habits, s.habitLogs, window, today),
      previous: habitConsistency(s.habits, s.habitLogs, prev, today),
    );
    final focus = Kpi(
      current: _focusMinutes(s.focusSessions, window),
      previous: _focusMinutes(s.focusSessions, prev),
    );

    return InsightsSnapshot(
      window: window,
      taskCompletion: Kpi(
        current: taskCompletion(s.tasksDue, window),
        previous: taskCompletion(s.tasksDue, prev),
      ),
      focusMinutes: focus,
      habitConsistency: consistency,
      notesCreated: Kpi(
        current: notesNow,
        previous: s.notesCreated.where(prev.contains).length,
      ),
      series: _bucket(window, daily),
      split: split,
      streaks: streakRows(s.habitStatuses),
      timeline: TaskTimeline.build(s.tasksDue, window, today),
      hasHabits: s.habits.isNotEmpty,
      tip: InsightsTips.pick(
        window: window,
        completedAt: completed.where(window.contains).toList(),
        daily: daily,
        consistency: consistency.current,
        focusMinutes: focus.current,
      ),
    );
  }

  // ─────────────────────────────── KPIs ────────────────────────────────

  /// Tasks due in [window]: completed / due.
  RatioMetric taskCompletion(List<TaskItem> tasksDue, InsightsWindow window) {
    var total = 0;
    var done = 0;
    for (final t in tasksDue) {
      final due = t.dueDate;
      if (due == null || !t.isActive || !window.contains(due)) continue;
      total++;
      if (t.isCompleted) done++;
    }
    return RatioMetric(done: done, total: total);
  }

  /// Pooled scheduled-day consistency of active, not paused [habits] over
  /// [window], clipped to [today]. See the file header for the rules.
  RatioMetric habitConsistency(
    List<Habit> habits,
    List<HabitLog> logs,
    InsightsWindow window,
    DateTime today,
  ) {
    final byHabit = logs.groupListsBy((l) => l.habitId);
    final todayDay = DateUtilsX.dateOnly(today);
    var done = 0;
    var total = 0;
    for (final h in habits) {
      if (!h.isActive || h.isPaused) continue;
      final start = DateUtilsX.dateOnly(h.startDate);
      final first = start.isAfter(window.start) ? start : window.start;
      final last = window.lastDay.isAfter(todayDay) ? todayDay : window.lastDay;
      if (first.isAfter(last)) continue;
      final r = _habitDays(
        h,
        HabitSchedule.indexByDay(byHabit[h.id] ?? const []),
        first,
        last,
        todayDay,
      );
      done += r.done;
      total += r.total;
    }
    return RatioMetric(done: done, total: total);
  }

  ({int done, int total}) _habitDays(
    Habit h,
    Map<String, HabitLog> byDay,
    DateTime first,
    DateTime last,
    DateTime today,
  ) {
    final span = DateUtilsX.daysBetween(first, last) + 1;
    final allDays = [
      for (var i = 0; i < span; i++) DateUtilsX.addDays(first, i),
    ];
    if (h.isQuit) {
      final clean = allDays
          .where((d) => HabitSchedule.isDone(h, byDay[DateUtilsX.dayKey(d)]))
          .length;
      return (done: clean, total: span);
    }
    final freq = h.frequency;
    final perWeek = freq is TimesPerWeekFrequency
        ? freq.times.clamp(1, 7)
        : null;
    final days = perWeek == null
        ? HabitSchedule.scheduledDaysBetween(h, first, last)
        : allDays;
    var done = 0;
    var measured = 0;
    for (final d in days) {
      final log = byDay[DateUtilsX.dayKey(d)];
      if (HabitSchedule.isDone(h, log)) {
        done++;
        measured++;
      } else if (!(log?.skipped ?? false) && !DateUtilsX.isSameDay(d, today)) {
        measured++;
      }
    }
    if (perWeek == null || measured == 0) return (done: done, total: measured);
    final expected = math.max(1, (perWeek * measured / 7).round());
    return (done: math.min(done, expected), total: expected);
  }

  int _focusMinutes(List<FocusSession> sessions, InsightsWindow w) => sessions
      .where((f) => w.contains(f.startedAt))
      .fold(0, (sum, f) => sum + f.durationMinutes);

  int _tasksInWindow(List<TaskItem> completed, InsightsWindow w) => completed
      .where((t) => t.completedAt != null && w.contains(t.completedAt!))
      .length;

  /// Check-in logs of active build habits (count > 0, not skipped).
  List<HabitLog> _checkIns(List<HabitLog> logs, Map<String, Habit> habits) => [
    for (final l in logs)
      if (habits[l.habitId] case final h?
          when !h.isQuit && h.isActive && l.count > 0 && !l.skipped)
        l,
  ];

  // ─────────────────────────────── Series ──────────────────────────────

  /// One point per day of [w].
  List<ProductivityPoint> _daily(
    InsightsWindow w,
    List<DateTime> completedAt,
    List<HabitLog> checkIns,
  ) {
    final n = w.days;
    final tasks = List<int>.filled(n, 0);
    final habits = List<int>.filled(n, 0);
    for (final t in completedAt) {
      final i = w.dayIndexOf(t);
      if (i >= 0 && i < n) tasks[i]++;
    }
    for (final l in checkIns) {
      final i = w.dayIndexOf(l.date);
      if (i >= 0 && i < n) habits[i]++;
    }
    return [
      for (var i = 0; i < n; i++)
        ProductivityPoint(
          start: DateUtilsX.addDays(w.start, i),
          days: 1,
          tasks: tasks[i],
          habits: habits[i],
        ),
    ];
  }

  /// Daily points, or 7-day buckets (the last may be shorter) when the
  /// window is longer than [dailyBucketMaxDays].
  List<ProductivityPoint> _bucket(
    InsightsWindow w,
    List<ProductivityPoint> daily,
  ) {
    if (w.days <= dailyBucketMaxDays) return daily;
    return [
      for (final chunk in daily.slices(7))
        ProductivityPoint(
          start: chunk.first.start,
          days: chunk.length,
          tasks: chunk.map((p) => p.tasks).sum,
          habits: chunk.map((p) => p.habits).sum,
        ),
    ];
  }

  // ─────────────────────────────── Streaks ─────────────────────────────

  /// Longest current streaks first (weeks weigh 7 days), then best streak,
  /// then name; at most [maxStreakRows]. Bars are relative to the first.
  List<StreakRow> streakRows(List<HabitDayStatus> statuses) {
    int weight(HabitStreak s, int v) => s.unit == StreakUnit.weeks ? v * 7 : v;
    final sorted = statuses.where((s) => s.habit.isActive).toList()
      ..sort((a, b) {
        final c = weight(
          b.streak,
          b.streak.current,
        ).compareTo(weight(a.streak, a.streak.current));
        if (c != 0) return c;
        final best = weight(
          b.streak,
          b.streak.best,
        ).compareTo(weight(a.streak, a.streak.best));
        if (best != 0) return best;
        return a.habit.name.toLowerCase().compareTo(b.habit.name.toLowerCase());
      });
    final top = maxStreakRows == null
        ? sorted
        : sorted.take(maxStreakRows!).toList();
    final max = top.isEmpty
        ? 0
        : weight(top.first.streak, top.first.streak.current);
    return [
      for (final s in top)
        StreakRow(
          habitId: s.habit.id,
          name: s.habit.name,
          iconKey: s.habit.iconKey,
          colorHex: s.habit.colorHex,
          streak: s.streak,
          progress: max == 0 ? 0 : weight(s.streak, s.streak.current) / max,
        ),
    ];
  }
}
