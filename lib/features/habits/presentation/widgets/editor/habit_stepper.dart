/// ============================================================
/// HABIT STEPPER — "( – )  8  ( + )" of the habit editor (mockup 15)
/// ============================================================
///
/// Soft round 32-pt buttons inside 44-pt tap targets around a bold value.
/// Used for the daily target, "X times per week" and "Every N days".
/// Long-pressing a button repeats nothing on purpose: targets are small
/// numbers and the unit / value can also be typed in a sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitStepper extends StatelessWidget {
  const HabitStepper({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.semanticLabel,
    super.key,
  });

  final int value;

  /// Null disables the stepper (both buttons and a faint value).
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;

  /// What the value counts ("Daily target") — announced with the value.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: FontAwesomeIcons.minus,
          label: 'Decrease $semanticLabel',
          onTap: change != null && value > min ? () => change(value - 1) : null,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: HabitDimens.stepperValue),
          child: Semantics(
            label: semanticLabel,
            value: '$value',
            liveRegion: true,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.text.stat.copyWith(
                fontSize: HabitDimens.stepperText,
                color: change == null ? context.ff.inkFaint : null,
              ),
            ),
          ),
        ),
        _StepButton(
          icon: FontAwesomeIcons.plus,
          label: 'Increase $semanticLabel',
          onTap: change != null && value < max ? () => change(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: Container(
              width: HabitDimens.stepperButton,
              height: HabitDimens.stepperButton,
              decoration: BoxDecoration(
                color: ff.primarySoft.withValues(alpha: enabled ? 0.6 : 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: HabitDimens.stepperIcon,
                color: enabled ? ff.primary : ff.inkFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
