/// ============================================================
/// REMINDER FLOWS — UI flows around reminder writes (snackbars, sheets)
/// ============================================================
///
/// What: snooze (with Undo), mark done (with the 5 s Undo snackbar),
/// enable / disable, reschedule a missed reminder (date + time sheets)
/// and the notification-permission prompt. The list rows, swipe actions
/// and the long-press sheet (reminder_item_actions.dart) all call these.
/// Why: CLAUDE.md rule 3 (Undo for destructive actions) and rule 5
/// (widgets only trigger flows; writes live in [ReminderActions]).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/alarm_overlay.dart';
import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_actions.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/due_date_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/time_sheet.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

String _quoted(String title) =>
    title.trim().isEmpty ? tr('Reminder') : '"${title.trim()}"';

/// Snoozes [occurrence] of [r] (the tapped row; default: its current
/// occurrence) for [minutes] and shows "Snoozed for 10 min · UNDO".
Future<void> snoozeReminder(
  BuildContext context,
  WidgetRef ref,
  Reminder r, {
  int minutes = ReminderActions.defaultSnoozeMinutes,
  DateTime? occurrence,
}) async {
  final actions = ref.read(reminderActionsProvider);
  final before = await actions.snooze(
    r.id,
    minutes: minutes,
    occurrence: occurrence,
  );
  if (before == null || !context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('{v} snoozed for {minutes} min', {
      'v': _quoted(r.title),
      'minutes': minutes,
    }),
    icon: FontAwesomeIcons.solidClock,
    onUndo: () => actions.restore(before),
  );
}

/// Marks [occurrence] of [r] (the tapped row; default: the pending one)
/// done, with Undo. Same function as the notification's Done: a one-time
/// reminder linked to a task completes the task too (Undo reopens it).
Future<void> markReminderDone(
  BuildContext context,
  WidgetRef ref,
  Reminder r, {
  DateTime? occurrence,
}) async {
  final actions = ref.read(reminderActionsProvider);
  final done = await actions.complete(r.id, occurrence: occurrence);
  if (done == null || !context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('{v} done', {'v': _quoted(r.title)}),
    icon: FontAwesomeIcons.solidCircleCheck,
    onUndo: () => actions.undoComplete(done),
  );
}

/// Turns [r] on or off (the row's toggle / "Disable" in the sheet).
Future<void> setReminderEnabled(WidgetRef ref, Reminder r, bool enabled) =>
    ref.read(reminderActionsProvider).setEnabled(r.id, enabled);

/// Asks for a new date and time for [r] (missed reminders) and moves it,
/// with Undo. Returns true when it was moved.
Future<bool> rescheduleReminder(
  BuildContext context,
  WidgetRef ref,
  Reminder r,
) async {
  final settings = ref.read(settingsProvider);
  final now = ref.read(clockProvider).now();
  final day = await showDueDateSheet(
    context,
    today: now,
    weekStartsOn: settings.weekStartsOn,
    current: DateUtilsX.dateOnly(now),
    title: tr('Reschedule'),
    subtitle: r.title.trim().isEmpty ? null : r.title.trim(),
    allowNoDate: false,
  );
  final date = day?.value;
  if (date == null || !context.mounted) return false;
  final current = r.triggerAt.hour * 60 + r.triggerAt.minute;
  final time = await showTimeSheet(
    context,
    current: current,
    use24h: settings.use24HourTime,
    allowAllDay: false,
  );
  if (time == null || !context.mounted) return false;
  final at = DateUtilsX.atMinutes(date, time.value ?? current);
  final actions = ref.read(reminderActionsProvider);
  final before = await actions.reschedule(r.id, at);
  if (before == null || !context.mounted) return false;
  showUndoSnackbar(
    context,
    message: tr('{v} moved to {relativeDay} {time}', {
      'v': _quoted(r.title),
      'relativeDay': DateUtilsX.relativeDay(at, now),
      'time': DateUtilsX.time(at, use24h: settings.use24HourTime),
    }),
    icon: FontAwesomeIcons.calendarDays,
    onUndo: () => actions.restore(before),
  );
  return true;
}

/// "Notifications are off — Enable": asks the OS again (the engine
/// invalidates [notificationPermissionProvider]).
Future<NotificationPermission> enableReminderNotifications(WidgetRef ref) =>
    ref.read(reminderPermissionRequestProvider)();

/// "Reminders may be late — Allow": opens Android's "Alarms & reminders"
/// page; the engine re-plans with exact timing when the user comes back.
Future<ExactAlarmPermission> allowExactAlarms(WidgetRef ref) =>
    ref.read(exactAlarmRequestProvider)();

/// "Full-screen alarms are off — Allow" (Android 14+).
Future<bool> allowFullScreenAlarms(WidgetRef ref) =>
    ref.read(fullScreenAlarmRequestProvider)();

/// "Allow reminders in the background — Allow" (Android battery
/// optimisation; opt-in, asked once from the editor).
Future<bool?> allowRemindersInBackground(WidgetRef ref) =>
    ref.read(backgroundDeliveryRequestProvider)();

/// "Let alarms appear over other apps — Allow": opens the system page for
/// "Display over other apps"; the state is re-read when the app resumes.
Future<void> allowAlarmOverApps(WidgetRef ref) =>
    ref.read(alarmOverAppsRequestProvider)();

/// "On [brand] phones, allow auto-start — Open": the maker's auto-start /
/// background screen (or the app's info page when the phone has none we
/// know).
Future<bool> allowAutostart(WidgetRef ref) =>
    ref.read(autostartRequestProvider)();
