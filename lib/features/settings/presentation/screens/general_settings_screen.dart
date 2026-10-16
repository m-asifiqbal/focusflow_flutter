/// ============================================================
/// GENERAL SETTINGS — Settings › General (`/settings/general`)
/// ============================================================
///
/// What: LANGUAGE & REGION (language, week start, date format, time
/// format), STARTUP (start screen) and RESET (restore default
/// preferences, after a confirmation). The root shows the same rows
/// inline; this page is the deep-link target and adds the date format.
/// Why: pickers are the root's own ([runRootAction]) so both places stay
/// identical; every choice writes [settingsProvider] and applies at once.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_option_sheet.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:intl/intl.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  /// Date patterns offered (stored as the intl pattern).
  static const datePatterns = [
    'MMM d, y',
    'd MMM y',
    'MM/dd/yyyy',
    'dd/MM/yyyy',
    'yyyy-MM-dd',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final now = ref.watch(clockProvider).now();
    void run(SettingsRootAction a) => runRootAction(context, ref, a);
    String sample(String pattern) => DateFormat(pattern, 'en').format(now);

    return SettingsPage(
      title: 'General',
      children: [
        FFGroupedList(
          label: 'Language & region',
          children: [
            FFListRow(
              leading: settingsTile(FontAwesomeIcons.globe, SettingsTints.sky),
              title: 'Language',
              value: SettingsLabels.language(s.languageCode),
              onTap: () => run(SettingsRootAction.language),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidCalendar,
                SettingsTints.violet,
              ),
              title: 'Week starts on',
              value: SettingsLabels.weekday(s.weekStartsOn),
              onTap: () => run(SettingsRootAction.weekStart),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.calendarDays,
                SettingsTints.blue,
              ),
              title: 'Date format',
              // Saved now; DateUtilsX formats don't read it yet.
              subtitle: 'Full dates · coming soon',
              value: sample(s.dateFormat),
              onTap: () async {
                final v = await pickSetting<String>(
                  context,
                  title: 'Date format',
                  // Honest: the choice is saved, but screens still use
                  // their own formats until every feature reads it.
                  subtitle:
                      'Saved for full dates. Screens switch to it in a '
                      'coming update.',
                  selected: s.dateFormat,
                  options: [for (final p in datePatterns) option(p, sample(p))],
                );
                if (v != null) {
                  await ref.read(settingsEditorProvider).setDateFormat(v);
                }
              },
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidClock,
                SettingsTints.slate,
              ),
              title: 'Time format',
              value: SettingsLabels.timeFormat(use24h: s.use24HourTime),
              onTap: () => run(SettingsRootAction.dateTimeFormat),
            ),
          ],
        ),
        FFGroupedList(
          label: 'Startup',
          footer: 'The tab FocusFlow opens on after launch.',
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.house,
                SettingsTints.emerald,
              ),
              title: 'Start screen',
              value: SettingsLabels.startScreen(s.startScreen),
              onTap: () => run(SettingsRootAction.startScreen),
            ),
          ],
        ),
        FFGroupedList(
          label: 'Reset',
          footer:
              'Restores appearance, notifications, module defaults, layout, '
              'gestures and sounds. Security, vault, backup and your data '
              'stay as they are.',
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.arrowRotateLeft,
                SettingsTints.red,
              ),
              title: 'Reset settings',
              destructive: true,
              onTap: () => confirmResetSettings(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks, then restores the default preferences
/// ([SettingsController.resetToDefaults]).
Future<void> confirmResetSettings(BuildContext context, WidgetRef ref) async {
  final ok = await showFFConfirm(
    context,
    title: 'Reset settings?',
    message:
        'Appearance, notifications, module defaults, layout, gestures and '
        'sounds go back to their defaults. Security, vault, backup settings '
        'and your data are not changed.',
    confirmLabel: 'Reset',
    destructive: true,
    icon: FontAwesomeIcons.arrowRotateLeft,
  );
  if (!ok) return;
  await ref.read(settingsProvider.notifier).resetToDefaults();
  if (context.mounted) {
    showFFToast(
      context,
      'Settings reset',
      icon: FontAwesomeIcons.solidCircleCheck,
    );
  }
}
