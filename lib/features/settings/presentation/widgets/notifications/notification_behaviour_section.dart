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
            FontAwesomeIcons.mobileScreenButton,
            NotificationTints.lockScreen,
          ),
          title: 'Show on lock screen',
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

  Future<void> _pickLockScreen(
    BuildContext context,
    AppSettings s,
    NotificationSettingsController c,
  ) async {
    final choice = await showNotificationOptionSheet<LockScreenVisibility>(
      context,
      title: 'Show on lock screen',
      selected: s.lockScreenVisibility,
      options: [
        for (final v in LockScreenVisibility.values)
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
