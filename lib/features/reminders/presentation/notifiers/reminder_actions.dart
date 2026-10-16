/// ============================================================
/// REMINDER ACTIONS — the writes behind the reminders list (screen 12)
/// ============================================================
///
/// What: enable / disable, snooze, mark done, reschedule — each returning
/// what Undo needs (the reminder as it was before).
/// Why: CLAUDE.md rule 5 (no business logic in widgets). These only write
/// the database; the NotificationEngine watches the repository and
/// (re)schedules or cancels the OS notifications — the UI never schedules
/// anything itself.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

class ReminderActions {
  const ReminderActions(this._repo, this._clock, this._complete);

  final RemindersRepository _repo;
  final Clock _clock;
  final CompleteReminder _complete;

  /// Default "SNOOZE 10m" length.
  static const int defaultSnoozeMinutes = 10;

  Future<void> setEnabled(String id, bool enabled) =>
      _repo.setEnabled(id, enabled);

  /// Snoozes [occurrence] of [id] (the row the user acted on; default:
  /// the reminder's current occurrence) for [minutes]; returns the
  /// reminder before (for Undo).
  ///
  /// The snooze counts from the occurrence, or from now if it is already
  /// due: snoozing "Call the bank" (10:00) at 9:35 moves it to 10:10.
  /// Counting from now would pull a future reminder *earlier*; counting
  /// from a stale `triggerAt` of a repeating reminder would too.
  Future<Reminder?> snooze(
    String id, {
    int minutes = defaultSnoozeMinutes,
    DateTime? occurrence,
  }) async {
    final before = await _repo.getReminder(id);
    if (before == null) return null;
    final now = _clock.now();
    final at = occurrence ?? ReminderSchedule.current(before, now).at;
    await _repo.snoozeUntil(
      id,
      snoozeTarget(before, now, minutes, occurrence: at),
      occurrence: at,
    );
    return before;
  }

  /// When a snooze of [minutes] on [occurrence] of [r] (default: its
  /// current occurrence, see [ReminderSchedule.current]) at [now] should
  /// fire: `max(now, occurrence) + minutes`.
  static DateTime snoozeTarget(
    Reminder r,
    DateTime now,
    int minutes, {
    DateTime? occurrence,
  }) {
    final due = occurrence ?? ReminderSchedule.current(r, now).at;
    final base = due.isAfter(now) ? due : now;
    return base.add(Duration(minutes: minutes));
  }

  /// Marks [occurrence] (default: the pending one) done — the same
  /// function as the notification's Done (a one-time reminder linked to a
  /// task completes the task too). Null when nothing changed.
  Future<ReminderDone?> complete(String id, {DateTime? occurrence}) =>
      _complete(id, occurrence: occurrence);

  /// Undo for [complete].
  Future<void> undoComplete(ReminderDone done) => _complete.undo(done);

  /// Marks the pending occurrence done; returns the reminder before.
  Future<Reminder?> markDone(String id, {DateTime? occurrence}) async =>
      (await complete(id, occurrence: occurrence))?.before;

  /// Moves the pending occurrence to [at]; returns the reminder before.
  Future<Reminder?> reschedule(String id, DateTime at) async {
    final before = await _repo.getReminder(id);
    if (before == null) return null;
    await _repo.reschedule(id, at);
    return before;
  }

  /// Undo for [snooze] / [markDone] / [reschedule]: writes [before] back.
  Future<void> restore(Reminder before) => _repo.save(before);
}

/// Asks for notification permission from widgets (the contract takes a
/// provider [Ref], which a WidgetRef can't supply).
final reminderPermissionRequestProvider =
    Provider<Future<NotificationPermission> Function()>(
      (ref) =>
          () => requestNotificationPermission(ref),
    );

final reminderActionsProvider = Provider<ReminderActions>(
  (ref) => ReminderActions(
    ref.watch(remindersRepositoryProvider),
    ref.watch(clockProvider),
    CompleteReminder(
      reminders: ref.watch(remindersRepositoryProvider),
      tasks: ref.watch(tasksRepositoryProvider),
    ),
  ),
);

/// Opens the system "Alarms & reminders" page (Android 12+).
final exactAlarmRequestProvider =
    Provider<Future<ExactAlarmPermission> Function()>(
      (ref) =>
          () => requestExactAlarmPermission(ref),
    );

/// Asks for full-screen alarms (Android 14+) when alarm-style is chosen.
final fullScreenAlarmRequestProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () => requestFullScreenAlarms(ref),
);
