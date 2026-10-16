/// ============================================================
/// MODULE SETTINGS — Settings › Modules › Notes / Tasks / Reminders /
/// Habits (`/settings/modules/:module`)
/// ============================================================
///
/// What: the module's defaults ([NotesDefaultsSection] …) plus shortcuts
/// to the cross-module pages that also affect it (notifications, swipe
/// actions, tags & folders). An unknown module shows an empty state.
/// Why: the four MODULES rows of the root (30) deep-link here; the values
/// they show ("Grid · Last edited", "Snooze 10m"…) are edited on this page.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/modules/module_settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:go_router/go_router.dart';

class ModuleSettingsScreen extends StatelessWidget {
  const ModuleSettingsScreen({required this.module, super.key});

  /// `notes`, `tasks`, `reminders` or `habits`.
  final String module;

  static const modules = ['notes', 'tasks', 'reminders', 'habits'];

  @override
  Widget build(BuildContext context) {
    final (title, section) = switch (module) {
      'notes' => ('Notes', const NotesDefaultsSection()),
      'tasks' => ('Tasks', const TasksDefaultsSection()),
      'reminders' => ('Reminders', const RemindersDefaultsSection()),
      'habits' => ('Habits', const HabitsDefaultsSection()),
      _ => ('Module', null),
    };
    if (section == null) {
      return SettingsPage(
        title: title,
        children: [
          FFEmptyState.compact(
            colors: SettingsTints.slate,
            icon: FontAwesomeIcons.circleQuestion,
            title: 'Nothing to set here',
            body: 'This module has no settings page.',
            ctaLabel: 'Back to Settings',
            ctaIcon: FontAwesomeIcons.arrowLeft,
            onCta: () => context.go(AppRoutes.settings),
          ),
        ],
      );
    }
    return SettingsPage(
      title: title,
      children: [
        section,
        FFGroupedList(
          label: 'Related',
          children: [
            if (module != 'notes')
              FFListRow(
                leading: settingsTile(
                  FontAwesomeIcons.solidBell,
                  ModuleStyle.reminders.colors,
                ),
                title: 'Notifications',
                onTap: () => context.push(AppRoutes.settingsNotifications),
              ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidHandPointer,
                SettingsTints.amber,
              ),
              title: 'Gestures & swipe actions',
              onTap: () => context.push(AppRoutes.settingsGestures),
            ),
            if (module == 'notes' || module == 'tasks')
              FFListRow(
                leading: settingsTile(
                  FontAwesomeIcons.layerGroup,
                  SettingsTints.slate,
                ),
                title: 'Tags & folders',
                onTap: () => context.push(AppRoutes.settingsTagsFolders),
              ),
          ],
        ),
      ],
    );
  }
}
