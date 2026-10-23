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

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/notifications/planning/quiet_hours.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

@immutable
class PlannerInput {
  const PlannerInput({
    required this.now,
    required this.calendar,
    required this.settings,
    this.reminders = const [],
    this.tasks = const [],
    this.habits = const [],
    this.medicines = const [],
    this.horizonDays = 14,
    this.vitalHorizonDays = 14,
    this.maxScheduled = defaultMaxScheduled,
  });

  /// iOS keeps at most 64 pending requests; Android's AlarmManager allows
  /// 500 alarms per app. The default is the conservative (iOS) number.
  static const int defaultMaxScheduled = 60;

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

  /// Schedulable medicines (`MedicinesRepository.schedulable`) with their
  /// dose logs from yesterday to the end of the window.
  final List<MedicineWithDoses> medicines;

  /// How many calendar days ahead to plan (the rolling window).
  final int horizonDays;

  /// How far ahead the *next* occurrence of a reminder (and so a task's
  /// due alert) is handed to the OS. Longer than [horizonDays]: with the
  /// app closed nothing rolls the window forward, so a reminder that is
  /// weeks away must already be with the OS. Never shorter than
  /// [horizonDays].
  final int vitalHorizonDays;

  /// Cap on notifications handed to the OS at once (see
  /// [NotificationPlanner.plan]: reminders, alarms and task alerts take
  /// their slots first, habit nudges and digests fill what is left).
  final int maxScheduled;

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
    return DateFormats.of(
      settings.use24HourTime ? 'HH:mm' : 'h:mm a',
    ).format(local);
  }
}

/// How much the OS can be asked to hold, per platform.
///
/// iOS keeps at most 64 pending requests, so its window is tight and a
/// reminder further than [vitalHorizonDays] waits for the next refill.
/// Android's AlarmManager takes 500 alarms per app: a long reach costs
/// nothing there and is what keeps reminders firing while the app stays
/// closed for weeks.
@immutable
class PlannerLimits {
  const PlannerLimits({
    required this.horizonDays,
    required this.vitalHorizonDays,
    required this.maxScheduled,
  });

  final int horizonDays;
  final int vitalHorizonDays;
  final int maxScheduled;

  /// What [PlannerInput] defaults to (and what iOS gets).
  static const PlannerLimits conservative = PlannerLimits(
    horizonDays: 14,
    vitalHorizonDays: 45,
    maxScheduled: PlannerInput.defaultMaxScheduled,
  );

  static const PlannerLimits android = PlannerLimits(
    horizonDays: 14,
    vitalHorizonDays: 120,
    maxScheduled: 240,
  );

  /// Limits of the platform the app runs on (conservative elsewhere, also
  /// in unit tests).
  static PlannerLimits get current =>
      !kIsWeb && Platform.isAndroid ? android : conservative;
}

/// Fixed wall times of notifications that have no setting of their own.
abstract final class PlannerTimes {
  /// Streak-at-risk nudge (20:00).
  static const int streakRiskMinutes = 20 * 60;

  /// Weekly report on the chosen weekday (18:00).
  static const int weeklyReportMinutes = 18 * 60;
}
