/// ============================================================
/// FF ROUND ICON BUTTON — the 44×44 circular header button
/// ============================================================
///
/// * surface — white circle + soft card shadow, primary icon (light);
///             white @4% + 1px border in dark (screens 03/07/37).
/// * accent  — filled primary circle, white icon (calendar "+").
/// * dark    — vault glass: white @5% + 1px border, emerald-400 icon (17/18).
/// Optional red [badge] dot (unread notifications). Always pass a
/// [semanticLabel] — the button is icon-only.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

enum FFRoundIconButtonVariant { surface, accent, dark }

class FFRoundIconButton extends StatelessWidget {
  const FFRoundIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = FFRoundIconButtonVariant.surface,
    this.badge = false,
    this.size = AppSizes.roundButton,
    this.iconSize = 17,
    this.iconColor,
    super.key,
  });

  final IconData icon;

  /// Screen-reader label (required: the button has no text).
  final String semanticLabel;
  final VoidCallback? onPressed;
  final FFRoundIconButtonVariant variant;

  /// Shows the red notification dot.
  final bool badge;
  final double size;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final (BoxDecoration decoration, Color fg) = switch (variant) {
      FFRoundIconButtonVariant.surface => (
        BoxDecoration(
          color: ff.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ff.surfaceBorder),
          boxShadow: ff.cardShadow,
        ),
        ff.primaryStrong,
      ),
      FFRoundIconButtonVariant.accent => (
        BoxDecoration(
          color: ff.primary,
          shape: BoxShape.circle,
          boxShadow: ff.heroShadow,
        ),
        ff.onPrimary,
      ),
      FFRoundIconButtonVariant.dark => (
        BoxDecoration(
          color: ff.vaultSurface,
          shape: BoxShape.circle,
          border: Border.all(color: ff.vaultBorder),
        ),
        ff.vaultAccent,
      ),
    };
    final dotRing = switch (variant) {
      FFRoundIconButtonVariant.surface => ff.isDark ? ff.canvas : ff.surface,
      FFRoundIconButtonVariant.accent => ff.primary,
      FFRoundIconButtonVariant.dark => ff.vaultCanvas,
    };
    final dot = size * 0.2;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: badge
          ? tr('{semanticLabel}, new', {'semanticLabel': semanticLabel})
          : semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        scale: 0.94,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: decoration,
                    child: Center(
                      child: Icon(icon, size: iconSize, color: iconColor ?? fg),
                    ),
                  ),
                ),
                if (badge)
                  PositionedDirectional(
                    top: size * 0.16,
                    end: size * 0.18,
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        color: ff.dangerSolid,
                        shape: BoxShape.circle,
                        border: Border.all(color: dotRing, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
