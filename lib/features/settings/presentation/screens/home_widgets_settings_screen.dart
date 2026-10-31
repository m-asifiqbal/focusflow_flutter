/// ============================================================
/// HOME SCREEN WIDGETS — Settings › Home screen widgets (Android)
/// ============================================================
///
/// What: the global look and privacy of the Android home-screen widgets
/// (theme, note text preview, completed tasks) and a list of the six widgets
/// with an "add" button each — it asks the launcher to place the widget
/// (Android 8+); where the launcher can't, a toast says how to add it by hand.
/// Each widget on the home screen also has its own settings (its theme,
/// background and, for the all-together widget, its sections) — opened by the
/// widget's own configuration screen when it is placed.
/// Why: changes are saved as ordinary settings; HomeWidgetSync notices and
/// redraws every widget a moment later.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/home_widgets/home_widget_channel.dart';
import 'package:focusflow/core/home_widgets/home_widget_sync.dart';
import 'package:focusflow/core/home_widgets/widget_snapshot_builder.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_option_sheet.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

String widgetsThemeLabel(WidgetsTheme t) => switch (t) {
  WidgetsTheme.app => tr('Follow the app'),
  WidgetsTheme.light => tr('Light'),
  WidgetsTheme.dark => tr('Dark'),
};

/// How many widgets of each kind are on the home screen.
final homeWidgetCountsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => const HomeWidgetChannel().counts(),
);

class HomeWidgetsSettingsScreen extends ConsumerWidget {
  const HomeWidgetsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    final counts = ref.watch(homeWidgetCountsProvider).valueOrNull ?? const {};
    const gap = SizedBox(height: AppSpacing.section);
    return SettingsPage(
      title: tr('Home screen widgets'),
      children: [
        FFGroupedList(
          label: tr('Look & privacy'),
          footer: tr(
            'Widgets show titles on your home screen. Turn the text preview off if others can see your phone. Locked notes and the Vault are never shown.',
          ),
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.circleHalfStroke,
                SettingsTints.indigo,
              ),
              title: tr('Theme'),
              value: widgetsThemeLabel(s.widgetsTheme),
              onTap: () async {
                final v = await pickSetting<WidgetsTheme>(
                  context,
                  title: tr('Theme'),
                  subtitle: tr('Each widget can also have its own.'),
                  selected: s.widgetsTheme,
                  options: [
                    for (final t in WidgetsTheme.values)
                      option(t, widgetsThemeLabel(t)),
                  ],
                );
                if (v != null) await editor.setWidgetsTheme(v);
              },
            ),
            FFListRow.toggle(
              leading: settingsTile(
                FontAwesomeIcons.noteSticky,
                SettingsTints.amber,
              ),
              title: tr('Show note text'),
              subtitle: s.widgetsShowNoteText
                  ? tr('Notes show a short preview')
                  : tr('Titles only'),
              value: s.widgetsShowNoteText,
              onChanged: editor.setWidgetsShowNoteText,
            ),
            FFListRow.toggle(
              leading: settingsTile(
                FontAwesomeIcons.circleCheck,
                SettingsTints.teal,
              ),
              title: tr('Show completed tasks'),
              subtitle: tr('Struck through until the day ends'),
              value: s.widgetsShowCompleted,
              onChanged: editor.setWidgetsShowCompleted,
            ),
          ],
        ),
        gap,
        FFGroupedList(
          label: tr('Add to home screen'),
          footer: tr(
            'Or touch and hold an empty spot on your home screen and choose Widgets.',
          ),
          children: [
            for (final k in WidgetKinds.all)
              _KindRow(kind: k, count: counts[k] ?? 0),
          ],
        ),
      ],
    );
  }
}

class _KindRow extends ConsumerWidget {
  const _KindRow({required this.kind, required this.count});

  final String kind;
  final int count;

  (String, String, IconData, ModuleColors) _info() => switch (kind) {
    WidgetKinds.today => (
      tr('All together'),
      tr('Tasks, habits, doses, reminders and notes in one widget'),
      FontAwesomeIcons.tableCellsLarge,
      SettingsTints.emeraldDeep,
    ),
    WidgetKinds.tasks => (
      tr('Tasks'),
      tr('Today’s tasks with check circles'),
      ModuleStyle.tasks.icon,
      ModuleStyle.tasks.colors,
    ),
    WidgetKinds.habits => (
      tr('Habits'),
      tr('Habit check-ins and streaks'),
      ModuleStyle.habits.icon,
      ModuleStyle.habits.colors,
    ),
    WidgetKinds.medicines => (
      tr('Medicine'),
      tr('Today’s doses; tap to mark taken'),
      ModuleStyle.medicines.icon,
      ModuleStyle.medicines.colors,
    ),
    WidgetKinds.reminders => (
      tr('Reminders'),
      tr('What is coming up today'),
      ModuleStyle.reminders.icon,
      ModuleStyle.reminders.colors,
    ),
    _ => (
      tr('Notes'),
      tr('Pinned and recent notes'),
      ModuleStyle.notes.icon,
      ModuleStyle.notes.colors,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (name, about, icon, colors) = _info();
    return FFListRow(
      leading: FFIconTile.soft(
        icon: icon,
        colors: colors,
        size: AppSizes.iconTile - 2,
      ),
      title: name,
      subtitle: count > 0
          ? '$about · ${tr('{n} on your home screen', {'n': count})}'
          : about,
      trailing: FFTextButton(
        label: tr('Add'),
        semanticLabel: tr('Add {name} widget', {'name': name}),
        onPressed: () async {
          final ok = await const HomeWidgetChannel().requestPin(kind);
          ref.invalidate(homeWidgetCountsProvider);
          if (ok) {
            // The new widget needs data now, and the sync needs to start.
            await pushWidgetSnapshot(ref.read);
            unawaited(ref.read(homeWidgetSyncProvider).start());
          }
          if (!ok && context.mounted) {
            showFFToast(
              context,
              tr(
                'Touch and hold your home screen, then choose Widgets › {name}.',
                {'name': name},
              ),
            );
          }
        },
      ),
    );
  }
}
