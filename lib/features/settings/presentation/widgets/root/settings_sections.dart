/// ============================================================
/// SETTINGS SECTIONS (1/2) — GENERAL · PREFERENCES · MODULES (screen 30)
/// ============================================================
///
/// Grouped cards of rows with live values read from [settingsProvider]
/// and the Library's live counts. Pickers run in place (see
/// settings_root_actions.dart); other rows drill into sub-pages.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// 32 pt solid row tile.
Widget settingsTile(IconData icon, ModuleColors colors) =>
    FFIconTile(icon: icon, colors: colors, size: AppSizes.iconTileSm);

class SettingsGeneralSection extends ConsumerWidget {
  const SettingsGeneralSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void run(SettingsRootAction a) => runRootAction(context, ref, a);
    return FFGroupedList(
      label: tr('General'),
      children: [
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.globe, SettingsTints.sky),
          title: tr('Language'),
          value: SettingsLabels.language(s.languageCode),
          onTap: () => run(SettingsRootAction.language),
        ),
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.house, SettingsTints.emerald),
          title: tr('Start screen'),
          value: SettingsLabels.startScreen(s.startScreen),
          onTap: () => run(SettingsRootAction.startScreen),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidCalendar,
            SettingsTints.violet,
          ),
          title: tr('Week starts on'),
          value: SettingsLabels.weekday(s.weekStartsOn),
          onTap: () => run(SettingsRootAction.weekStart),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidClock,
            SettingsTints.slate,
          ),
          title: tr('Date & time format'),
          value: SettingsLabels.timeFormat(use24h: s.use24HourTime),
          // General holds both the date pattern and the 12/24-hour clock.
          onTap: () => context.push(AppRoutes.settingsGeneral),
        ),
      ],
    );
  }
}

class SettingsPreferencesSection extends ConsumerWidget {
  const SettingsPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider.select((s) => s.themeMode));
    final pinned = ref.watch(
      libraryCountsProvider.select((c) => c.whenData((v) => v.pinned)),
    );
    return FFGroupedList(
      label: tr('Preferences'),
      children: [
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.solidBell, SettingsTints.red),
          title: tr('Notifications & Reminders'),
          onTap: () => context.push(AppRoutes.settingsNotifications),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.circleHalfStroke,
            SettingsTints.indigo,
          ),
          title: tr('Appearance'),
          value: SettingsLabels.theme(theme),
          onTap: () => context.push(AppRoutes.settingsAppearance),
        ),
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.thumbtack, SettingsTints.blue),
          title: tr('Pinned items'),
          value: pinned.valueOrNull?.toString(),
          onTap: () => context.push(AppRoutes.pinned),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.tableCellsLarge,
            SettingsTints.teal,
          ),
          title: tr('Home layout & widgets'),
          onTap: () => context.push(AppRoutes.settingsHomeLayout),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.solidHandPointer,
            SettingsTints.amber,
          ),
          title: tr('Gestures & swipe actions'),
          onTap: () => context.push(AppRoutes.settingsGestures),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.volumeHigh,
            SettingsTints.pink,
          ),
          title: tr('Sounds & haptics'),
          onTap: () => context.push(AppRoutes.settingsSoundsHaptics),
        ),
      ],
    );
  }
}

class SettingsModulesSection extends ConsumerWidget {
  const SettingsModulesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final tagsFolders = ref.watch(
      libraryCountsProvider.select((c) => c.whenData((v) => v.tagsAndFolders)),
    );
    FFListRow module(ModuleStyle style, String key, String title, String v) =>
        FFListRow(
          leading: settingsTile(style.icon, style.colors),
          title: title,
          value: v,
          onTap: () => context.push(AppRoutes.settingsModule(key)),
        );
    return FFGroupedList(
      label: tr('Modules'),
      children: [
        module(
          ModuleStyle.notes,
          'notes',
          tr('Notes'),
          '${SettingsLabels.notesView(s.notesView)} · '
              '${SettingsLabels.notesSort(s.notesSort)}',
        ),
        module(
          ModuleStyle.tasks,
          'tasks',
          tr('Tasks'),
          // Smart lists aren't implemented yet, so show a default that
          // does take effect.
          s.tasksShowCompleted ? tr('Completed shown') : tr('Completed hidden'),
        ),
        module(
          ModuleStyle.reminders,
          'reminders',
          tr('Reminders'),
          tr('Snooze {minutes}m', {'minutes': s.defaultSnoozeMinutes}),
        ),
        module(
          ModuleStyle.habits,
          'habits',
          tr('Habits'),
          tr('Reset {time}', {
            'time': SettingsLabels.clockTime(
              s.habitResetMinutes,
              use24h: s.use24HourTime,
            ),
          }),
        ),
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.layerGroup,
            SettingsTints.slate,
          ),
          title: tr('Tags & folders'),
          value: tagsFolders.valueOrNull?.toString(),
          onTap: () => context.push(AppRoutes.settingsTagsFolders),
        ),
      ],
    );
  }
}
