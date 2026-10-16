/// ============================================================
/// HABITS REPOSITORY (contract)
/// ============================================================
///
/// Day-level logic (streaks, schedule, stats) is pure domain code in
/// `domain/services/` — this contract only loads data and writes logs.
/// Days are local calendar days; pass any DateTime within the day.
/// Log semantics: build habit count = check-ins; quit habit count = slips
/// (see Habit.isDoneWith).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';

/// Filter chips of the habits list (screen 14).
enum HabitsScope {
  /// Active, not paused (rest days included — see HabitDayStatus).
  today,

  /// Every active habit, paused ones included.
  all,

  /// Active habits for the morning.
  morning,

  /// Active habits for the afternoon.
  afternoon,

  /// Active habits for the afternoon or evening ("Evening" chip). Screen
  /// 14 only has Morning / Evening chips, so "Evening" is the second half
  /// of the day — afternoon habits stay reachable from a chip.
  evening,

  /// Archived (not deleted) habits.
  archived,
}

@immutable
class HabitsQuery {
  const HabitsQuery({this.scope = HabitsScope.all, this.text = ''});

  final HabitsScope scope;

  /// Case-insensitive name / category substring filter.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is HabitsQuery && other.scope == scope && other.text == text;

  @override
  int get hashCode => Object.hash(scope, text);
}

/// A habit with its logs in a requested range (oldest first).
@immutable
class HabitWithLogs {
  const HabitWithLogs({required this.habit, required this.logs});

  final Habit habit;
  final List<HabitLog> logs;

  static const _eq = ListEquality<HabitLog>();

  @override
  bool operator ==(Object other) =>
      other is HabitWithLogs &&
      other.habit == habit &&
      _eq.equals(other.logs, logs);

  @override
  int get hashCode => Object.hash(habit, _eq.hash(logs));
}

/// Everything the habit detail screen (16) needs.
@immutable
class HabitDetail {
  const HabitDetail({
    required this.habit,
    required this.logs,
    required this.stats,
    required this.today,
  });

  final Habit habit;

  /// Full history, oldest first (history list: reverse it).
  final List<HabitLog> logs;
  final HabitStats stats;

  /// The day the stats refer to.
  final DateTime today;

  /// Nothing to show yet — the detail screen shows placeholders. A build
  /// habit has no data before its first check-in; a quit habit's clean days
  /// need no log, so it has data from its start date on (only a habit that
  /// starts after [today] is empty).
  bool get isEmpty => habit.isQuit
      ? DateUtilsX.daysBetween(habit.startDate, today) < 0
      : logs.isEmpty;

  static const _eq = ListEquality<HabitLog>();

  @override
  bool operator ==(Object other) =>
      other is HabitDetail &&
      other.habit == habit &&
      _eq.equals(other.logs, logs) &&
      other.stats == stats &&
      other.today == today;

  @override
  int get hashCode => Object.hash(habit, _eq.hash(logs), stats, today);
}

abstract interface class HabitsRepository {
  /// Habits for a list scope, pinned first then manual order.
  Stream<List<Habit>> watchHabits(HabitsQuery query);

  /// One habit in any lifecycle state (null when gone).
  Stream<Habit?> watchHabit(String id);
  Future<Habit?> getHabit(String id);

  /// The habit and its logs with day in [from, to] (inclusive; null =
  /// unbounded).
  Stream<HabitWithLogs?> watchHabitWithLogs(
    String id, {
    DateTime? from,
    DateTime? to,
  });

  /// Habit + full history + computed stats (streaks, 30-day completion,
  /// check-ins, 6 monthly bars, 365-day heatmap) for [today] (default
  /// now).
  Stream<HabitDetail?> watchHabitDetail(
    String id, {
    DateTime? today,
    int weekStartsOn = DateTime.monday,
  });

  /// One card model per active, not paused habit for [day] (pinned first,
  /// manual order): progress, done, scheduled, streak, week squares.
  Stream<List<HabitDayStatus>> watchTodayHabits(
    DateTime day, {
    int weekStartsOn = DateTime.monday,
  });

  /// One card model per habit of [query] for [day] — the habits list's
  /// cards for every chip (Today, All habits incl. paused, Morning,
  /// Evening, Archived). Same ordering and rules as [watchTodayHabits].
  Stream<List<HabitDayStatus>> watchDayStatuses(
    HabitsQuery query,
    DateTime day, {
    int weekStartsOn = DateTime.monday,
  });

  /// Logs of every habit with day in [from, to] (Insights).
  Stream<List<HabitLog>> watchLogsInRange(DateTime from, DateTime to);

  /// Adds [by] to the day's count (never below 0) and clears "skipped".
  /// Build habit: +1 check-in; quit habit: logs a slip. Returns the new
  /// count.
  Future<int> increment(String habitId, DateTime day, {int by = 1});

  /// Writes the day's log exactly (heatmap cell editor / custom amount).
  Future<void> setLog(
    String habitId,
    DateTime day, {
    required int count,
    bool skipped = false,
    String? note,
  });

  /// Marks the day skipped (rest day; never breaks a streak).
  Future<void> skip(String habitId, DateTime day);

  /// Flips the day between done and not done. Build: count 0 ⇄ target.
  /// Quit: clean ⇄ one slip.
  Future<void> toggleDone(String habitId, DateTime day);

  /// Removes the day's log.
  Future<void> clearLog(String habitId, DateTime day);

  /// Creates ([Habit.isNew]) or updates a habit. Returns the id.
  ///
  /// Create writes every field (+ tags by name). Update writes only the
  /// fields the habit editor owns (name, look, type, goal, schedule,
  /// reminders, start date): paused / pinned / favourite and tags keep
  /// their stored values, so saving a stale editor draft never reverts a
  /// concurrent change ([setPaused], the shared item actions).
  Future<String> save(Habit habit);

  /// Manual order: place [id] between [afterId] (above) and [beforeId]
  /// (below); either may be null at the ends.
  Future<void> reorder(String id, {String? afterId, String? beforeId});

  /// Deletes every log of the habit (editor "Reset history").
  Future<void> resetHistory(String id);

  /// Undo of [resetHistory]: writes [logs] back in one transaction (all or
  /// nothing; one stream update). A day logged again in the meantime is
  /// overwritten with the restored values.
  Future<void> restoreLogs(List<HabitLog> logs);

  Future<void> setPaused(String id, bool paused);
}
