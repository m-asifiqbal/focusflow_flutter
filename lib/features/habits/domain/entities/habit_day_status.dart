/// ============================================================
/// HABIT DAY STATUS — everything one habit card needs for one day
/// ============================================================
///
/// Built by `HabitDayStatusBuilder` (pure, unit tested) and streamed by
/// `HabitsRepository.watchTodayHabits(day)` for Home (rings) and the Habits
/// list (card, + button, weekday squares, 🔥 streak).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

/// One weekday square in a habit card footer.
@immutable
class HabitDayCell {
  const HabitDayCell({
    required this.day,
    required this.isDone,
    required this.isScheduled,
    required this.isSkipped,
    required this.isFuture,
    required this.progress,
  });

  /// Local midnight.
  final DateTime day;

  /// Done (build) / clean (quit). Always false for future days.
  final bool isDone;
  final bool isScheduled;
  final bool isSkipped;

  /// After the reference day (render dashed / empty).
  final bool isFuture;

  /// 0…1 (see Habit.progressWith); 0 for future days.
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is HabitDayCell &&
      other.day == day &&
      other.isDone == isDone &&
      other.isScheduled == isScheduled &&
      other.isSkipped == isSkipped &&
      other.isFuture == isFuture &&
      other.progress == progress;

  @override
  int get hashCode =>
      Object.hash(day, isDone, isScheduled, isSkipped, isFuture, progress);
}

@immutable
class HabitDayStatus {
  const HabitDayStatus({
    required this.habit,
    required this.day,
    required this.log,
    required this.progress,
    required this.isDone,
    required this.isScheduled,
    required this.streak,
    required this.week,
  });

  final Habit habit;

  /// The day this status describes (local midnight).
  final DateTime day;

  /// That day's log, if any.
  final HabitLog? log;

  /// 0…1 ring progress.
  final double progress;

  /// Done (build: count ≥ target) / clean (quit: no slip).
  final bool isDone;

  /// False on rest days (weekdays-only habit on Saturday, paused habit …).
  final bool isScheduled;
  final HabitStreak streak;

  /// The 7 days of the week containing [day] (week start from settings),
  /// for the M T W T F S S squares.
  final List<HabitDayCell> week;

  /// Today's count (check-ins for build habits, slips for quit habits).
  int get count => log?.count ?? 0;
  bool get isSkipped => log?.skipped ?? false;
  int get currentStreak => streak.current;

  /// An N× per week habit that is not due on [day] because this week's
  /// quota was already met (see HabitSchedule.isDueOn).
  bool get isWeekGoalMet =>
      !isScheduled &&
      !habit.isQuit &&
      !habit.isPaused &&
      habit.frequency is TimesPerWeekFrequency &&
      DateUtilsX.daysBetween(habit.startDate, day) >= 0;

  /// "6 / 8 glasses", "Completed", "Quit habit · day 9", "Paused",
  /// "Week goal met", "Rest day".
  String get progressLabel {
    if (habit.isQuit) return 'Quit habit · day ${streak.current}';
    if (isSkipped) return 'Skipped';
    if (isDone) return 'Completed';
    if (habit.isPaused) return 'Paused';
    if (!isScheduled) return isWeekGoalMet ? 'Week goal met' : 'Rest day';
    if (habit.isYesNo) return habit.frequency.label;
    return '$count / ${habit.targetCount} ${habit.unit}';
  }

  static const _cellsEq = ListEquality<HabitDayCell>();

  @override
  bool operator ==(Object other) =>
      other is HabitDayStatus &&
      other.habit == habit &&
      other.day == day &&
      other.log == log &&
      other.progress == progress &&
      other.isDone == isDone &&
      other.isScheduled == isScheduled &&
      other.streak == streak &&
      _cellsEq.equals(other.week, week);

  @override
  int get hashCode => Object.hash(
    habit,
    day,
    log,
    progress,
    isDone,
    isScheduled,
    streak,
    _cellsEq.hash(week),
  );
}
