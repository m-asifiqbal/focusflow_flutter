/// ============================================================
/// HABIT SWATCH — one colour dot of the editor (mockup 15 Colour row)
/// ============================================================
///
/// A 28-pt dot in a [slot]-wide, 44-pt-tall tap area; the selected swatch
/// gets a ring in its own colour with a surface-coloured gap. Announced as
/// "Blue colour, selected".
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitSwatch extends StatelessWidget {
  const HabitSwatch({
    required this.colors,
    required this.selected,
    required this.onTap,
    this.slot = HabitDimens.swatchSlot,
    super.key,
  });

  final ModuleColors colors;
  final bool selected;
  final VoidCallback onTap;

  /// Width of the tap area (the dot shrinks to fit when it is smaller).
  final double slot;

  @override
  Widget build(BuildContext context) {
    final outer = slot < HabitDimens.swatchSlot ? slot : HabitDimens.swatchSlot;
    return Semantics(
      button: true,
      selected: selected,
      label: tr('{nameOf} colour', {'nameOf': HabitPalette.nameOf(colors)}),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: SizedBox(
          width: slot,
          height: AppSizes.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(AppMotion.fast),
              width: outer,
              height: outer,
              // Ring + transparent gap around the dot (dot = outer − 8).
              padding: const EdgeInsets.all(HabitDimens.swatchRing),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.solid : Colors.transparent,
                  width: HabitDimens.swatchRing,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.solid,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
