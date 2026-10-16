/// ============================================================
/// ARCHIVE BOTTOM BAR — the two sticky buttons of Archive / Trash
/// ============================================================
///
/// What: "Restore all · Delete all" (Archive, on the canvas) and
/// "Recover (2) · Delete (2)" (Trash, on a raised surface sheet with
/// rounded top corners). Two equal buttons, 12 pt apart.
/// Why: one bar for both screens; it pads itself by the bottom inset, so
/// it sits above the home indicator (the screens cover the tab bar).
/// The buttons always stay side by side like the mockups: on a narrow
/// screen with large text the labels are capped at [_narrowMaxScale] and
/// lose their icons ([compact]) instead of stacking, which left room for ~1 row at 360 × 1.3.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class ArchiveBottomBar extends StatelessWidget {
  const ArchiveBottomBar({
    required this.start,
    required this.end,
    this.raised = false,
    super.key,
  });

  final Widget start;
  final Widget end;

  /// Surface sheet with a top shadow (Trash) instead of the plain canvas.
  final bool raised;

  /// Text-scale cap of the labels on screens narrower than 400 pt.
  static const double _narrowMaxScale = 1.1;

  /// True when the two labels ("Restore all", "Recover (2)") no longer fit
  /// next to their icons (360-pt phones, or large text below 400 pt): the
  /// screens then drop the button icons so the words stay readable.
  static bool compact(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 380 ||
        (width < 400 && MediaQuery.textScalerOf(context).scale(10) > 11);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final radius = raised
        ? const BorderRadius.vertical(top: Radius.circular(AppRadii.hero))
        : BorderRadius.zero;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: raised ? ff.surface : ff.canvas,
        borderRadius: radius,
        boxShadow: raised
            ? [
                BoxShadow(
                  color: ff.ink.withValues(alpha: ff.isDark ? 0.3 : 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.grouped,
            raised ? AppSpacing.md : AppSpacing.sm,
            AppSpacing.grouped,
            AppSpacing.sm,
          ),
          // Intrinsic height: the FF buttons centre their label and would
          // otherwise grow to the whole height the Scaffold offers.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: MediaQuery.sizeOf(context).width < 400
                ? _narrowMaxScale
                : double.infinity,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: start),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: end),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
