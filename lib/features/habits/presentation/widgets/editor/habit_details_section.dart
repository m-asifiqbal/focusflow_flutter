/// ============================================================
/// HABIT DETAILS SECTION — Name · Colour · Category · Habit type ·
/// Time of day (15)
/// ============================================================
///
/// The DETAILS grouped card of the habit editor. Rows open small sheets
/// (name entry, category list, build / quit choice, time of day — which
/// decides the Morning / Evening chip of the list); the Colour row picks
/// one of the five inline swatches directly (the full palette lives in
/// the Customize Habit sheet behind the preview icon).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/presentation/habit_editor_actions.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/habit_templates.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_editor_sheets.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_swatch.dart';

/// The accent-coloured row tile of the editor ("pen", "palette" …).
class HabitRowTile extends StatelessWidget {
  const HabitRowTile(this.icon, {this.colors, super.key});

  final IconData icon;

  /// Defaults to the accent (primary) trio.
  final ModuleColors? colors;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFIconTile.soft(
      icon: icon,
      colors:
          colors ??
          ModuleColors(
            solid: ff.primary,
            soft: ff.primarySoft,
            ink: ff.primaryStrong,
          ),
      size: HabitDimens.rowTile,
      radius: AppRadii.tile,
      iconSize: HabitDimens.rowIcon,
    );
  }
}

class HabitDetailsSection extends ConsumerWidget {
  const HabitDetailsSection({
    required this.args,
    required this.draft,
    super.key,
  });

  final HabitEditorArgs args;
  final Habit draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final c = ref.read(habitEditorControllerProvider(args).notifier);
    final name = draft.name.trim();

    Future<void> editName() async {
      final v = await showHabitTextSheet(
        context,
        title: 'Habit name',
        initial: draft.name,
        hint: 'e.g. Drink Water',
      );
      if (v != null) c.setName(v);
    }

    Future<void> pickCategory() async {
      final v = await showHabitOptionSheet<String>(
        context,
        title: 'Category',
        selected: draft.category,
        options: [for (final k in HabitCategories.all) HabitOption(k, k)],
      );
      if (v != null) c.setCategory(v);
    }

    Future<void> pickKind() async {
      final v = await showHabitOptionSheet<HabitKind>(
        context,
        title: 'Habit type',
        selected: draft.kind,
        options: [
          HabitOption(
            HabitKind.build,
            HabitFormat.kind(HabitKind.build),
            subtitle: 'Check in when you do it',
          ),
          HabitOption(
            HabitKind.quit,
            HabitFormat.kind(HabitKind.quit),
            subtitle: 'Log a slip when it happens',
          ),
        ],
      );
      if (v != null && context.mounted) {
        await changeHabitKind(context, ref, args, v);
      }
    }

    Future<void> pickPartOfDay() async {
      final v = await showHabitOptionSheet<PartOfDay>(
        context,
        title: 'Time of day',
        selected: draft.partOfDay,
        options: [
          for (final p in PartOfDay.values)
            HabitOption(p, HabitFormat.partOfDay(p)),
        ],
      );
      if (v != null) c.setPartOfDay(v);
    }

    return FFGroupedList(
      label: 'Details',
      children: [
        FFListRow(
          leading: const HabitRowTile(FontAwesomeIcons.pen),
          title: 'Name',
          value: name.isEmpty ? 'Add a name' : name,
          valueColor: name.isEmpty ? ff.inkFaint : null,
          onTap: editName,
        ),
        _ColourRow(
          selected: draft.colors.solid,
          onPick: (colors) => c.setColorHex(HabitPalette.hexOf(colors)),
        ),
        FFListRow(
          leading: const HabitRowTile(FontAwesomeIcons.layerGroup),
          title: 'Category',
          value: draft.category,
          valueColor: ff.primary,
          onTap: pickCategory,
        ),
        FFListRow(
          leading: const HabitRowTile(FontAwesomeIcons.arrowsUpDown),
          title: 'Habit type',
          value: HabitFormat.kind(draft.kind),
          onTap: pickKind,
        ),
        FFListRow(
          leading: const HabitRowTile(FontAwesomeIcons.cloudSun),
          title: 'Time of day',
          value: HabitFormat.partOfDay(draft.partOfDay),
          onTap: pickPartOfDay,
        ),
      ],
    );
  }
}

class _ColourRow extends StatelessWidget {
  const _ColourRow({required this.selected, required this.onPick});

  final Color selected;
  final ValueChanged<ModuleColors> onPick;

  @override
  Widget build(BuildContext context) {
    final swatches = HabitPalette.inline;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Swatches share what the label leaves (up to 36 pt each); when
            // that would shrink them below a 28-pt dot (360 pt at large
            // text) they move to a second line under the label instead.
            const leading =
                HabitDimens.rowTile + AppSpacing.md + AppSpacing.xxs;
            final style = context.text.rowTitle;
            final painter = TextPainter(
              text: TextSpan(text: 'Colour', style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final labelWidth = painter.width;
            painter.dispose();
            final room =
                constraints.maxWidth - leading - labelWidth - AppSpacing.sm;
            final inline = room / swatches.length >= HabitDimens.swatch;
            final slot =
                ((inline ? room : constraints.maxWidth - leading) /
                        swatches.length)
                    .clamp(0.0, HabitDimens.swatchSlot);
            final dots = [
              for (final s in swatches)
                HabitSwatch(
                  colors: s,
                  selected: s.solid == selected,
                  slot: slot,
                  onTap: () => onPick(s),
                ),
            ];
            final label = Row(
              children: [
                const HabitRowTile(FontAwesomeIcons.palette),
                const SizedBox(width: leading - HabitDimens.rowTile),
                Expanded(
                  child: Text(
                    'Colour',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                if (inline) ...dots,
              ],
            );
            if (inline) return label;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: leading),
                  child: Row(children: dots),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
