/// ============================================================
/// HABIT CHECK BUTTON — the card's 44-pt "+" / "✓" button (mockup 14)
/// ============================================================
///
/// Pending: outlined in the faded habit colour with a "+" (build) — tap
/// adds a check-in. Done: filled with the habit colour and a white check
/// (build: goal met; quit: clean today). Long-press opens the amount
/// sheet (custom amount / skip today). The fill cross-fades and the icon
/// pops on change; both are instant under reduce motion.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitCheckButton extends StatelessWidget {
  const HabitCheckButton({
    required this.done,
    required this.colors,
    required this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final bool done;
  final ModuleColors colors;

  /// Spoken action ("Check in Drink Water", "Undo check-in …").
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(AppMotion.normal);
    return Semantics(
      button: true,
      toggled: done,
      label: semanticLabel,
      onLongPressHint: onLongPress == null ? null : 'Custom amount or skip',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.curve,
          width: HabitDimens.checkButton,
          height: HabitDimens.checkButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? colors.solid : Colors.transparent,
            borderRadius: BorderRadius.circular(HabitDimens.checkRadius),
            border: Border.all(
              color: done ? colors.solid : HabitAccents.pendingBorder(colors),
              width: HabitDimens.checkBorder,
            ),
          ),
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              done ? FontAwesomeIcons.check : FontAwesomeIcons.plus,
              key: ValueKey(done),
              size: HabitDimens.checkIcon,
              color: done ? HabitAccents.onColor : colors.solid,
            ),
          ),
        ),
      ),
    );
  }
}
