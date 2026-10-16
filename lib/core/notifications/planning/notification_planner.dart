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
///   5. Rolling window: the soonest [maxCount] survive (iOS keeps at most
///      64 pending requests) — the engine re-plans on resume and whenever
///      one fires, so later ones move in as earlier ones are delivered.
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
    final end =
        until ??
        input.calendar.at(
          ZoneCalendar.addDays(input.today, input.horizonDays),
          0,
        );
    final raw = [
      ...ReminderPlanner.plan(input, end),
      ...HabitPlanner.plan(input, end),
      ...DigestPlanner.plan(input, end),
    ];

    final quiet = input.quietHours;
    final mode = input.settings.badgeMode;
    final shaped = [
      for (final n in raw)
        () {
          final fireAt = quiet == null || n.category.bypassesQuietHours
              ? n.fireAt
              : quiet.delay(n.fireAt, input.calendar);
          return n.copyWith(
            fireAt: fireAt,
            badge: DigestPlanner.badgeOn(
              input.tasks,
              input.calendar.dayOf(fireAt),
              mode,
            ),
          );
        }(),
    ]..sort(_order);

    final capped = maxCount == null || shaped.length <= maxCount
        ? shaped
        : shaped.sublist(0, maxCount);
    return _uniqueIds(capped);
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
