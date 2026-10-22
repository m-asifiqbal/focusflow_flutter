/// ============================================================
/// SOUNDS & HAPTICS — Settings › Sounds & haptics
/// ============================================================
///
/// What: SOUNDS — in-app sounds switch and the default reminder alert
/// sound; HAPTICS — haptic feedback switch plus a "Try it" row.
/// Why: `hapticsEnabled` is read live by the widgets that buzz (check-ins,
/// PIN pad, copy, tab bars), so turning it off takes effect on the next
/// tap. `soundsEnabled` is saved but nothing plays sounds yet, so its row
/// says "coming soon". The reminder sound is the same
/// setting as Settings › Reminders (one catalogue: ReminderAlertOptions).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_option_sheet.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class SoundsHapticsSettingsScreen extends ConsumerWidget {
  const SoundsHapticsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    return SettingsPage(
      title: tr('Sounds & haptics'),
      children: [
        FFGroupedList(
          label: tr('Sounds'),
          footer: tr(
            'Notification sounds also follow your device’s silent mode and Focus settings.',
          ),
          children: [
            FFListRow.toggle(
              leading: settingsTile(
                FontAwesomeIcons.volumeHigh,
                SettingsTints.pink,
              ),
              title: tr('In-app sounds'),
              // No widget plays sounds yet: say so instead of a dead switch.
              subtitle: tr('Completing tasks and habits · coming soon'),
              value: s.soundsEnabled,
              onChanged: editor.setSounds,
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidBell,
                SettingsTints.orange,
              ),
              title: tr('Reminder sound'),
              value: ReminderAlertOptions.soundLabel(s.remindersDefaultSound),
              onTap: () async {
                final v = await pickSetting<String>(
                  context,
                  title: tr('Reminder sound'),
                  subtitle: tr(
                    'Used by new reminders. Each reminder can override it.',
                  ),
                  selected: s.remindersDefaultSound,
                  options: [
                    for (final o in ReminderAlertOptions.sounds)
                      option(o.key, o.label),
                  ],
                );
                if (v != null) await editor.setReminderSound(v);
              },
            ),
          ],
        ),
        FFGroupedList(
          label: tr('Haptics'),
          children: [
            FFListRow.toggle(
              leading: settingsTile(
                FontAwesomeIcons.mobileScreenButton,
                SettingsTints.violet,
              ),
              title: tr('Haptic feedback'),
              subtitle: tr('Check-ins, PIN pad, copy and swipes'),
              value: s.hapticsEnabled,
              onChanged: editor.setHaptics,
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidHandPointer,
                SettingsTints.amber,
              ),
              title: tr('Try haptics'),
              enabled: s.hapticsEnabled,
              chevron: false,
              onTap: () {
                HapticFeedback.mediumImpact();
                showFFToast(
                  context,
                  tr('Felt that?'),
                  icon: FontAwesomeIcons.mobileScreenButton,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
