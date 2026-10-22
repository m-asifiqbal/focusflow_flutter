/// ============================================================
/// CUSTOMIZE HABIT SHEET — icon & colour picker of the habit editor
/// ============================================================
///
/// Opened from the preview card's icon tile (screen 15): the full colour
/// palette and a searchable grid of the ~150 habit icons (HabitIcons).
/// Edits the editor draft live, so the preview behind the sheet follows.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_swatch.dart';

Future<void> showHabitCustomizeSheet(
  BuildContext context,
  HabitEditorArgs args,
) => showFFBottomSheet<void>(
  context,
  builder: (_) => HabitCustomizeSheet(args: args),
);

class HabitCustomizeSheet extends ConsumerStatefulWidget {
  const HabitCustomizeSheet({required this.args, super.key});

  final HabitEditorArgs args;

  @override
  ConsumerState<HabitCustomizeSheet> createState() =>
      _HabitCustomizeSheetState();
}

class _HabitCustomizeSheetState extends ConsumerState<HabitCustomizeSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final draft = ref
        .watch(habitEditorControllerProvider(widget.args))
        .valueOrNull
        ?.draft;
    if (draft == null) return const SizedBox.shrink();
    final controller = ref.read(
      habitEditorControllerProvider(widget.args).notifier,
    );
    final colors = draft.colors;
    final icons = HabitIcons.search(_query);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FFIconTile.soft(
              icon: HabitIcons.of(draft.iconKey),
              colors: colors,
              size: AppSizes.iconTileLg,
              radius: AppRadii.tileLg,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(tr('Customize Habit'), style: context.text.title),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FFSectionLabel(tr('Colour')),
        Wrap(
          children: [
            for (final c in HabitPalette.colors)
              HabitSwatch(
                colors: c,
                selected: c.solid == colors.solid,
                slot: AppSizes.minTap,
                onTap: () => controller.setColorHex(HabitPalette.hexOf(c)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FFSectionLabel(tr('Icon')),
        FFSearchField(
          hint: tr('Search icons'),
          onChanged: (q) => setState(() => _query = q),
          onClear: () => setState(() => _query = ''),
        ),
        const SizedBox(height: AppSpacing.md),
        if (icons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              tr('No icons match "{v}"', {'v': _query}),
              textAlign: TextAlign.center,
              style: context.text.meta,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final e in icons)
                _IconCell(
                  entry: e,
                  selected: e.key == draft.iconKey,
                  colorsSolid: colors.solid,
                  idle: ff.surfaceMuted,
                  onTap: () => controller.setIcon(e.key),
                ),
            ],
          ),
      ],
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.entry,
    required this.selected,
    required this.colorsSolid,
    required this.idle,
    required this.onTap,
  });

  final HabitIconEntry entry;
  final bool selected;
  final Color colorsSolid;
  final Color idle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tr('{replaceAll} icon', {
        'replaceAll': entry.key.replaceAll('-', ' '),
      }),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          width: AppSizes.iconTileLg,
          height: AppSizes.iconTileLg,
          decoration: BoxDecoration(
            color: selected ? colorsSolid : idle,
            borderRadius: BorderRadius.circular(AppRadii.tileLg),
          ),
          child: Icon(
            entry.icon,
            size: HabitDimens.pickerIcon,
            color: selected ? HabitAccents.onColor : context.ff.inkMuted,
          ),
        ),
      ),
    );
  }
}
