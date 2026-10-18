/// ============================================================
/// HABIT PLANNER — check-ins at each habit's times + streak at risk
/// ============================================================
///
/// Check-ins (Habits switch, screen 15 "Remind me" + times): one
/// notification per reminder time on every day the habit is scheduled
/// (HabitSchedule), in the wall-clock zone. Today's check-ins are skipped
/// once the habit is done; their text shows today's progress ("Drink Water
/// — 6/8 · 2 glasses to go"). Paused, archived and deleted habits are not
/// in the input.
///
/// Streak at risk (its own switch): at 20:00 on every day of the window,
/// for build habits scheduled that day, not done / skipped (today), with a
/// streak of 2+ days — projected for later days as if every scheduled day
/// in between is checked in. Planned ahead so it fires even when the app
/// is not opened that day; a check-in (in the app or the notification's
/// Check-in button) re-plans and drops it. Several habits collapse into
/// one summary notification per day.
/// ============================================================
library;

import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';

abstract final class HabitPlanner {
  static List<PlannedNotification> plan(PlannerInput input, DateTime until) => [
    if (input.settings.notifyHabits) ..._checkIns(input, until),
    if (input.settings.notifyStreakRisk) ..._streakRisk(input, until),
  ];

  /// Whether the habit source of plan [key] (`hab:…` / `stk:…`) may still
  /// fire — for a request whose time has passed but that the OS has not
  /// shown yet (cancelled when the habit was checked in, paused, archived).
  static bool stillWanted(PlannerInput input, String key) {
    final parts = key.split(':');
    final todayKey = ZoneCalendar.dayKey(input.today);
    if (parts.first == 'stk') {
      if (!input.settings.notifyStreakRisk) return false;
      return parts.length < 2 ||
          parts[1] != todayKey ||
          _atRisk(input).isNotEmpty;
    }
    if (parts.length < 3) return true;
    if (!input.settings.notifyHabits) return false;
    HabitDayStatus? status;
    for (final s in input.habits) {
      if (s.habit.id == parts[1]) status = s;
    }
    if (status == null) return false;
    final habit = status.habit;
    if (!habit.isActive || habit.isPaused || !habit.reminderEnabled) {
      return false;
    }
    final doneToday = !habit.isQuit && (status.isDone || status.isSkipped);
    return !(parts[2] == todayKey && doneToday);
  }

  static List<PlannedNotification> _checkIns(
    PlannerInput input,
    DateTime until,
  ) {
    final cal = input.calendar;
    final today = input.today;
    final result = <PlannedNotification>[];
    for (final status in input.habits) {
      final habit = status.habit;
      if (!habit.isActive || habit.isPaused || !habit.reminderEnabled) continue;
      final times =
          habit.reminderTimes.map(_parseTime).nonNulls.toSet().toList()..sort();
      if (times.isEmpty) continue;
      for (var day = today; ; day = ZoneCalendar.addDays(day, 1)) {
        if (!cal.at(day, 0).isBefore(until)) break;
        if (!HabitSchedule.isScheduledOn(habit, day)) continue;
        final isToday = day == today;
        if (isToday && !habit.isQuit && (status.isDone || status.isSkipped)) {
          continue;
        }
        for (final minutes in times) {
          final fireAt = cal.at(day, minutes);
          if (!fireAt.isAfter(input.now) || !fireAt.isBefore(until)) continue;
          final dayKey = ZoneCalendar.dayKey(day);
          final key = 'hab:${habit.id}:$dayKey:$minutes';
          result.add(
            PlannedNotification(
              id: notificationIdForKey(key),
              key: key,
              fireAt: fireAt,
              category: NotificationCategory.habit,
              title: _title(status, isToday),
              body: _body(status, isToday),
              payload: NotificationPayload(
                key: key,
                category: NotificationCategory.habit,
                target: habit.ref,
                open: habit.ref,
                day: dayKey,
              ),
              buttons: habit.isQuit
                  ? const []
                  : const [NotificationButton.checkIn],
              inboxRef: habit.ref,
            ),
          );
        }
      }
    }
    return result;
  }

  static String _title(HabitDayStatus s, bool isToday) {
    final h = s.habit;
    final name = h.name.trim().isEmpty ? 'Habit' : h.name.trim();
    if (h.isQuit || h.isYesNo) return name;
    final count = isToday ? s.count : 0;
    return '$name — $count/${h.targetCount}';
  }

  static String _body(HabitDayStatus s, bool isToday) {
    final h = s.habit;
    final streak = isToday ? s.currentStreak : 0;
    if (h.isQuit) {
      return streak > 0
          ? 'Stay strong — $streak ${streak == 1 ? 'day' : 'days'} clean.'
          : 'Stay on track today.';
    }
    final left = h.targetCount - (isToday ? s.count : 0);
    final lead = h.isYesNo || left <= 0
        ? 'Time to check in.'
        : '$left ${h.unit} to go.';
    return streak > 1 ? "$lead You're on a $streak-day streak!" : lead;
  }

  static List<PlannedNotification> _streakRisk(
    PlannerInput input,
    DateTime until,
  ) {
    final cal = input.calendar;
    final eligible = [
      for (final s in input.habits)
        if (_streakEligible(s.habit)) s,
    ];
    // The streak a habit would have on the morning of each later day if
    // today and every scheduled day in between are checked in, kept as a
    // running total while the days are walked once (the projection used to
    // be recounted from today for every day: habits × days² schedule
    // checks).
    final running = [
      for (final s in eligible) s.currentStreak + (_pendingToday(s) ? 1 : 0),
    ];
    final result = <PlannedNotification>[];
    var index = 0;
    for (var day = input.today; ; day = ZoneCalendar.addDays(day, 1), index++) {
      final fireAt = cal.at(day, PlannerTimes.streakRiskMinutes);
      if (!fireAt.isBefore(until)) break;
      final atRisk = <(HabitDayStatus, int)>[];
      for (var k = 0; k < eligible.length; k++) {
        final s = eligible[k];
        final int streak;
        if (index == 0) {
          streak = _pendingToday(s) ? s.currentStreak : 0;
        } else if (HabitSchedule.isScheduledOn(s.habit, day)) {
          streak = running[k];
          running[k]++; // this day, checked in, lengthens the later ones
        } else {
          streak = 0;
        }
        if (streak >= 2) atRisk.add((s, streak));
      }
      if (!fireAt.isAfter(input.now)) continue;
      if (atRisk.isEmpty) continue;
      atRisk.sort((a, b) => b.$2.compareTo(a.$2));
      result.add(_streakNotice(day, fireAt, atRisk));
    }
    return result;
  }

  /// Build habits that can have a streak at risk (active, not paused).
  static bool _streakEligible(Habit h) =>
      h.isActive && !h.isPaused && !h.isQuit;

  /// Scheduled today and neither done nor skipped yet.
  static bool _pendingToday(HabitDayStatus s) =>
      s.isScheduled && !s.isDone && !s.isSkipped;

  /// `(status, streak)` of build habits whose streak is at risk *today*,
  /// longest streak first.
  static List<(HabitDayStatus, int)> _atRisk(PlannerInput input) {
    final result = <(HabitDayStatus, int)>[];
    for (final s in input.habits) {
      if (!_streakEligible(s.habit)) continue;
      final streak = _pendingToday(s) ? s.currentStreak : 0;
      if (streak >= 2) result.add((s, streak));
    }
    return result..sort((a, b) => b.$2.compareTo(a.$2));
  }

  static PlannedNotification _streakNotice(
    DateTime day,
    DateTime fireAt,
    List<(HabitDayStatus, int)> atRisk,
  ) {
    final dayKey = ZoneCalendar.dayKey(day);
    final key = 'stk:$dayKey';
    final single = atRisk.length == 1 ? atRisk.first : null;
    final names = atRisk.map((r) => r.$1.habit.name.trim()).join(', ');
    final habit = single?.$1.habit;
    return PlannedNotification(
      id: notificationIdForKey(key),
      key: key,
      fireAt: fireAt,
      category: NotificationCategory.streak,
      title: single != null
          ? 'Your ${single.$2}-day ${habit!.name.trim()} streak is at risk'
          : '${atRisk.length} streaks at risk',
      body: single != null
          ? 'Check in before the day ends to keep it going.'
          : '$names — check in before the day ends.',
      payload: NotificationPayload(
        key: key,
        category: NotificationCategory.streak,
        target: habit?.ref,
        open: habit?.ref,
        route: single == null ? AppRoutes.habits : null,
        day: dayKey,
      ),
      buttons: single == null ? const [] : const [NotificationButton.checkIn],
      inboxRef: habit?.ref,
    );
  }

  /// `HH:mm` → minutes after midnight (null when malformed).
  static int? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }
}
