/// ============================================================
/// APPEARANCE SETTINGS SCREEN — Settings › Appearance (screen 32)
/// ============================================================
///
/// What: "‹ Settings | Appearance" over THEME (phone previews) · ACCENT
/// COLOUR · TEXT SIZE (+ live preview) · APP ICON · LAYOUT (notes default
/// view, list density, reduce motion, system font).
/// Why: every control writes [settingsProvider], which app.dart applies
/// to the theme / MediaQuery at once — the preview *is* the app, no
/// restart needed. The text-size slider previews locally while dragging
/// and saves once, on release.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/appearance/appearance_controls.dart';
import 'package:focusflow/features/settings/presentation/widgets/appearance/theme_picker.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    const gap = SizedBox(height: AppSpacing.section);
    return FFScaffold(
      body: Column(
        children: [
          const FFNavHeader(
            leading: FFBackButton(label: 'Settings'),
            title: 'Appearance',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.lg,
                AppSpacing.grouped,
                AppSpacing.xxl,
              ),
              children: [
                const FFSectionLabel('Theme'),
                ThemePicker(
                  selected: s.themeMode,
                  accent: s.accent,
                  onSelected: editor.setThemeMode,
                ),
                gap,
                const FFSectionLabel('Accent colour'),
                AccentPicker(selected: s.accent, onSelected: editor.setAccent),
                gap,
                const FFSectionLabel('Text size'),
                TextSizeCard(
                  index: SettingsEditor.stopIndexOf(s.textScale),
                  scales: SettingsEditor.textScaleStops,
                  onChanged: (i) =>
                      editor.setTextScale(SettingsEditor.textScaleStops[i]),
                ),
                gap,
                const FFSectionLabel('App icon'),
                AppIconPicker(
                  onUnavailable: (label) => showFFToast(
                    context,
                    '$label icon is coming soon',
                    icon: FontAwesomeIcons.wandMagicSparkles,
                  ),
                ),
                gap,
                const _LayoutSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutSection extends ConsumerWidget {
  const _LayoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    return FFGroupedList(
      label: 'Layout',
      children: [
        FFListRow(
          leading: settingsTile(
            FontAwesomeIcons.tableCellsLarge,
            SettingsTints.teal,
          ),
          title: 'Notes default view',
          value: SettingsLabels.notesView(s.notesView),
          onTap: () async {
            final c = await showNotificationOptionSheet<NotesView>(
              context,
              title: 'Notes default view',
              selected: s.notesView,
              options: [
                for (final v in NotesView.values)
                  NotificationOption(
                    value: v,
                    label: SettingsLabels.notesView(v),
                  ),
              ],
            );
            if (c?.value != null) await editor.setNotesView(c!.value!);
          },
        ),
        FFListRow(
          leading: settingsTile(FontAwesomeIcons.bars, SettingsTints.blue),
          title: 'List density',
          // Saved now; FFListRow doesn't read a density token yet.
          subtitle: 'Coming soon',
          value: SettingsLabels.density(s.listDensity),
          onTap: () async {
            final c = await showNotificationOptionSheet<ListDensity>(
              context,
              title: 'List density',
              subtitle: 'Compact fits more rows on screen.',
              selected: s.listDensity,
              options: [
                for (final v in ListDensity.values)
                  NotificationOption(
                    value: v,
                    label: SettingsLabels.density(v),
                  ),
              ],
            );
            if (c?.value != null) await editor.setListDensity(c!.value!);
          },
        ),
        FFListRow.toggle(
          leading: settingsTile(
            FontAwesomeIcons.wandMagicSparkles,
            SettingsTints.violet,
          ),
          title: 'Reduce motion',
          value: s.reduceMotion,
          onChanged: editor.setReduceMotion,
        ),
        FFListRow.toggle(
          leading: settingsTile(FontAwesomeIcons.font, SettingsTints.slate),
          title: 'Use system font',
          // AppTheme drops the bundled families (San Francisco / Roboto).
          value: s.useSystemFont,
          onChanged: editor.setUseSystemFont,
        ),
      ],
    );
  }
}
