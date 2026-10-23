/// ============================================================
/// MODULE SECTION — "BY MODULE" switches of screen 31
/// ============================================================
///
/// What: one switch per notification source — Reminders, Task due &
/// overdue, Habit check-ins, Streak at risk, Vault security alerts, Backup
/// & sync status — each with the mockup's subtitle where it has one.
/// Why: the planner reads these flags; flipping one reschedules at once
/// (the engine listens to the settings).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_digest_section.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_controller.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class NotificationModuleSection extends ConsumerWidget {
  const NotificationModuleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(notificationSettingsControllerProvider);
    final sound = ReminderAlertOptions.soundLabel(s.remindersDefaultSound);
    return FFGroupedList(
      label: tr('BY MODULE'),
      children: [
        FFListRow.toggle(
          leading: NotificationRowTile(
            FontAwesomeIcons.solidBell,
            NotificationTints.reminders,
          ),
          title: tr('Reminders'),
          subtitle: tr('Sound: {sound} · Alarm-style for high priority', {
            'sound': sound,
          }),
          value: s.notifyReminders,
          onChanged: c.setReminders,
        ),
        FFListRow.toggle(
          leading: NotificationRowTile(
            FontAwesomeIcons.checkDouble,
            NotificationTints.tasks,
          ),
          title: tr('Task due & overdue'),
          value: s.notifyTasks,
          onChanged: c.setTasks,
        ),
        FFListRow.toggle(
          leading: NotificationRowTile(
            FontAwesomeIcons.repeat,
            NotificationTints.habits,
          ),
          title: tr('Habit check-ins'),
          subtitle: tr('At each habit\'s scheduled times'),
          value: s.notifyHabits,
          onChanged: c.setHabits,
        ),
        FFListRow.toggle(
          leading: NotificationRowTile(
            FontAwesomeIcons.pills,
            NotificationTints.medicines,
          ),
          title: tr('Medicine doses'),
          subtitle: tr('At each dose time, and again if not taken'),
          value: s.notifyMedicines,
          onChanged: c.setMedicines,
        ),
        FFListRow.toggle(
          leading: const NotificationRowTile(
            FontAwesomeIcons.fire,
            NotificationTints.streak,
          ),
          title: tr('Streak at risk'),
          value: s.notifyStreakRisk,
          onChanged: c.setStreakRisk,
        ),
        FFListRow.toggle(
          leading: const NotificationRowTile(
            FontAwesomeIcons.shieldHalved,
            NotificationTints.security,
          ),
          title: tr('Vault security alerts'),
          value: s.notifyVault,
          onChanged: c.setVault,
        ),
        FFListRow.toggle(
          leading: const NotificationRowTile(
            FontAwesomeIcons.cloud,
            NotificationTints.sky,
          ),
          title: tr('Backup & sync status'),
          value: s.notifySync,
          onChanged: c.setSync,
        ),
      ],
    );
  }
}
