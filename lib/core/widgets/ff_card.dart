/// ============================================================
/// FF CARD — the white, softly-shadowed rounded surface (radius 22)
/// ============================================================
///
/// Light: white + card shadow `0 6 24 -12 rgba(6,78,59,.18)`.
/// Dark: white @4% + 1px white @10% border, no shadow (screen 37).
/// Optional tap → press-scale 0.98 via [FFPressable].
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';

class FFCard extends StatelessWidget {
  const FFCard({
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.lg),
    this.radius = AppRadii.card,
    this.color,
    this.gradient,
    this.shadow = true,
    this.border = true,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.clip = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Background override (note colours, tinted cards). Defaults to surface.
  final Color? color;

  /// Background gradient (hero cards). Wins over [color].
  final Gradient? gradient;

  /// Card shadow (light mode only — the dark token list is empty).
  final bool shadow;

  /// 1px surfaceBorder (visible in dark mode only).
  final bool border;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// Clip children to the rounded shape.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final shape = BorderRadius.circular(radius);
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? ff.surface) : null,
        gradient: gradient,
        borderRadius: shape,
        border: border && gradient == null
            ? Border.all(color: ff.surfaceBorder)
            : null,
        boxShadow: shadow ? ff.cardShadow : null,
      ),
      child: clip
          ? ClipRRect(
              borderRadius: shape,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
    if (onTap != null || onLongPress != null || semanticLabel != null) {
      card = FFPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
