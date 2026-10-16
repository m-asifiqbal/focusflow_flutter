/// ============================================================
/// REMINDER EDITOR CONTROLLER — form logic of screen 13
/// ============================================================
///
/// What: loads the reminder (or builds a prefilled draft for
/// `/reminders/new?title&at&rrule&linkType&linkId`), applies every edit to
/// an in-memory [ReminderEditorState] and writes it on [save] through
/// `RemindersRepository.save`. The NotificationEngine watches the
/// repository and (re)schedules the OS notification — nothing here talks
/// to the notification plugin.
/// Why: Cancel must be able to throw edits away, and the rules (keep the
/// time when the day changes, re-anchor a weekly repeat, defaults from
/// Settings) stay out of the widgets.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Thrown by the editor when `/reminders/:id` no longer exists.
class ReminderNotFoundException implements Exception {
  const ReminderNotFoundException();

  @override
  String toString() => 'This reminder no longer exists';
}

class ReminderEditorController
    extends
        AutoDisposeFamilyAsyncNotifier<
          ReminderEditorState,
          ReminderEditorArgs
        > {
  @override
  Future<ReminderEditorState> build(ReminderEditorArgs arg) async {
    if (arg.isNew) return _newDraft(arg);
    final r = await ref.read(remindersRepositoryProvider).getReminder(arg.id!);
    if (r == null) throw const ReminderNotFoundException();
    return ReminderEditorState(original: r, draft: r);
  }

  Future<ReminderEditorState> _newDraft(ReminderEditorArgs arg) async {
    final now = ref.read(clockProvider).now();
    final settings = ref.read(settingsProvider);
    // Default: the next full hour (9:41 → 10:00).
    final at = arg.at ?? DateTime(now.year, now.month, now.day, now.hour + 1);
    final link = arg.link;
    final r =
        Reminder.draft(
          triggerAt: DateTime(at.year, at.month, at.day, at.hour, at.minute),
          title: arg.title ?? '',
          repeatRule: RecurrenceRule.tryParse(arg.repeatRule)?.toRRule(),
          linkedRef: link,
        ).copyWith(
          sound: settings.remindersDefaultSound,
          snoozeMinutes: settings.defaultSnoozeMinutes,
          linkedTitle: link == null ? null : await _titleOf(link),
          createdAt: now,
          updatedAt: now,
        );
    return ReminderEditorState(original: r, draft: r);
  }

  /// Title of a linked task / note (null when gone or another type).
  Future<String?> _titleOf(ItemRef link) async => switch (link.type) {
    ItemType.task =>
      (await ref.read(tasksRepositoryProvider).getTask(link.id))?.title,
    ItemType.note =>
      (await ref.read(notesRepositoryProvider).getNote(link.id))?.displayTitle,
    _ => null,
  };

  ReminderEditorState? get _form => state.valueOrNull;

  void _draft(Reminder Function(Reminder r) change) {
    final s = _form;
    if (s == null) return;
    state = AsyncData(s.copyWith(draft: change(s.draft)));
  }

  // ───────────────────────── Fields ─────────────────────────

  void setTitle(String title) => _draft((r) => r.copyWith(title: title));

  void setNote(String note) => _draft((r) => r.copyWith(note: note));

  /// Moves the reminder to [day], keeping its time. A weekly repeat on the
  /// old weekday follows the new day.
  void setDay(DateTime day) => _draft((r) {
    final minutes = r.triggerAt.hour * 60 + r.triggerAt.minute;
    final at = DateUtilsX.atMinutes(DateUtilsX.dateOnly(day), minutes);
    final oldWeekly = RepeatPreset.weekly.rule(r.triggerAt);
    final rule = r.repeatRule != null && r.repeatRule == oldWeekly
        ? RepeatPreset.weekly.rule(at)
        : r.repeatRule;
    return r.copyWith(triggerAt: at, repeatRule: rule);
  });

  /// New time of day (minutes after midnight) on the same day.
  void setTime(int minutes) => _draft(
    (r) => r.copyWith(
      triggerAt: DateUtilsX.atMinutes(
        DateUtilsX.dateOnly(r.triggerAt),
        minutes.clamp(0, 24 * 60 - 1),
      ),
    ),
  );

  /// RRULE text; null = once.
  void setRepeat(String? rrule) => _draft(
    (r) => rrule == null
        ? r.copyWith(clearRepeatRule: true)
        : r.copyWith(repeatRule: rrule),
  );

  void setSound(String key) => _draft((r) => r.copyWith(sound: key));

  /// Alarm-style (full-screen intent / time-sensitive) on or off. Turning
  /// it on asks for full-screen intents where Android 14+ denies them (the
  /// editor shows a hint while they stay off: the alarm then degrades to a
  /// heads-up notification).
  void setAlarm(bool alarm) {
    _draft(
      (r) => r.copyWith(
        alertStyle: alarm ? AlertStyle.alarm : AlertStyle.notification,
      ),
    );
    if (alarm) unawaited(_askFullScreen());
  }

  Future<void> _askFullScreen() async {
    try {
      await requestFullScreenAlarms(ref);
    } catch (_) {
      // Closed editor (StateError) or no plugin: the hint explains it.
    }
  }

  void setSnooze(int minutes) =>
      _draft((r) => r.copyWith(snoozeMinutes: minutes));

  /// Links a task / note; null removes the link.
  void setLink(ItemRef? link, String? title) => _draft(
    (r) => link == null
        ? r.copyWith(clearLink: true)
        : r.copyWith(linkedRef: link, linkedTitle: title),
  );

  // ───────────────────────── Save ─────────────────────────

  /// Writes the reminder (create or update). Returns its id, or null when
  /// the form is invalid / already saving. A one-time reminder whose time
  /// has passed is saved for its next occurrence
  /// ([ReminderEditorState.pastTimeRollsTo]). The first save asks for
  /// notification permission (and exact alarms on Android 12+), and the
  /// OS schedule is updated before this returns ([flushNotifications]).
  Future<String?> save() async {
    final s = _form;
    if (s == null || !s.canSave) return null;
    state = AsyncData(s.copyWith(saving: true));
    try {
      await _askNotificationPermission();
      // A one-time time that has passed moves to its next occurrence
      // (the editor shows the hint; the screen confirms with a toast).
      final now = ref.read(clockProvider).now();
      final id = await ref
          .read(remindersRepositoryProvider)
          .save(s.toReminder(now: now));
      // Hand it to the OS before the editor closes: the user may close the
      // app right away, and the OS delivers it with the app closed.
      await flushNotifications(ref);
      return id;
    } finally {
      final now = _form;
      if (now != null) state = AsyncData(now.copyWith(saving: false));
    }
  }

  Future<void> _askNotificationPermission() async {
    try {
      final now = await ref.read(notificationPermissionProvider.future);
      if (now == NotificationPermission.notDetermined) {
        await requestNotificationPermission(ref);
      }
    } catch (_) {
      // Never blocks the save (also a closed editor's StateError); the
      // editor and the Reminders list show the
      // "Notifications are off" banner.
    }
  }
}

/// The editor form for one route ([ReminderEditorArgs]).
final reminderEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ReminderEditorController, ReminderEditorState, ReminderEditorArgs>(
      ReminderEditorController.new,
    );
