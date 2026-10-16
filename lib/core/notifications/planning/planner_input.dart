/// ============================================================
/// PLANNER INPUT — a snapshot of everything the planner looks at
/// ============================================================
///
/// The engine builds one of these from the live repository streams and the
/// settings; tests build them by hand. Everything here is plain data, so
/// planning is a pure function of its input (and fully unit testable with
/// any "now" and any time zone).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/notifications/planning/quiet_hours.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:intl/intl.dart';

@immutable
class PlannerInput {
  const PlannerInput({
    required this.now,
    required this.calendar,
    required this.settings,
    this.reminders = const [],
    this.tasks = const [],
    this.habits = const [],
    this.horizonDays = 14,
  });

  /// Plan notifications strictly after this instant.
  final DateTime now;

  /// Wall-clock zone (device zone or `AppSettings.timeZone`).
  final ZoneCalendar calendar;
  final AppSettings settings;

  /// Schedulable reminders (`RemindersRepository.watchSchedulable`):
  /// active, enabled, not completed, linked item active.
  final List<Reminder> reminders;

  /// Active tasks (open and completed) — overdue summary, digests, badge.
  final List<TaskItem> tasks;

  /// Today's status of every active, not paused habit
  /// (`HabitsRepository.watchTodayHabits`).
  final List<HabitDayStatus> habits;

  /// How many calendar days ahead to plan (the rolling window).
  final int horizonDays;

  /// Today in [calendar]'s zone.
  DateTime get today => calendar.dayOf(now);

  QuietHours? get quietHours => settings.quietHours
      ? QuietHours(
          startMinutes: settings.quietStartMinutes,
          endMinutes: settings.quietEndMinutes,
        )
      : null;

  /// "8:00 AM" / "08:00" for an instant on the wall clock.
  String formatTime(DateTime instant) {
    final w = calendar.wall(instant);
    final local = DateTime(w.year, w.month, w.day, w.hour, w.minute);
    return DateFormat(
      settings.use24HourTime ? 'HH:mm' : 'h:mm a',
    ).format(local);
  }
}

/// Fixed wall times of notifications that have no setting of their own.
abstract final class PlannerTimes {
  /// Streak-at-risk nudge (20:00).
  static const int streakRiskMinutes = 20 * 60;

  /// Weekly report on the chosen weekday (18:00).
  static const int weeklyReportMinutes = 18 * 60;
}
