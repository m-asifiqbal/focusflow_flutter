/// ============================================================
/// PRAYER DAY PARTS — the pieces of a PrayerDayCard row
/// ============================================================
///
/// [PrayerRail] (the line through the day and a row's status dot),
/// [PrayerResultLabel] ("On time ✓", "Now"), [PrayerMarkButton] (the open
/// prayer's one-tap action: 40 pt high, 12 pt corners — not a pill) and
/// [PrayerSquareButton] (+1 on a counter).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

/// The vertical line through the day with this row's status dot.
class PrayerRail extends StatelessWidget {
  const PrayerRail({
    required this.state,
    required this.color,
    required this.first,
    required this.last,
    super.key,
  });

  final PrayerSlotState state;
  final Color color;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const size = PrayerStyle.railDot;
    Widget line(bool show) =>
        Center(child: Container(width: 2, color: show ? ff.divider : null));
    final Widget dot = switch (state) {
      PrayerSlotState.done || PrayerSlotState.missed => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: PrayerStyle.state(ff, state),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          state == PrayerSlotState.done
              ? FontAwesomeIcons.check
              : FontAwesomeIcons.xmark,
          size: 9,
          color: ff.onGradient,
        ),
      ),
      PrayerSlotState.open || PrayerSlotState.endingSoon => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
      PrayerSlotState.excused => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: ff.inkFaint, shape: BoxShape.circle),
      ),
      PrayerSlotState.upcoming => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ff.inkFaint, width: 2),
        ),
      ),
    };
    return SizedBox(
      width: size,
      child: Column(
        children: [
          SizedBox(height: AppSpacing.md + 2, child: line(!first)),
          dot,
          Expanded(child: line(!last)),
        ],
      ),
    );
  }
}

/// "On time ✓" / "Missed ✕" on the end of a marked row.
class PrayerResultLabel extends StatelessWidget {
  const PrayerResultLabel({
    required this.label,
    required this.color,
    required this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: AppSpacing.xs),
      Text(
        label,
        style: context.text.meta.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// The open prayer's one-tap action (12 pt corners, 44 pt tap target).
class PrayerMarkButton extends StatelessWidget {
  const PrayerMarkButton({
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      child: Container(
        height: PrayerStyle.markButton,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Text(
          label,
          style: context.text.buttonSmall.copyWith(
            color: context.ff.onGradient,
          ),
        ),
      ),
    ),
  );
}

/// A square icon button (+1 on a counter).
class PrayerSquareButton extends StatelessWidget {
  const PrayerSquareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      child: Container(
        width: AppSizes.minTap,
        height: AppSizes.minTap,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );
}
