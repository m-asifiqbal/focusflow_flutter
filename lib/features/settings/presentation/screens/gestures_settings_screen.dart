/// ============================================================
/// GESTURES SETTINGS — Settings › Gestures & swipe actions
/// ============================================================
///
/// What: a live "Try it" row that swipes exactly like a list row with the
/// current configuration, then SWIPE ACTIONS — Swipe right / Swipe left
/// pickers (`AppSettings.swipeRight` / `swipeLeft`), with a note on how
/// actions map per module.
/// Why: every list wraps its rows in ItemSwipe, which watches these two
/// settings, so a change applies to Notes, Tasks, Reminders, Habits and
/// the Vault at once. The demo row lets people feel the result safely
/// (nothing is archived or deleted there).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
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

class GesturesSettingsScreen extends ConsumerWidget {
  const GesturesSettingsScreen({super.key});

  /// Choices per direction (swipe left always ends with Delete).
  static const rightChoices = [
    SwipeAction.complete,
    SwipeAction.pin,
    SwipeAction.favourite,
    SwipeAction.snooze,
    SwipeAction.archive,
    SwipeAction.none,
  ];
  static const leftChoices = [
    SwipeAction.archive,
    SwipeAction.pin,
    SwipeAction.favourite,
    SwipeAction.delete,
    SwipeAction.none,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);

    Future<void> pick({required bool right}) async {
      final v = await pickSetting<SwipeAction>(
        context,
        title: right ? 'Swipe right' : 'Swipe left',
        subtitle: right
            ? 'A full swipe right runs it at once.'
            : 'Swipe left reveals it next to Delete.',
        selected: right ? s.swipeRight : s.swipeLeft,
        options: [
          for (final a in right ? rightChoices : leftChoices)
            option(a, SettingsLabels.swipe(a), SettingsLabels.swipeHint(a)),
        ],
      );
      if (v == null) return;
      right ? await editor.setSwipeRight(v) : await editor.setSwipeLeft(v);
    }

    return SettingsPage(
      title: 'Gestures',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FFSectionLabel('Try it'),
            _DemoRow(left: s.swipeLeft, right: s.swipeRight),
          ],
        ),
        FFGroupedList(
          label: 'Swipe actions',
          footer:
              'Applies to every list. Where an action does not fit an item '
              '(e.g. Complete on a note) the row pins instead. Archive and '
              'Delete always offer Undo for 5 seconds.',
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.arrowRight,
                SettingsTints.emerald,
              ),
              title: 'Swipe right',
              value: SettingsLabels.swipe(s.swipeRight),
              onTap: () => pick(right: true),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.arrowLeft,
                SettingsTints.slate,
              ),
              title: 'Swipe left',
              value: s.swipeLeft == SwipeAction.none
                  ? SettingsLabels.swipe(s.swipeLeft)
                  : s.swipeLeft == SwipeAction.delete
                  ? 'Delete'
                  : '${SettingsLabels.swipe(s.swipeLeft)} + Delete',
              onTap: () => pick(right: false),
            ),
          ],
        ),
      ],
    );
  }
}

/// A sample task row wired to FFSwipeActions with the current choices;
/// actions only show a toast.
class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.left, required this.right});

  final SwipeAction left;
  final SwipeAction right;

  FFSwipeAction? _action(BuildContext context, SwipeAction a) {
    void say() => showFFToast(
      context,
      '${SettingsLabels.swipe(a)} — just a preview',
      icon: FontAwesomeIcons.solidHandPointer,
    );
    return switch (a) {
      SwipeAction.none => null,
      SwipeAction.archive => FFSwipeAction.archive(onTap: say),
      SwipeAction.delete => FFSwipeAction.delete(onTap: say),
      SwipeAction.complete => FFSwipeAction.complete(onTap: say),
      SwipeAction.pin => FFSwipeAction.pin(onTap: say),
      SwipeAction.favourite => FFSwipeAction(
        icon: FontAwesomeIcons.solidStar,
        label: 'Favourite',
        color: ModuleStyle.vault.solid,
        onTap: say,
      ),
      SwipeAction.snooze => FFSwipeAction(
        icon: FontAwesomeIcons.clockRotateLeft,
        label: 'Snooze',
        color: ModuleStyle.reminders.solid,
        onTap: say,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final primary = _action(context, left);
    return FFSwipeActions(
      // Rebuild the gesture state when the configuration changes.
      key: ValueKey((left, right)),
      startAction: _action(context, right),
      endActions: [
        if (primary != null && left != SwipeAction.delete) primary,
        if (left != SwipeAction.none)
          FFSwipeAction.delete(
            onTap: () => showFFToast(
              context,
              'Delete — just a preview',
              icon: FontAwesomeIcons.solidHandPointer,
            ),
          ),
      ],
      child: FFCard(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            settingsTile(ModuleStyle.tasks.icon, ModuleStyle.tasks.colors),
            const SizedBox(width: AppSpacing.rowLeadingGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review weekly plan', style: context.text.rowTitle),
                  Text(
                    'Swipe this row left or right',
                    style: context.text.meta.copyWith(color: ff.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(
              FontAwesomeIcons.arrowsLeftRight,
              size: AppSizes.tileGlyph,
              color: ff.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
