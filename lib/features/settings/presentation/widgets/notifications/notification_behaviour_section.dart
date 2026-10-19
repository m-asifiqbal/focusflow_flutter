/// ============================================================
/// BEHAVIOUR SECTION — "BEHAVIOUR" card of screen 31
/// ============================================================
///
/// What: Quiet hours (two time pills → wheel sheets; "Off" when disabled),
/// Default snooze, Show on lock screen and App icon badge (list sheets),
/// and the offline-scheduling footnote.
/// Why: quiet hours hold back every non-alarm notification until the
/// window ends (the planner does the shifting); the other values are read
/// by the engine when it schedules, so changes apply immediately.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_digest_section.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_controller.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/quiet_hours_row.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class NotificationBehaviourSection extends ConsumerWidget {
  const NotificationBehaviourSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(notificationSettingsControllerProvider);
    return FFGroupedList(
      label: 'BEHAVIOUR',
      footer:
          "Reminders are scheduled on-device, so they fire even when you're "
          'offline.',
      children: [
        const QuietHoursRow(),
        FFListRow(
          leading: const NotificationRowTile(
            FontAwesomeIcons.clockRotateLeft,
            NotificationTints.snooze,
          ),
          title: 'Default snooze',
          value: ReminderAlertOptions.snoozeLabel(s.defaultSnoozeMinutes),
          onTap: () => _pickSnooze(context, s, c),
        ),
        FFListRow(
          leading: const NotificationRowTile(
            FontAwesomeIcons.repeat,
            NotificationTints.repeat,
          ),
          title: 'Repeat until done',
          subtitle: 'Show a reminder again if you have not acted on it',
          value: NotificationLabels.repeat(s.repeatIntervalMinutes),
          onTap: () => _pickRepeat(context, s, c),
        ),
        if (s.repeatIntervalMinutes > 0)
          FFListRow(
            leading: const NotificationRowTile(
              FontAwesomeIcons.hashtag,
              NotificationTints.repeat,
            ),
            title: 'Repeat up to',
            value: NotificationLabels.repeatCount(s.repeatCount),
            onTap: () => _pickRepeatCount(context, s, c),
          ),
        // Android only: the guard is a foreground service (see
        // core/notifications/alarm_guard.dart).
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          FFListRow.toggle(
            leading: const NotificationRowTile(
              FontAwesomeIcons.shieldHalved,
              NotificationTints.guard,
            ),
            title: 'Keep alarms running',
            subtitle: s.keepAlarmsAlive
                ? 'A quiet notification keeps alarms and reminders on time '
                      'after you close the app'
                : 'Some phones stop alarms when the app is swiped away',
            value: s.keepAlarmsAlive,
            onChanged: c.setKeepAlarmsAlive,
          ),
        FFListRow.toggle(
          leading: const NotificationRowTile(
            FontAwesomeIcons.mobileScreenButton,
            NotificationTints.lockScreen,
          ),
          title: 'Show on lock screen',
          subtitle: s.showOnLockScreen
              ? 'Notifications appear while the phone is locked'
              : 'Nothing is shown while the phone is locked',
          value: s.showOnLockScreen,
          onChanged: c.setShowOnLockScreen,
        ),
        if (s.showOnLockScreen)
          FFListRow(
            leading: const NotificationRowTile(
              FontAwesomeIcons.eye,
              NotificationTints.lockScreen,
            ),
            title: 'Lock screen details',
            value: NotificationLabels.lockScreen(s.lockScreenVisibility),
            onTap: () => _pickLockScreen(context, s, c),
          ),
        FFListRow(
          leading: const NotificationRowTile(
            FontAwesomeIcons.hashtag,
            NotificationTints.badge,
          ),
          title: 'App icon badge',
          value: NotificationLabels.badge(s.badgeMode),
          onTap: () => _pickBadge(context, s, c),
        ),
      ],
    );
  }

  Future<void> _pickSnooze(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController c,
  ) async {
    final choice = await showNotificationOptionSheet<int>(
      context,
      title: 'Default snooze',
      subtitle: 'Used by "Snooze" on notifications and in the inbox',
      selected: s.defaultSnoozeMinutes,
      options: [
        for (final m in ReminderAlertOptions.snoozeMinutes)
          NotificationOption(
            value: m,
            label: ReminderAlertOptions.snoozeLabel(m),
          ),
      ],
    );
    final value = choice?.value;
    if (value != null) await c.setDefaultSnooze(value);
  }

  Future<void> _pickRepeat(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController c,
  ) async {
    final choice = await showRepeatIntervalSheet(
      context,
      current: s.repeatIntervalMinutes,
    );
    final value = choice?.value;
    if (value != null) await c.setRepeatInterval(value);
  }

  Future<void> _pickRepeatCount(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController c,
  ) async {
    final choice = await showNotificationOptionSheet<int>(
      context,
      title: 'Repeat up to',
      subtitle: 'Most times a notification is shown again',
      selected: s.repeatCount,
      options: [
        for (final n in const [1, 2, 3, 5, 10])
          NotificationOption(
            value: n,
            label: NotificationLabels.repeatCount(n),
          ),
      ],
    );
    final value = choice?.value;
    if (value != null) await c.setRepeatCount(value);
  }

  Future<void> _pickLockScreen(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController c,
  ) async {
    final choice = await showNotificationOptionSheet<LockScreenVisibility>(
      context,
      title: 'Lock screen details',
      selected: s.lockScreenVisibility,
      options: [
        // Hiding is the switch above; this only picks how much is shown.
        for (final v in LockScreenVisibility.values.where(
          (v) => v != LockScreenVisibility.hidden,
        ))
          NotificationOption(
            value: v,
            label: NotificationLabels.lockScreen(v),
            subtitle: NotificationLabels.lockScreenHint(
              v,
              platform: Theme.of(context).platform,
            ),
          ),
      ],
    );
    final value = choice?.value;
    if (value != null) await c.setLockScreen(value);
  }

  Future<void> _pickBadge(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController c,
  ) async {
    final choice = await showNotificationOptionSheet<BadgeMode>(
      context,
      title: 'App icon badge',
      selected: s.badgeMode,
      options: [
        for (final m in BadgeMode.values)
          NotificationOption(
            value: m,
            label: NotificationLabels.badge(m),
            subtitle: NotificationLabels.badgeHint(m),
          ),
      ],
    );
    final value = choice?.value;
    if (value != null) await c.setBadge(value);
  }
}
