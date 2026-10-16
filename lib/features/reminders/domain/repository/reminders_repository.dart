/// ============================================================
/// REMINDERS REPOSITORY (contract)
/// ============================================================
///
/// Lists are streams of [ReminderOccurrence]s so a repeating reminder can
/// appear on several days. Only *active* reminders (not archived / deleted)
/// are returned, and reminders whose linked task / note is archived,
/// trashed or gone are hidden everywhere (they never fire).
///
/// The notification scheduler (core/notifications) listens to
/// [watchSchedulable] and schedules `Reminder.nextFireAfter(now)` for each.
/// Time-relative streams (next, missed, snoozed) are evaluated when the
/// stream (re)computes — refresh the provider on a ticker (e.g. every
/// minute) for countdowns.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';

/// Filter chips of the reminders list (screen 12).
enum RemindersScope {
  /// Occurrences on [RemindersQuery.day] (done + pending), by time.
  today,

  /// Next occurrence of every enabled, not-done reminder after now.
  upcoming,

  /// Repeating reminders (one row each, at their next occurrence).
  recurring,

  /// Reminders with a location trigger.
  location,

  /// Reminders snoozed into the future.
  snoozed,

  /// One-time reminders whose time passed without being done.
  missed,

  /// Every active reminder (one row each), by next time.
  all,
}

@immutable
class RemindersQuery {
  const RemindersQuery({
    this.scope = RemindersScope.today,
    this.day,
    this.now,
    this.text = '',
    this.tagId,
  });

  final RemindersScope scope;

  /// Day for [RemindersScope.today] (default: today).
  final DateTime? day;

  /// Reference instant for upcoming / snoozed / missed (default: now).
  final DateTime? now;

  /// Case-insensitive title / note substring filter.
  final String text;
  final String? tagId;

  @override
  bool operator ==(Object other) =>
      other is RemindersQuery &&
      other.scope == scope &&
      other.day == day &&
      other.now == now &&
      other.text == text &&
      other.tagId == tagId;

  @override
  int get hashCode => Object.hash(scope, day, now, text, tagId);
}

/// The instant of a wall time (calendar day, minutes after midnight) in
/// some time zone (e.g. `ZoneCalendar.at`).
typedef WallClock = DateTime Function(DateTime day, int minutes);

abstract interface class RemindersRepository {
  /// Occurrences for a list scope (see [RemindersScope]), ascending by time.
  Stream<List<ReminderOccurrence>> watchReminders(RemindersQuery query);

  /// One reminder in any lifecycle state (null when gone).
  Stream<Reminder?> watchReminder(String id);
  Future<Reminder?> getReminder(String id);

  /// Creates ([Reminder.isNew]) or updates a reminder and its tags
  /// (from `reminder.tags` names). On create a stable positive 31-bit
  /// `notificationId` is assigned. Returns the id.
  Future<String> save(Reminder reminder);

  Future<void> setEnabled(String id, bool enabled);

  /// Snoozes [occurrence] (default: the pending one) for [minutes]
  /// (default: the reminder's own `snoozeMinutes`): from the occurrence
  /// when it is still ahead, else from now. See [snoozeUntil].
  Future<void> snooze(String id, {int? minutes, DateTime? occurrence});

  /// Snoozes until exactly [until] (sets `snoozedUntil`). [occurrence] =
  /// the occurrence the user acted on (its rule time, as listed). When it
  /// is a later occurrence of a repeating reminder than the pending one
  /// (a stale `triggerAt`), the series is first re-anchored at it (earlier
  /// occurrences skipped, COUNT reduced), so it fires once, at [until].
  Future<void> snoozeUntil(String id, DateTime until, {DateTime? occurrence});

  /// One-time → `completedAt = now`. Repeating → `triggerAt` advances past
  /// the acknowledged occurrence and `completedAt` records it; when the
  /// series is exhausted it becomes a completed one-time reminder. Clears
  /// any snooze. [occurrence] = the occurrence the user acted on: a later
  /// occurrence than the pending one is the one acknowledged (earlier ones
  /// are skipped); null / the pending one → the latest one already due, or
  /// the pending one when marking done early; an occurrence already behind
  /// the pending one → no-op (null). Returns the reminder as it was before
  /// (undo = `save(previous)`), or null when not found / nothing changed.
  Future<Reminder?> markDone(String id, {DateTime? occurrence});

  /// Undoes [markDone] for a one-time reminder (`completedAt = null`).
  Future<void> markUndone(String id);

  /// Moves the pending occurrence to [at]; clears snooze / done state and
  /// enables the reminder.
  Future<void> reschedule(String id, DateTime at);

  /// Records that a notification fired (`lastFiredAt`). Does not advance
  /// a repeating reminder.
  Future<void> markFired(String id, DateTime firedAt);

  /// The soonest upcoming occurrence (after [now]) of any enabled reminder.
  Stream<ReminderOccurrence?> watchNext(DateTime now);

  /// Occurrences on [day] (Home "Up next", calendar agenda).
  Stream<List<ReminderOccurrence>> watchForDay(DateTime day);

  /// Occurrences in [from, to) (calendar month dots / agenda).
  Stream<List<ReminderOccurrence>> watchInRange(DateTime from, DateTime to);

  /// Every active, enabled, not-completed reminder whose linked item (if
  /// any) is active — the notification scheduler's input.
  Stream<List<Reminder>> watchSchedulable();

  /// Creates or updates the reminder linked to [link] (task "Remind me",
  /// note "Set reminder") firing at [at], and stores its id on the linked
  /// task / note (`reminderId`). Returns the reminder id.
  Future<String> upsertLinkedReminder(
    ItemRef link, {
    required String title,
    required DateTime at,
    String? repeatRule,
  });

  /// Deletes the reminder(s) linked to [link] and clears the item's
  /// `reminderId`.
  Future<void> removeLinkedReminder(ItemRef link);

  /// The reminder linked to [link], if any.
  Future<Reminder?> getLinkedReminder(ItemRef link);

  /// Re-derives the trigger instant of every open task's own "Remind me"
  /// reminder from the task's floating due day/time ([TaskItem.reminderWallTime])
  /// in [target] (the planning zone). Only reminders still at the task's
  /// own time — as computed in the device zone or one of the [from] zones
  /// (previous planning zones) — move; snoozed, done or hand-moved ones
  /// are left alone. Returns how many moved.
  Future<int> resyncTaskReminders(
    WallClock target, {
    Iterable<WallClock> from = const [],
  });
}
