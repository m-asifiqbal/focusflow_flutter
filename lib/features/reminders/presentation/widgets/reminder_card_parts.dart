/// ============================================================
/// REMINDER CARD PARTS — time column, bordered frame, action pills
/// ============================================================
///
/// What: the building blocks of [ReminderCard]: the "07:00 / AM" time
/// label, the rounded card with its 4 pt coloured start edge (the
/// colour shows as a crescent along the rounded corners, like the
/// mockup), the SNOOZE / MARK DONE pills and the done check.
/// Why: keeps reminder_card.dart short; all colours from tokens.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_labels.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';

/// "07:00" (15.5 w700) over "AM", end-aligned.
class ReminderTimeLabel extends StatelessWidget {
  const ReminderTimeLabel({
    required this.at,
    this.use24h = false,
    this.danger = false,
    this.emphasis = false,
    super.key,
  });

  final DateTime at;
  final bool use24h;

  /// Missed reminders: red time.
  final bool danger;

  /// The next-due row: bolder time.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final meridiem = ReminderLabels.meridiem(at, use24h: use24h);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: ReminderSizes.timeTop),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                ReminderLabels.time(at, use24h: use24h),
                maxLines: 1,
                style:
                    (emphasis
                            ? context.text.reminderTimeNext
                            : context.text.reminderTime)
                        .copyWith(color: danger ? ff.danger : ff.ink),
              ),
            ),
            if (meridiem != null) ...[
              const SizedBox(height: ReminderSizes.hairGap),
              Text(
                meridiem,
                maxLines: 1,
                style: context.text.reminderMeridiem.copyWith(
                  color: danger
                      ? ff.danger.withValues(alpha: 0.7)
                      : ff.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded surface card with a coloured 4 pt start edge.
class ReminderCardFrame extends StatelessWidget {
  const ReminderCardFrame({
    required this.accent,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.bottomPadding = ReminderSizes.cardVertical,
    this.elevated = false,
    super.key,
  });

  /// The next-due card: deeper shadow ([ReminderShadows.reminderNextShadow]).
  final bool elevated;

  /// Edge colour.
  final Color accent;
  final Widget child;

  /// Smaller when the last child brings its own tap-target padding.
  final double bottomPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double edge = 4;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        // Shadow only: the (possibly translucent) surface is painted
        // below so the accent never shows through it in dark mode.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: elevated ? ff.reminderNextShadow : ff.cardShadow,
        ),
        child: CustomPaint(
          painter: _EdgedCardPainter(
            accent: accent,
            surface: ff.surface,
            border: ff.isDark ? ff.surfaceBorder : null,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
          child: Padding(
            // End 12: CupertinoSwitch has 4 pt of built-in margin.
            padding: EdgeInsetsDirectional.fromSTEB(
              edge + AppSpacing.lg,
              ReminderSizes.cardVertical,
              AppSpacing.md,
              bottomPadding,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Paints the surface (inset by [ReminderCardFrame.edge] on the start
/// side) and the accent crescent between it and the outer rounded rect.
class _EdgedCardPainter extends CustomPainter {
  const _EdgedCardPainter({
    required this.accent,
    required this.surface,
    required this.rtl,
    this.border,
  });

  final Color accent;
  final Color surface;
  final Color? border;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(AppRadii.card);
    const edge = ReminderCardFrame.edge;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(rtl ? 0 : edge, 0, size.width - edge, size.height),
      radius,
    );
    canvas.drawRRect(inner, Paint()..color = surface);
    final line = border;
    if (line != null) {
      canvas.drawRRect(
        inner.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = line,
      );
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRRect(outer),
        Path()..addRRect(inner),
      ),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_EdgedCardPainter old) =>
      old.accent != accent ||
      old.surface != surface ||
      old.border != border ||
      old.rtl != rtl;
}

/// "SNOOZE 10m" / "MARK DONE" / "RESCHEDULE" pill (44 pt tap target).
class ReminderActionPill extends StatelessWidget {
  const ReminderActionPill({
    required this.label,
    this.colors,
    this.primary = false,
    this.onTap,
    super.key,
  });

  final String label;

  /// Tint (ignored when [primary]: the accent colour).
  final ModuleColors? colors;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tint = colors;
    final Color fg;
    final Color bg;
    if (primary || tint == null) {
      fg = ff.primary;
      bg = ff.primary.withValues(alpha: ff.isDark ? 0.18 : 0.08);
    } else {
      fg = ff.isDark
          ? tint.inkFor(ff.brightness)
          : Color.lerp(tint.solid, tint.ink, 0.35)!;
      bg = tint.solid.withValues(alpha: ff.isDark ? 0.18 : 0.09);
    }
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Visual 24 pt pill, 44 pt hit area.
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: ReminderSizes.pillHitPad,
          ),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: ReminderSizes.pillMinHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: ReminderSizes.pillHorizontal,
              vertical: ReminderSizes.pillVertical,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.tileSm),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: context.text.reminderPill.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled check shown instead of the toggle on done occurrences.
class ReminderDoneCheck extends StatelessWidget {
  const ReminderDoneCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Container(
      width: ReminderSizes.doneCheck,
      height: ReminderSizes.doneCheck,
      margin: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ff.primary, shape: BoxShape.circle),
      child: Icon(
        FontAwesomeIcons.check,
        size: ReminderSizes.doneCheckGlyph,
        color: ff.onPrimary,
      ),
    );
  }
}
