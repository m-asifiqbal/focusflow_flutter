/// ============================================================
/// FF ICON TILE — the rounded-square module icon (sizes 32–64)
/// ============================================================
///
/// * solid — module solid fill + white icon (Library cards, Settings rows).
/// * soft  — module soft fill + module-coloured icon (Archive rows).
/// * tint  — solid @13% + module-coloured icon (Item actions sheet, 09).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

enum FFIconTileStyle { solid, soft, tint }

class FFIconTile extends StatelessWidget {
  const FFIconTile({
    required this.icon,
    required this.colors,
    this.size = AppSizes.iconTile,
    this.style = FFIconTileStyle.solid,
    this.radius,
    this.iconSize,
    this.semanticLabel,
    super.key,
  });

  /// Soft fill + coloured icon.
  const FFIconTile.soft({
    required this.icon,
    required this.colors,
    this.size = AppSizes.iconTile,
    this.radius,
    this.iconSize,
    this.semanticLabel,
    super.key,
  }) : style = FFIconTileStyle.soft;

  final IconData icon;
  final ModuleColors colors;
  final double size;
  final FFIconTileStyle style;

  /// Corner radius; defaults scale with [size] (9 → 14 → 30%).
  final double? radius;
  final double? iconSize;
  final String? semanticLabel;

  /// Default corner radius for a tile of [size].
  static double radiusFor(double size) {
    if (size <= 34) return AppRadii.tileSm;
    if (size <= 40) return AppRadii.tile;
    if (size <= 48) return AppRadii.tileLg;
    return size * 0.3;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final (Color bg, Color fg) = switch (style) {
      FFIconTileStyle.solid => (colors.solid, ff.onGradient),
      FFIconTileStyle.soft => (colors.softFor(ff.brightness), colors.solid),
      FFIconTileStyle.tint => (
        colors.solid.withValues(alpha: 0.13),
        colors.solid,
      ),
    };
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius ?? radiusFor(size)),
        ),
        child: Icon(icon, size: iconSize ?? size * 0.42, color: fg),
      ),
    );
  }
}
