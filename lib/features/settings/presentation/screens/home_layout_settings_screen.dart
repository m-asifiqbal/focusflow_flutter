/// ============================================================
/// HOME LAYOUT SETTINGS — Settings › Home layout & widgets
/// ============================================================
///
/// What: HOME SECTIONS — every Home section in its current order with a
/// drag handle (reorder) and a switch (show / hide); "Reset" restores the
/// designed order. HOME — daily focus goal (the hero's 100 %). LIBRARY —
/// show item counts.
/// Why: Home reads `AppSettings.visibleHomeSections`, so a drag or a
/// switch here re-lays out Home immediately. Reorder is also reachable
/// without dragging (screen-reader "Move up / Move down" actions).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_option_sheet.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class HomeLayoutSettingsScreen extends ConsumerWidget {
  const HomeLayoutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    final isDefault =
        s.hiddenHomeSections.isEmpty &&
        _sameOrder(s.homeSections, HomeSection.values);
    return SettingsPage(
      title: tr('Home layout'),
      trailing: [
        if (!isDefault)
          FFNavAction(label: tr('Reset'), onPressed: editor.resetHomeLayout),
      ],
      children: [
        FFGroupedList(
          label: tr('Home sections'),
          footer: tr(
            'Drag to reorder. Hidden sections come back when you turn them on again.',
          ),
          children: [_SectionsList(settings: s)],
        ),
        FFGroupedList(
          label: tr('Home'),
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.bullseye,
                SettingsTints.emerald,
              ),
              title: tr('Daily focus goal'),
              value: tr('{count, plural, one {# task} other {# tasks}}', {
                'count': s.dailyFocusGoal,
              }),
              onTap: () async {
                final v = await pickSetting<int>(
                  context,
                  title: tr('Daily focus goal'),
                  subtitle: tr(
                    'Tasks per day that fill Today\'s focus to 100 %.',
                  ),
                  selected: s.dailyFocusGoal,
                  options: [
                    for (final n in const [3, 5, 7, 10, 12, 15])
                      option(
                        n,
                        tr('{count, plural, one {# task} other {# tasks}}', {
                          'count': n,
                        }),
                      ),
                  ],
                );
                if (v != null) await editor.setDailyFocusGoal(v);
              },
            ),
          ],
        ),
        FFGroupedList(
          label: tr('Library'),
          children: [
            FFListRow.toggle(
              leading: settingsTile(
                FontAwesomeIcons.layerGroup,
                SettingsTints.slate,
              ),
              title: tr('Show item counts'),
              value: s.libraryShowCounts,
              onChanged: editor.setLibraryShowCounts,
            ),
          ],
        ),
      ],
    );
  }

  static bool _sameOrder(List<HomeSection> a, List<HomeSection> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Icon tile of each Home section (module colours where one exists).
(IconData, ModuleColors) homeSectionStyle(HomeSection s) => switch (s) {
  HomeSection.focus => (FontAwesomeIcons.bullseye, SettingsTints.emerald),
  HomeSection.week => (FontAwesomeIcons.calendarWeek, SettingsTints.violet),
  HomeSection.upNext => (
    ModuleStyle.reminders.icon,
    ModuleStyle.reminders.colors,
  ),
  HomeSection.tasks => (ModuleStyle.tasks.icon, ModuleStyle.tasks.colors),
  HomeSection.notes => (ModuleStyle.notes.icon, ModuleStyle.notes.colors),
  HomeSection.habits => (ModuleStyle.habits.icon, ModuleStyle.habits.colors),
  HomeSection.medicines => (
    ModuleStyle.medicines.icon,
    ModuleStyle.medicines.colors,
  ),
};

class _SectionsList extends ConsumerWidget {
  const _SectionsList({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(settingsEditorProvider);
    final order = settings.homeSections;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    void move(int from, int to) {
      if (to < 0 || to >= order.length || from == to) return;
      final next = [...order];
      final item = next.removeAt(from);
      next.insert(to, item);
      editor.setHomeOrder(next);
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        color: context.ff.surface,
        elevation: reduceMotion ? 0 : 6,
        shadowColor: context.ff.scrim,
        child: child,
      ),
      onReorderItem: move,
      children: [
        for (var i = 0; i < order.length; i++)
          _SectionRow(
            key: ValueKey(order[i]),
            index: i,
            section: order[i],
            visible: !settings.hiddenHomeSections.contains(order[i]),
            onVisible: (v) => editor.setHomeSectionVisible(order[i], v),
            onMoveUp: i == 0 ? null : () => move(i, i - 1),
            onMoveDown: i == order.length - 1 ? null : () => move(i, i + 1),
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.index,
    required this.section,
    required this.visible,
    required this.onVisible,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final int index;
  final HomeSection section;
  final bool visible;
  final ValueChanged<bool> onVisible;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final (icon, colors) = homeSectionStyle(section);
    final title = SettingsLabels.homeSection(section);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: tr('Move {title} up', {'title': title})):
            ?onMoveUp,
        CustomSemanticsAction(label: tr('Move {title} down', {'title': title})):
            ?onMoveDown,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0) const FFDividerInset(),
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: tr('Reorder {title}', {'title': title}),
                  button: true,
                  child: SizedBox(
                    width: AppSizes.minTap,
                    height: AppSizes.rowMin,
                    child: Icon(
                      FontAwesomeIcons.gripVertical,
                      size: AppSizes.tileGlyph,
                      color: ff.inkFaint,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: visible ? 1 : 0.55,
                  child: FFListRow.toggle(
                    leading: settingsTile(icon, colors),
                    title: title,
                    subtitle: SettingsLabels.homeSectionHint(section),
                    value: visible,
                    onChanged: onVisible,
                    semanticLabel: tr('Show {title} on Home', {'title': title}),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
