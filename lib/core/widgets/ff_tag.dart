/// ============================================================
/// FF TAG · BADGE · DOT · INSET DIVIDER — small decorative atoms
/// ============================================================
///
/// * [FFTag]   — 10 w800 UPPERCASE pill (radius 6) in the tag palette
///               ("WORK", "FINANCE"). Keeps its pastel look in dark mode,
///               exactly like the dark home mockup (37).
/// * [FFBadge] — status pill ("3 LEFT", "CONNECTED", "STRONG"); adapts
///               to dark mode (solid @15% + lightened ink). `uppercase:
///               false` reads as text instead ("Synced 2 min ago": sentence
///               case, medium weight, no tracking).
/// * [FFDot]   — a small coloured circle (calendar dots, legends).
/// * [FFDividerInset] — 1px row separator inset 60 from the start.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

class FFTag extends StatelessWidget {
  const FFTag(this.label, {this.colors, this.uppercase = true, super.key});

  final String label;

  /// Defaults to [TagPalette.forName] of [label].
  final ModuleColors? colors;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? TagPalette.forName(label);
    // Light-mode trios are pale; dark mode needs the adapted pair.
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: c.softFor(brightness),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.tag.copyWith(color: c.inkFor(brightness)),
      ),
    );
  }
}

class FFBadge extends StatelessWidget {
  const FFBadge(
    this.label, {
    this.colors,
    this.icon,
    this.solid = false,
    this.uppercase = true,
    super.key,
  });

  final String label;

  /// False: the label as written, medium weight, no letter spacing.
  final bool uppercase;

  /// Defaults to the primary family.
  final ModuleColors? colors;
  final IconData? icon;

  /// Solid fill + white text instead of the soft tint.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final Color bg;
    final Color fg;
    if (colors == null) {
      bg = solid ? ff.primary : ff.primarySoft;
      fg = solid ? ff.onPrimary : ff.primaryStrong;
    } else {
      bg = solid ? colors!.solid : colors!.softFor(ff.brightness);
      fg = solid ? ff.onGradient : colors!.inkFor(ff.brightness);
    }
    final style = uppercase
        ? context.text.tag.copyWith(fontSize: 11.5, color: fg)
        : context.text.tag.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            color: fg,
          );
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class FFDot extends StatelessWidget {
  const FFDot({this.color, this.size = 6, super.key});

  /// Defaults to primary.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? context.ff.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class FFDividerInset extends StatelessWidget {
  const FFDividerInset({
    this.indent = AppSpacing.dividerInset,
    this.endIndent = 0,
    this.color,
    super.key,
  });

  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: ColoredBox(color: color ?? context.ff.divider),
      ),
    );
  }
}
