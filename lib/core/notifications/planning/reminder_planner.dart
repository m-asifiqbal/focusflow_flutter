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

abstract final class ReminderPlanner {
  /// Planned notifications for every reminder occurrence in
  /// `(input.now, until)`, before quiet hours and the rolling-window cap.
  /// A reminder's *next* occurrence is planned up to [pendingUntil]
  /// (default [until]) — see [PlannerInput.vitalHorizonDays].
  static List<PlannedNotification> plan(
    PlannerInput input,
    DateTime until, {
    DateTime? pendingUntil,
  }) {
    final tasksById = {for (final t in input.tasks) t.id: t};
    final result = <PlannedNotification>[];
    for (final r in input.reminders) {
      if (!_fires(input, r, tasksById)) continue;
      final taskLinked = r.linkedRef?.type == ItemType.task;
      final linkedTask = taskLinked ? tasksById[r.linkedRef!.id] : null;
      for (final (occurrence, fireAt) in slots(
        r,
        input.now,
        until,
        pendingUntil: pendingUntil,
      )) {
        result.add(
          _describe(input, r, occurrence, fireAt, taskLinked, linkedTask),
        );
      }
      result.addAll(
        _repeats(input, r, taskLinked, linkedTask, pendingUntil ?? until),
      );
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
  /// snooze to the pending occurrence. The pending occurrence (the one
  /// that fires next) may lie up to [pendingUntil] ahead (default
  /// [until]): later occurrences of a repeating rule stay inside [until].
  static List<(DateTime, DateTime)> slots(
    Reminder r,
    DateTime now,
    DateTime until, {
    DateTime? pendingUntil,
  }) {
    if (!r.isEnabled || r.isCompleted) return const [];
    bool inWindow(DateTime t) => t.isAfter(now) && t.isBefore(until);
    final snooze = r.snoozedUntil;
    final snoozed = snooze != null && snooze.isAfter(now);
    final pendingFire = snoozed ? snooze : r.triggerAt;
    final pendingEnd = pendingUntil != null && pendingUntil.isAfter(until)
        ? pendingUntil
        : until;
    final result = <(DateTime, DateTime)>[
      if (pendingFire.isAfter(now) && pendingFire.isBefore(pendingEnd))
        (r.triggerAt, pendingFire),
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

  /// A plan key of a "repeat until done" copy: `rem:<id>:<epoch>:r<n>`.
  static bool isRepeatKey(String key) => key.split(':').length > 3;

  /// "Repeat until done" (Settings › Notifications): a reminder that is
  /// still open — not done, not archived — is shown again every
  /// `repeatIntervalMinutes`, up to `repeatCount` times, counted from its
  /// pending time (the snooze, once snoozed). Marking it done, snoozing or
  /// switching it off drops the copies at the next pass (they are plain plan
  /// entries). Alarm-style reminders keep ringing by themselves and are
  /// left out; a repeating reminder's copies stop before its next
  /// occurrence. Copies carry no inbox entry of their own.
  static List<PlannedNotification> _repeats(
    PlannerInput input,
    Reminder r,
    bool taskLinked,
    TaskItem? task,
    DateTime until,
  ) {
    final every = input.settings.repeatIntervalMinutes;
    if (every <= 0 || r.alertStyle == AlertStyle.alarm) return const [];
    final snooze = r.snoozedUntil;
    final base = snooze != null && snooze.isAfter(input.now)
        ? snooze
        : r.triggerAt;
    final limit = r.recurrence?.nextAfter(r.triggerAt, r.triggerAt);
    final out = <PlannedNotification>[];
    for (var k = 1; k <= input.settings.repeatCount; k++) {
      final at = base.add(Duration(minutes: every * k));
      if (!at.isAfter(input.now)) continue;
      if (!at.isBefore(until) || (limit != null && !at.isBefore(limit))) break;
      final first = _describe(input, r, r.triggerAt, at, taskLinked, task);
      final key = '${first.key}:r$k';
      out.add(
        first.copyWith(key: key, id: notificationIdForKey(key), inbox: false),
      );
    }
    return out;
  }

  /// The "missed" copy of the reminder occurrence behind plan [key]
  /// (`rem:<id>:<epoch seconds>`), to show right now ([at]) when the OS
  /// never delivered it (its alarm was wiped by a force-stop / an OEM
  /// task killer). Rebuilt from current data, so nothing but the plan key
  /// has to be remembered. Null when [key] is not a reminder's or the
  /// reminder no longer fires.
  ///
  /// An alarm-style reminder comes back as a plain heads-up: a full-screen,
  /// insistent alarm hours late would only startle.
  static PlannedNotification? missed(
    PlannerInput input,
    String key, {
    required DateTime at,
  }) {
    final parts = key.split(':');
    if (parts.length < 3 || parts[0] != 'rem') return null;
    // A lost repeat is not worth a "Missed" of its own (its first alert was).
    if (isRepeatKey(key)) return null;
    final seconds = int.tryParse(parts[2]);
    final r = input.reminders.firstWhereOrNull((r) => r.id == parts[1]);
    if (seconds == null || r == null) return null;
    final tasksById = {for (final t in input.tasks) t.id: t};
    if (!_fires(input, r, tasksById)) return null;
    final occurrence = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final taskLinked = r.linkedRef?.type == ItemType.task;
    final base = _describe(
      input,
      r,
      occurrence,
      at,
      taskLinked,
      taskLinked ? tasksById[r.linkedRef!.id] : null,
    );
    final note = _noteLine(r);
    return base.copyWith(
      category: base.category == NotificationCategory.alarm
          ? (taskLinked
                ? NotificationCategory.task
                : NotificationCategory.reminder)
          : null,
      body:
          'Missed · was due at ${input.formatTime(occurrence)}'
          '${note == null ? '' : ' · $note'}',
    );
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

  /// First non-empty line of the reminder's note, clipped for a
  /// notification (null = no note).
  static String? _noteLine(Reminder r) {
    final note = r.note
        .split('\n')
        .map((l) => l.trim())
        .firstWhereOrNull((l) => l.isNotEmpty);
    if (note == null) return null;
    return note.length > 140 ? '${note.substring(0, 139)}…' : note;
  }

  static String _body(
    PlannerInput input,
    Reminder r,
    DateTime occurrence,
    TaskItem? task,
  ) {
    final note = _noteLine(r);
    if (note != null) return note;
    final dueDay = task?.dueDate;
    if (task != null && dueDay != null) {
      final diff = DateUtilsX.daysBetween(
        input.calendar.dayOf(occurrence),
        dueDay,
      );
      final day = switch (diff) {
        0 => null,
        1 => 'tomorrow',
        _ => DateFormats.of('EEE, MMM d').format(dueDay),
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
