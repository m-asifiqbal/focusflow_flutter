/// ============================================================
/// ONBOARDING HERO — app tile + floating module chips (screen 01)
/// ============================================================
///
/// A 342×330 illustration: two concentric soft circles, the -8° rotated
/// primary-gradient app tile (radius 40) with the page's glyph, and five
/// white chips that float 6 pt up and down on a 3 s loop, staggered.
/// Scales down with a FittedBox on small screens; chips are kept inside
/// the box (see [_ChipLayout]) and mirror in RTL; under reduce motion the
/// chips stand still.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// One floating chip of the illustration, positioned in the 342×330 box.
class HeroChip {
  const HeroChip({
    required this.label,
    required this.icon,
    required this.colors,
    required this.position,
  });

  final String label;
  final IconData icon;
  final ModuleColors colors;

  /// Top-left corner inside the 342×330 box.
  final Offset position;
}

class OnboardingHero extends StatefulWidget {
  const OnboardingHero({required this.icon, required this.chips, super.key});

  /// Glyph on the app tile (bolt, shield, cloud).
  final IconData icon;
  final List<HeroChip> chips;

  static const Size size = Size(342, 330);
  static const Offset _center = Offset(171, 155);

  @override
  State<OnboardingHero> createState() => _OnboardingHeroState();
}

class _OnboardingHeroState extends State<OnboardingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const c = OnboardingHero._center;
    Widget circle(double d, double alpha) => Positioned(
      left: c.dx - d / 2,
      top: c.dy - d / 2,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // primarySoft is opaque in light, already translucent in dark.
          color: ff.primarySoft.withValues(
            alpha: ff.primarySoft.a * alpha * (ff.isDark ? 1.6 : 1),
          ),
        ),
      ),
    );
    const tile = 148.0;
    return ExcludeSemantics(
      child: FittedBox(
        child: SizedBox.fromSize(
          size: OnboardingHero.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              circle(262, 0.45),
              circle(190, 0.55),
              Positioned(
                left: c.dx - tile / 2,
                top: c.dy - tile / 2,
                child: Transform.rotate(
                  angle: -8 * math.pi / 180,
                  child: Container(
                    width: tile,
                    height: tile,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: ff.primaryGradient,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: ff.heroShadow,
                    ),
                    // White on the gradient in both modes (onPrimary is dark in dark).
                    child: Icon(widget.icon, size: 54, color: AppPalette.white),
                  ),
                ),
              ),
              for (final (i, chip) in widget.chips.indexed)
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _ChipLayout(
                      chip.position,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                    child: AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) {
                        final t = _float.value + i / widget.chips.length;
                        return Transform.translate(
                          offset: Offset(0, math.sin(t * 2 * math.pi) * 3),
                          child: child,
                        );
                      },
                      child: _Chip(chip: chip),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Places a chip at its mockup offset, but never past the box's end edge:
/// a label wider than the mockup's (or a bigger font) grows inward instead
/// of running off the screen. Mirrors the picture in RTL.
class _ChipLayout extends SingleChildLayoutDelegate {
  const _ChipLayout(this.position, {required this.rtl});

  final Offset position;
  final bool rtl;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = math.max(0.0, size.width - childSize.width);
    final x = position.dx.clamp(0.0, maxX);
    return Offset(rtl ? maxX - x : x, position.dy);
  }

  @override
  bool shouldRelayout(_ChipLayout old) =>
      old.position != position || old.rtl != rtl;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});

  final HeroChip chip;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.lg + 2,
        AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: ff.isDark ? ff.sheet : ff.surface,
        borderRadius: BorderRadius.circular(AppRadii.row),
        border: Border.all(color: ff.surfaceBorder),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -8,
            color: ff.ink.withValues(alpha: ff.isDark ? 0.4 : 0.14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FFIconTile(icon: chip.icon, colors: chip.colors, size: 30),
          const SizedBox(width: AppSpacing.md - 2),
          Text(
            chip.label,
            maxLines: 1,
            // Part of a fixed-size picture (excluded from semantics); the
            // FittedBox already scales it, so don't grow it with text size.
            textScaler: TextScaler.noScaling,
            style: context.text.cardTitle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
