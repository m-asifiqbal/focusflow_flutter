/// ============================================================
/// NOTIFICATION SETTINGS CONTROLLER — writes of screen 31
/// ============================================================
///
/// What: every change Settings › Notifications & Reminders makes — the
/// master switch (with the OS permission flow), digests, per-module
/// switches, quiet hours and the behaviour options — as small methods over
/// [settingsProvider] and the notification permission contract.
/// Why: keeps the widgets free of logic. Rescheduling needs nothing here:
/// the notification engine listens to [settingsProvider] and reconciles the
/// OS schedule as soon as a value changes ("changing digest time
/// reschedules immediately").
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Which once-a-day digest a time change targets.
enum DigestKind { morning, evening }

class NotificationSettingsController {
  NotificationSettingsController(this._ref);

  final Ref _ref;

  Future<void> _update(AppSettings Function(AppSettings s) change) =>
      _ref.read(settingsProvider.notifier).update(change);

  /// Master switch. Turning it on also makes sure the OS allows
  /// notifications: asks when never asked, opens the system settings when
  /// the user refused earlier (the OS won't prompt again). Returns the
  /// permission after the flow (null when switching off).
  Future<NotificationPermission?> setEnabled(bool on) async {
    await _update((s) => s.copyWith(notificationsEnabled: on));
    if (!on) return null;
    final NotificationPermission current;
    try {
      current = await _ref.read(notificationPermissionProvider.future);
    } catch (_) {
      return requestPermission();
    }
    if (current == NotificationPermission.granted) return current;
    return requestPermission();
  }

  /// Asks the OS (or opens its settings after a refusal).
  Future<NotificationPermission> requestPermission() =>
      requestNotificationPermission(_ref);

  /// Re-reads the OS permission (on resume from the system settings).
  void refreshPermission() => _ref.invalidate(notificationPermissionProvider);

  /// Morning briefing / evening review: [minutes] null turns it off.
  Future<void> setDigest(DigestKind kind, int? minutes) => _update(
    (s) => switch (kind) {
      DigestKind.morning => s.copyWith(
        morningBriefing: minutes != null,
        morningBriefingMinutes: minutes,
      ),
      DigestKind.evening => s.copyWith(
        eveningReview: minutes != null,
        eveningReviewMinutes: minutes,
      ),
    },
  );

  /// Weekly report on [weekday] (1 = Monday … 7 = Sunday); null = off.
  Future<void> setWeeklyReport(int? weekday) => _update(
    (s) =>
        s.copyWith(weeklyReport: weekday != null, weeklyReportWeekday: weekday),
  );

  Future<void> setReminders(bool on) =>
      _update((s) => s.copyWith(notifyReminders: on));

  Future<void> setTasks(bool on) => _update((s) => s.copyWith(notifyTasks: on));

  Future<void> setHabits(bool on) =>
      _update((s) => s.copyWith(notifyHabits: on));

  Future<void> setStreakRisk(bool on) =>
      _update((s) => s.copyWith(notifyStreakRisk: on));

  Future<void> setVault(bool on) => _update((s) => s.copyWith(notifyVault: on));

  Future<void> setSync(bool on) => _update((s) => s.copyWith(notifySync: on));

  /// Quiet hours on / off (keeps the chosen window).
  Future<void> setQuietHours(bool on) =>
      _update((s) => s.copyWith(quietHours: on));

  /// Moves one end of the quiet-hours window (and turns quiet hours on).
  Future<void> setQuietWindow({int? startMinutes, int? endMinutes}) => _update(
    (s) => s.copyWith(
      quietHours: true,
      quietStartMinutes: startMinutes,
      quietEndMinutes: endMinutes,
    ),
  );

  Future<void> setDefaultSnooze(int minutes) =>
      _update((s) => s.copyWith(defaultSnoozeMinutes: minutes));

  Future<void> setLockScreen(LockScreenVisibility v) =>
      _update((s) => s.copyWith(lockScreenVisibility: v));

  /// The on / off switch: off hides notifications on the lock screen
  /// ([LockScreenVisibility.hidden]); on shows them with the title only —
  /// the safe default — until "Lock screen details" says otherwise.
  Future<void> setShowOnLockScreen(bool on) => _update(
    (s) => s.copyWith(
      lockScreenVisibility: on
          ? (s.showOnLockScreen
                ? s.lockScreenVisibility
                : LockScreenVisibility.titleOnly)
          : LockScreenVisibility.hidden,
    ),
  );

  /// "Repeat until done" interval in minutes; 0 turns it off.
  Future<void> setRepeatInterval(int minutes) => _update(
    (s) => s.copyWith(
      repeatIntervalMinutes: minutes.clamp(
        0,
        AppSettings.maxRepeatIntervalMinutes,
      ),
    ),
  );

  /// How many times a notification repeats.
  Future<void> setRepeatCount(int count) => _update(
    (s) => s.copyWith(repeatCount: count.clamp(1, AppSettings.maxRepeatCount)),
  );

  Future<void> setBadge(BadgeMode m) =>
      _update((s) => s.copyWith(badgeMode: m));

  /// Android: keep a quiet foreground service running while alarms or
  /// reminders are due, so they still go off after the app is swiped away.
  /// The engine listens to the setting and starts / stops the service.
  Future<void> setKeepAlarmsAlive(bool on) =>
      _update((s) => s.copyWith(keepAlarmsAlive: on));
}

final notificationSettingsControllerProvider =
    Provider<NotificationSettingsController>(
      NotificationSettingsController.new,
    );
