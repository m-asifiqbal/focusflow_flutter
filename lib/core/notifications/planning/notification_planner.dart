/// ============================================================
/// NOTIFICATION PLANNER — pure "what should be scheduled?" function
/// ============================================================
///
/// `NotificationPlanner.plan(input)` turns a snapshot of reminders, tasks,
/// habits and settings into the exact list of OS notifications that should
/// be pending right now:
///
///   1. Master switch off → nothing.
///   2. Reminder occurrences, habit check-ins, streak at risk, overdue
///      tasks and digests in the window `(now, today + horizonDays)`.
///   3. Quiet hours delay every non-alarm notification to the window's end.
///   4. Each notification gets the predicted app-icon badge of its day.
///   5. Rolling window: at most [maxCount] survive (iOS keeps at most 64
///      pending requests, Android 500 alarms). Reminders, alarms and task
///      alerts ([isVital]) take their slots first, soonest first; habit
///      nudges and digests fill what is left. The engine re-plans on resume
///      and whenever one fires, so later ones move in as earlier ones are
///      delivered. A reminder's next occurrence is planned up to
///      `vitalHorizonDays` ahead, further than the routine `horizonDays`,
///      because with the app closed nothing rolls the window forward.
///   6. Ids are made unique (a derived id never collides with another).
///
/// No I/O, no plugins, no `DateTime.now()` — deterministic for tests.
/// ============================================================
library;

import 'package:focusflow/core/notifications/planning/digest_planner.dart';
import 'package:focusflow/core/notifications/planning/habit_planner.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/reminder_planner.dart';
import 'package:focusflow/core/notifications/planning/task_day_index.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';

abstract final class NotificationPlanner {
  /// iOS allows 64 pending requests; keep a few free for immediate ones.
  static const int defaultMaxCount = 60;

  /// The notifications to keep scheduled, soonest first. [until] overrides
  /// the end of the window (default: midnight `horizonDays` from today);
  /// [maxCount] null disables the cap (used to replay deliveries).
  static List<PlannedNotification> plan(
    PlannerInput input, {
    DateTime? until,
    int? maxCount = defaultMaxCount,
  }) {
    if (!input.settings.notificationsEnabled) return const [];
    DateTime windowEnd(int days) =>
        input.calendar.at(ZoneCalendar.addDays(input.today, days), 0);
    final end = until ?? windowEnd(input.horizonDays);
    final vitalEnd = until ?? windowEnd(input.vitalHorizonDays);
    // One sorted view of the tasks answers every overdue / due-today
    // question below (digests and badges) — see TaskDayIndex.
    final tasks = TaskDayIndex(input.tasks);
    final raw = [
      ...ReminderPlanner.plan(input, end, pendingUntil: vitalEnd),
      ...HabitPlanner.plan(input, end),
      ...DigestPlanner.plan(input, end, tasks: tasks),
    ];

    final quiet = input.quietHours;
    PlannedNotification? shape(PlannedNotification n) {
      final fireAt = quiet == null || n.category.bypassesQuietHours
          ? n.fireAt
          : quiet.delay(n.fireAt, input.calendar);
      // A "repeat until done" copy inside quiet hours is dropped, not pushed
      // to the window's end — they would all pile up there at once.
      if (fireAt != n.fireAt && ReminderPlanner.isRepeatKey(n.key)) {
        return null;
      }
      return fireAt == n.fireAt ? n : n.copyWith(fireAt: fireAt);
    }

    final shaped = [for (final n in raw) ?shape(n)]..sort(_order);

    return _withBadges(_uniqueIds(_cap(shaped, maxCount)), input, tasks);
  }

  /// Gives each notification the app-icon badge predicted for the day it
  /// fires. Done last, on the notifications that survived the cap (the
  /// badge changes neither order nor cap), with one lookup per distinct day
  /// instead of one per notification.
  static List<PlannedNotification> _withBadges(
    List<PlannedNotification> list,
    PlannerInput input,
    TaskDayIndex tasks,
  ) {
    final mode = input.settings.badgeMode;
    final byDay = <int, int?>{};
    return [
      for (final n in list)
        n.copyWith(
          badge: () {
            final day = input.calendar.dayNumberOf(n.fireAt);
            return byDay.putIfAbsent(day, () => tasks.badgeOn(day, mode));
          }(),
        ),
    ];
  }

  /// Reminders, alarms and task alerts — what the user explicitly set up
  /// and cannot afford to lose. Habit nudges, streak warnings and digests
  /// are routine.
  static bool isVital(PlannedNotification n) =>
      switch (n.category) {
        NotificationCategory.reminder ||
        NotificationCategory.alarm ||
        NotificationCategory.task => true,
        _ => false,
      } &&
      // A repeat of a reminder is a nicety: it never takes a slot from one.
      !ReminderPlanner.isRepeatKey(n.key);

  /// Keeps at most [maxCount] of [sorted] (soonest first). Vital ones take
  /// their slots first, the routine ones fill what is left — a daily
  /// digest plus a few habit nudges would otherwise use up the whole cap
  /// within days and push a reminder set for next week out of the plan,
  /// which with the app closed nothing would ever bring back.
  static List<PlannedNotification> _cap(
    List<PlannedNotification> sorted,
    int? maxCount,
  ) {
    if (maxCount == null || sorted.length <= maxCount) return sorted;
    final vital = <PlannedNotification>[];
    final routine = <PlannedNotification>[];
    for (final n in sorted) {
      (isVital(n) ? vital : routine).add(n);
    }
    if (vital.length >= maxCount) return vital.sublist(0, maxCount);
    final room = maxCount - vital.length;
    // Merge the two (each sorted) back into one soonest-first list.
    final keep = {...vital, ...routine.take(room)};
    return [
      for (final n in sorted)
        if (keep.contains(n)) n,
    ];
  }

  /// Whether the source of plan [key] may still fire. For a request whose
  /// fire time has passed but that the OS has not shown yet (late inexact
  /// alarm): false when its reminder / habit was completed, checked in,
  /// archived or switched off meanwhile, so the reconciler cancels it.
  /// Digests and summaries stay wanted while notifications are on.
  static bool stillWanted(PlannerInput input, String key) {
    if (!input.settings.notificationsEnabled) return false;
    if (key.startsWith('rem:')) return ReminderPlanner.stillWanted(input, key);
    if (key.startsWith('hab:') || key.startsWith('stk:')) {
      return HabitPlanner.stillWanted(input, key);
    }
    return true;
  }

  /// The "Missed" copy of the request behind plan [key], to show at [at]
  /// when the OS never delivered it. Only reminders and task alerts have
  /// one (a habit nudge or digest hours late is noise); null when the
  /// source no longer wants to fire.
  static PlannedNotification? missed(
    PlannerInput input,
    String key, {
    required DateTime at,
  }) {
    if (!input.settings.notificationsEnabled || !key.startsWith('rem:')) {
      return null;
    }
    return ReminderPlanner.missed(input, key, at: at);
  }

  /// Soonest first; ties by category importance, then key (stable).
  static int _order(PlannedNotification a, PlannedNotification b) {
    final t = a.fireAt.compareTo(b.fireAt);
    if (t != 0) return t;
    final p = a.category.priority.compareTo(b.category.priority);
    return p != 0 ? p : a.key.compareTo(b.key);
  }

  /// A reminder's pending occurrence keeps its stored id (the reminders
  /// list and the editor know it); every other id is derived from its key
  /// and steps aside (+1) on a clash, so no two notifications share an id.
  static List<PlannedNotification> _uniqueIds(List<PlannedNotification> list) {
    bool isFixed(PlannedNotification n) =>
        n.reminderId != null && n.id != notificationIdForKey(n.key);
    final fixed = {for (final n in list.where(isFixed)) n.id};
    final used = <int>{};
    final result = <PlannedNotification>[];
    for (final n in list) {
      var id = n.id;
      final clash = isFixed(n)
          ? used.contains(id)
          : fixed.contains(id) || used.contains(id);
      if (clash) {
        do {
          id = id >= 0x7FFFFFFF ? 1 : id + 1;
        } while (used.contains(id) ||
            fixed.contains(id) ||
            id == reservedNotificationId);
      }
      used.add(id);
      result.add(id == n.id ? n : n.copyWith(id: id));
    }
    return result;
  }
}
