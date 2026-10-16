/// ============================================================
/// NOTIFICATION ACTIONS — Done / Snooze / Check in, and tap targets
/// ============================================================
///
/// What: the logic behind a notification's action buttons, shared by the
/// foreground handler, the background isolate and the notification centre's
/// inline buttons (screen 27: "Actions perform the same logic as system
/// notification actions").
///
///   • Done    — reminder: [CompleteReminder] on the notified occurrence
///               (repeating → next occurrence; a one-time reminder linked
///               to a task completes the task too — the same function the
///               reminders list uses).
///   • Snooze  — reminder: `snooze(minutes)` of the notified occurrence
///               (its own length, else the Settings default), from now.
///   • Open    — handled by the engine like a body tap (no write here).
///   • Check in — habit: one check-in on the notification's day.
///
/// Items that are archived, deleted or gone are ignored (a stale
/// notification never resurrects an item). [tapRoute] maps a body tap to
/// the route to open.
/// ============================================================
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';

class NotificationActions {
  const NotificationActions({
    required this.reminders,
    required this.tasks,
    required this.habits,
    required this.clock,
    required this.defaultSnoozeMinutes,
  });

  final RemindersRepository reminders;
  final TasksRepository tasks;
  final HabitsRepository habits;
  final Clock clock;
  final int defaultSnoozeMinutes;

  /// Performs [button] for [payload]. Returns true when something changed.
  Future<bool> perform(
    NotificationButton button,
    NotificationPayload payload,
  ) async {
    final target = payload.target;
    if (target == null) return false;
    try {
      return switch (button) {
        NotificationButton.done => await markDone(
          target,
          occurrence: occurrenceOf(payload.key),
        ),
        NotificationButton.snooze => await snooze(
          target,
          minutes: payload.snoozeMinutes,
          occurrence: occurrenceOf(payload.key),
        ),
        NotificationButton.open => false,
        NotificationButton.checkIn => await checkIn(
          target,
          day: _day(payload.day),
        ),
      };
    } catch (e) {
      AppLogger.w('Notification action ${button.id} failed: $e');
      return false;
    }
  }

  /// Marks a reminder [occurrence] (and its linked one-time task) done.
  Future<bool> markDone(ItemRef target, {DateTime? occurrence}) async {
    if (target.type == ItemType.task) {
      final t = await tasks.getTask(target.id);
      if (t == null || !t.isActive || t.isCompleted) return false;
      await tasks.complete(t.id);
      return true;
    }
    if (target.type != ItemType.reminder) return false;
    final done = await CompleteReminder(reminders: reminders, tasks: tasks)(
      target.id,
      occurrence: occurrence,
    );
    return done != null;
  }

  /// Snoozes a reminder by [minutes] (default: its own / the setting).
  Future<bool> snooze(
    ItemRef target, {
    int? minutes,
    DateTime? occurrence,
  }) async {
    if (target.type != ItemType.reminder) return false;
    final r = await reminders.getReminder(target.id);
    if (r == null || !r.isActive || r.isCompleted) return false;
    final m = minutes ?? (r.snoozeMinutes > 0 ? r.snoozeMinutes : null);
    // The notified occurrence has fired: counts from now.
    await reminders.snoozeUntil(
      r.id,
      clock.now().add(Duration(minutes: m ?? defaultSnoozeMinutes)),
      occurrence: occurrence,
    );
    return true;
  }

  /// The occurrence (rule time) of a reminder plan key
  /// `rem:<id>:<epochSeconds>`; null for other keys.
  static DateTime? occurrenceOf(String key) {
    final parts = key.split(':');
    if (parts.length != 3 || parts[0] != 'rem') return null;
    final s = int.tryParse(parts[2]);
    return s == null ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }

  /// Logs one check-in for a habit on [day] (default: today).
  Future<bool> checkIn(ItemRef target, {DateTime? day}) async {
    if (target.type != ItemType.habit) return false;
    final h = await habits.getHabit(target.id);
    if (h == null || !h.isActive || h.isPaused) return false;
    await habits.increment(h.id, day ?? DateUtilsX.dateOnly(clock.now()));
    return true;
  }

  /// The route a body tap opens (item first, then the payload's route).
  static String? tapRoute(NotificationPayload? payload) {
    if (payload == null) return null;
    final open = payload.open ?? payload.target;
    if (open != null) return AppRoutes.open(open);
    return payload.route;
  }

  static DateTime? _day(String? key) {
    if (key == null) return null;
    final p = key.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]),
        m = int.tryParse(p[1]),
        d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
