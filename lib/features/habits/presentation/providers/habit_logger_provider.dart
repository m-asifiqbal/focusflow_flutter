/// ============================================================
/// HABIT LOGGER — applies check-ins for every habit entry point
/// ============================================================
///
/// The card's round button, the swipe "Log" action, the item-actions "Log
/// today" row and the long-press amount sheet all write through
/// [HabitLogger]. *Which* change a gesture makes is decided by the pure
/// HabitCheckIn rules; this class only maps that change onto the
/// repository for the current habit day and reports what happened so the
/// UI can give feedback (haptics, Undo for a slip).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/domain/services/habit_check_in.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// What a check-in did.
enum HabitLogOutcome {
  /// Nothing changed (e.g. "Log today" on a habit that is already done).
  unchanged,

  /// Progress moved forward (check-in, done, slip cleared).
  progressed,

  /// Progress moved back (last check-in undone, done → not done).
  reverted,

  /// A quit habit's slip was recorded (streak reset — offer Undo).
  slipped,
}

class HabitLogger {
  HabitLogger(this._repo, this._today);

  final HabitsRepository _repo;
  final DateTime _today;

  /// The habit day writes go to.
  DateTime get today => _today;

  /// The card button: increment / undo / toggle (see HabitCheckIn.tap).
  Future<HabitLogOutcome> tap(HabitDayStatus status) {
    final change = HabitCheckIn.tap(status);
    return _apply(status.habit, status.log, change, status.day);
  }

  /// Swipe "Log" / sheet "Log today": only ever moves today forward.
  Future<HabitLogOutcome> logToday(String habitId) async {
    final data = await _repo
        .watchHabitWithLogs(habitId, from: _today, to: _today)
        .first;
    if (data == null) return HabitLogOutcome.unchanged;
    final log = data.logs.isEmpty ? null : data.logs.last;
    final change = HabitCheckIn.logToday(data.habit, log);
    if (change == null) return HabitLogOutcome.unchanged;
    return _apply(data.habit, log, change, _today);
  }

  /// Undoes a [tap] / [logToday] on [habit]: restores the day's log as it
  /// was [before] (null = no log).
  Future<void> undo(Habit habit, HabitLog? before) =>
      restoreDay(habit.id, _today, before);

  /// Undo of any write to [day]: puts the log back as it was [before]
  /// (null = no log at all).
  Future<void> restoreDay(String habitId, DateTime day, HabitLog? before) {
    if (before == null) return _repo.clearLog(habitId, day);
    return _repo.setLog(
      habitId,
      day,
      count: before.count,
      skipped: before.skipped,
      note: before.note,
    );
  }

  /// Long-press amount sheet: writes today's count exactly (keeps a note).
  Future<void> setAmount(HabitDayStatus status, int count) => _repo.setLog(
    status.habit.id,
    status.day,
    count: count,
    note: status.log?.note,
  );

  /// Long-press amount sheet: a deliberate rest day.
  Future<void> skip(HabitDayStatus status) =>
      _repo.skip(status.habit.id, status.day);

  /// Long-press amount sheet: back to "nothing logged".
  Future<void> clear(HabitDayStatus status) =>
      _repo.clearLog(status.habit.id, status.day);

  Future<void> setPaused(String habitId, bool paused) =>
      _repo.setPaused(habitId, paused);

  /// Detail screen (16) primary button: applies [change] to today's
  /// [todayLog] of [habit] (see HabitCheckIn.detailLog).
  Future<HabitLogOutcome> apply(
    Habit habit,
    HabitLog? todayLog,
    HabitLogChange change,
  ) => _apply(habit, todayLog, change, _today);

  /// Detail "Skip today": a rest day for [habitId].
  Future<void> skipToday(String habitId) => _repo.skip(habitId, _today);

  Future<HabitLogOutcome> _apply(
    Habit habit,
    HabitLog? log,
    HabitLogChange change,
    DateTime day,
  ) async {
    final slip = HabitCheckIn.logsSlip(habit, log, change);
    final wasDone = habit.isDoneWith(log);
    switch (change) {
      case HabitLogChange.increment:
        await _repo.increment(habit.id, day);
      case HabitLogChange.decrement:
        await _repo.increment(habit.id, day, by: -1);
      case HabitLogChange.toggle:
        await _repo.toggleDone(habit.id, day);
    }
    if (slip) return HabitLogOutcome.slipped;
    if (change == HabitLogChange.decrement) return HabitLogOutcome.reverted;
    if (change == HabitLogChange.toggle && wasDone && !habit.isQuit) {
      return HabitLogOutcome.reverted;
    }
    return HabitLogOutcome.progressed;
  }
}

/// The logger for the current habit day.
final habitLoggerProvider = Provider.autoDispose<HabitLogger>(
  (ref) => HabitLogger(
    ref.watch(habitsRepositoryProvider),
    ref.watch(habitTodayProvider),
  ),
);
