/// ============================================================
/// REMINDER PLANNER — reminder occurrences → planned notifications
/// ============================================================
///
/// What: expands each schedulable reminder into the occurrences that fall
/// in the planning window and describes each one (title, body, buttons,
/// inbox entry).
///
/// Rules (screens 11, 12, 13):
///   • Disabled / completed reminders, and reminders whose linked item is
///     archived, trashed or gone, are never in the input — the repository's
///     `watchSchedulable()` already drops them; we re-check what we can.
///   • The *pending* occurrence ([Reminder.triggerAt]) fires at
///     `snoozedUntil` while snoozed; later occurrences of a repeating rule
///     fire at their own times.
///   • A reminder linked to a task is a "Task due" notification (Tasks
///     switch, Tasks channel, opens the task); everything else obeys the
///     Reminders switch. Alarm-style reminders use the Alarms channel and
///     ignore quiet hours.
///   • Ids: the pending occurrence uses the reminder's stable
///     `notificationId`; later occurrences derive one from their key.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:intl/intl.dart';

abstract final class ReminderPlanner {
  /// Planned notifications for every reminder occurrence in
  /// `(input.now, until)`, before quiet hours and the rolling-window cap.
  static List<PlannedNotification> plan(PlannerInput input, DateTime until) {
    final tasksById = {for (final t in input.tasks) t.id: t};
    final result = <PlannedNotification>[];
    for (final r in input.reminders) {
      if (!_fires(input, r, tasksById)) continue;
      final taskLinked = r.linkedRef?.type == ItemType.task;
      final linkedTask = taskLinked ? tasksById[r.linkedRef!.id] : null;
      for (final (occurrence, fireAt) in slots(r, input.now, until)) {
        result.add(
          _describe(input, r, occurrence, fireAt, taskLinked, linkedTask),
        );
      }
    }
    return result;
  }

  /// Whether the reminder of plan [key] (`rem:<id>:…`) may still fire:
  /// it is schedulable and its switch is on. Used for a request whose fire
  /// time has passed but that the OS has not shown yet.
  static bool stillWanted(PlannerInput input, String key) {
    final parts = key.split(':');
    if (parts.length < 3) return true;
    final r = input.reminders.firstWhereOrNull((r) => r.id == parts[1]);
    if (r == null) return false;
    return _fires(input, r, {for (final t in input.tasks) t.id: t});
  }

  /// Active, enabled, not completed, linked task open, switch on.
  static bool _fires(
    PlannerInput input,
    Reminder r,
    Map<String, TaskItem> tasksById,
  ) {
    if (!r.isActive || !r.isEnabled || r.isCompleted) return false;
    if (r.linkedRef?.type != ItemType.task) {
      return input.settings.notifyReminders;
    }
    // A task-linked reminder of an inactive / completed task never fires.
    final task = tasksById[r.linkedRef!.id];
    if (task != null && (!task.isActive || task.isCompleted)) return false;
    return input.settings.notifyTasks;
  }

  /// `(occurrence, fireAt)` pairs of [r] with `now < fireAt < until`.
  /// `occurrence` is the rule time (stable identity); `fireAt` applies the
  /// snooze to the pending occurrence.
  static List<(DateTime, DateTime)> slots(
    Reminder r,
    DateTime now,
    DateTime until,
  ) {
    if (!r.isEnabled || r.isCompleted) return const [];
    bool inWindow(DateTime t) => t.isAfter(now) && t.isBefore(until);
    final snooze = r.snoozedUntil;
    final snoozed = snooze != null && snooze.isAfter(now);
    final pendingFire = snoozed ? snooze : r.triggerAt;
    final result = <(DateTime, DateTime)>[
      if (inWindow(pendingFire)) (r.triggerAt, pendingFire),
    ];
    final rule = r.recurrence;
    if (rule != null && until.isAfter(now)) {
      for (final t in rule.occurrencesBetween(r.triggerAt, now, until)) {
        if (t.isAtSameMomentAs(r.triggerAt) || !inWindow(t)) continue;
        result.add((t, t));
      }
    }
    return result;
  }

  /// The plan key of one occurrence.
  static String keyFor(String reminderId, DateTime occurrence) =>
      'rem:$reminderId:${occurrence.millisecondsSinceEpoch ~/ 1000}';

  static PlannedNotification _describe(
    PlannerInput input,
    Reminder r,
    DateTime occurrence,
    DateTime fireAt,
    bool taskLinked,
    TaskItem? task,
  ) {
    final key = keyFor(r.id, occurrence);
    final isPending = occurrence.isAtSameMomentAs(r.triggerAt);
    final id = isPending && r.notificationId > 0
        ? r.notificationId
        : notificationIdForKey(key);
    final alarm = r.alertStyle == AlertStyle.alarm;
    final category = alarm
        ? NotificationCategory.alarm
        : taskLinked
        ? NotificationCategory.task
        : NotificationCategory.reminder;
    final title = r.title.trim().isNotEmpty
        ? r.title.trim()
        : (task?.title.trim().isNotEmpty ?? false)
        ? task!.title.trim()
        : 'Reminder';
    final open = taskLinked ? r.linkedRef : (r.linkedRef ?? r.ref);
    return PlannedNotification(
      id: id,
      key: key,
      fireAt: fireAt,
      category: category,
      title: title,
      body: _body(input, r, occurrence, task),
      payload: NotificationPayload(
        key: key,
        category: category,
        target: r.ref,
        open: open,
        snoozeMinutes: r.snoozeMinutes,
      ),
      // Screen 13: "Notification actions: Done, Snooze (default), Open".
      buttons: const [
        NotificationButton.done,
        NotificationButton.snooze,
        NotificationButton.open,
      ],
      inboxActions: const [InboxActions.done, InboxActions.snooze],
      inboxRef: taskLinked ? r.linkedRef : r.ref,
      reminderId: r.id,
      sound: r.sound,
    );
  }

  static String _body(
    PlannerInput input,
    Reminder r,
    DateTime occurrence,
    TaskItem? task,
  ) {
    final note = r.note
        .split('\n')
        .map((l) => l.trim())
        .firstWhereOrNull((l) => l.isNotEmpty);
    if (note != null) {
      return note.length > 140 ? '${note.substring(0, 139)}…' : note;
    }
    final dueDay = task?.dueDate;
    if (task != null && dueDay != null) {
      final diff = DateUtilsX.daysBetween(
        input.calendar.dayOf(occurrence),
        dueDay,
      );
      final day = switch (diff) {
        0 => null,
        1 => 'tomorrow',
        _ => DateFormat('EEE, MMM d').format(dueDay),
      };
      final time = task.dueAt == null || task.dueTimeMinutes == null
          ? null
          : input.formatTime(task.dueAt!);
      if (time == null) return day == null ? 'Due today' : 'Due $day';
      return day == null ? 'Due at $time' : 'Due $day at $time';
    }
    return 'Due at ${input.formatTime(occurrence)}';
  }
}
