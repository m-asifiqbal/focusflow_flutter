/// ============================================================
/// FF EMPTY STATE — the screen-29 illustration + copy + CTA
/// ============================================================
///
/// Concentric soft circles in the module colour, a gradient module tile
/// rotated −8° with a glow, two sparkle stars; title (22 w700), muted body,
/// gradient CTA and a tappable hint ("Try: …"). [compact] is the small
/// in-card variant (no circles, no big button).
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/core/widgets/ff_icon_tile.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

class FFEmptyState extends StatelessWidget {
  const FFEmptyState({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
    this.ctaIcon = FontAwesomeIcons.plus,
    this.hint,
    this.onHint,
    this.compact = false,
    super.key,
  });

  /// Small in-card variant ("No tasks today").
  const FFEmptyState.compact({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
    this.ctaIcon = FontAwesomeIcons.plus,
    this.hint,
    this.onHint,
    super.key,
  }) : compact = true;

  final ModuleColors colors;
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final IconData? ctaIcon;

  /// Example prompt under the CTA ('Try: "Remind me to stretch…"').
  final String? hint;
  final VoidCallback? onHint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    final ff = context.ff;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: _Illustration(colors: colors, icon: icon),
          ),
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.title.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(fontSize: 14.5, height: 1.6),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: FFPrimaryButton(
                label: ctaLabel!,
                icon: ctaIcon,
                onPressed: onCta,
              ),
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FFTextButton(
              label: hint!,
              onPressed: onHint,
              style: context.text.rowTitle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ff.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FFIconTile.soft(icon: icon, colors: colors, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.cardTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(fontSize: 13.5),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            FFTextButton(label: ctaLabel!, icon: ctaIcon, onPressed: onCta),
          ],
          if (hint != null)
            FFTextButton(
              label: hint!,
              onPressed: onHint,
              color: context.ff.inkMuted,
            ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.colors, required this.icon});

  final ModuleColors colors;
  final IconData icon;

  static const double _size = 176;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final soft = colors.softFor(ff.brightness);
    final hsl = HSLColor.fromColor(colors.solid);
    final light = hsl
        .withLightness((hsl.lightness + 0.07).clamp(0.0, 1.0))
        .toColor();
    final deep = hsl
        .withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0))
        .toColor();
    final star = colors.solid.withValues(alpha: 0.55);
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: soft.withValues(alpha: soft.a * 0.6),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: ff.surface.withValues(alpha: ff.surface.a * 0.5),
              shape: BoxShape.circle,
            ),
          ),
          Transform.rotate(
            angle: -8 * math.pi / 180,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [light, deep],
                ),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 14),
                    blurRadius: 30,
                    spreadRadius: -6,
                    color: colors.solid.withValues(alpha: 0.45),
                  ),
                ],
              ),
              child: Icon(icon, size: 32, color: ff.onGradient),
            ),
          ),
          PositionedDirectional(
            top: 20,
            end: 24,
            child: Icon(FontAwesomeIcons.solidStar, size: 18, color: star),
          ),
          PositionedDirectional(
            bottom: 36,
            start: 18,
            child: Icon(FontAwesomeIcons.solidStar, size: 11, color: star),
          ),
        ],
      ),
    );
  }
}
