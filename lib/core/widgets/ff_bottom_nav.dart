/// ============================================================
/// FF BOTTOM NAV — floating glass pill: Home · Library · [+] · Insights · Settings
/// ============================================================
///
/// A frosted-glass capsule that floats above the content (blurred backdrop,
/// soft sheen, hairline border). The active tab grows into an inner pill
/// with icon + label; the others are icon-only and get their label through
/// Semantics. The Quick Add "+" sits *inside* the capsule as a gradient
/// circle — there is no canvas-coloured ring or raised area, so nothing
/// opaque shows around it on any screen (mint, white editor, dark vault).
///
/// Use it with `Scaffold(extendBody: true)` (the app shell does) so content
/// scrolls under the glass; screens keep `AppSpacing.bottomBarClearance`
/// bottom padding. [currentIndex] is the tab index 0..3 (the + is not a tab).
/// ============================================================
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

/// One tab of [FFBottomNav].
@immutable
class FFNavItem {
  const FFNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class FFBottomNav extends StatelessWidget {
  const FFBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onFab,
    this.items = defaultItems,
    this.fabSemanticLabel = 'Quick add',
    super.key,
  });

  /// Active tab (0..3).
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Centre + (always opens Quick Add).
  final VoidCallback onFab;

  /// Exactly 4 tabs (2 either side of the +).
  final List<FFNavItem> items;
  final String fabSemanticLabel;

  static const List<FFNavItem> defaultItems = [
    FFNavItem(icon: FontAwesomeIcons.house, label: 'Home'),
    FFNavItem(icon: FontAwesomeIcons.layerGroup, label: 'Library'),
    FFNavItem(icon: FontAwesomeIcons.chartPie, label: 'Insights'),
    FFNavItem(icon: FontAwesomeIcons.gear, label: 'Settings'),
  ];

  /// Capsule height (the + and the active pill sit inside it).
  static const double height = 64;
  static const double _sideMargin = AppSpacing.lg;
  static const double _radius = height / 2;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Float just above the home indicator (or 12 pt from the edge).
    final bottomGap = bottomInset > 0
        ? bottomInset - AppSpacing.xs
        : AppSpacing.md;
    final glass = _GlassColors.of(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          _sideMargin,
          AppSpacing.sm,
          _sideMargin,
          bottomGap,
        ),
        child: DecoratedBox(
          // Shadow outside the clip so the capsule lifts off the content.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: glass.shadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glass.fill,
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: glass.border),
                ),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        // Icon-only tabs get a fixed slot; the active pill
                        // gets whatever is left, so nothing can overflow.
                        final activeMax =
                            (c.maxWidth - _Fab._size - 3 * _tabSlot)
                                .clamp(AppSizes.minTap, double.infinity)
                                .toDouble();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _tab(0, activeMax),
                            _tab(1, activeMax),
                            _Fab(onTap: onFab, semanticLabel: fabSemanticLabel),
                            _tab(2, activeMax),
                            _tab(3, activeMax),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Width reserved for an icon-only tab (≥ 44 pt tap target).
  static const double _tabSlot = 46;

  /// The active pill may grow up to [activeMax] (its label fades out on a
  /// narrow phone / large text); the others sit in a fixed slot.
  Widget _tab(int i, double activeMax) {
    final active = i == currentIndex;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: AppSizes.minTap,
        maxWidth: active ? activeMax : _tabSlot,
      ),
      child: _Tab(item: items[i], active: active, onTap: () => onTap(i)),
    );
  }
}

/// Glass tokens derived from the theme (light: milky white over mint;
/// dark: smoked emerald) so dark mode and accents work for free.
class _GlassColors {
  const _GlassColors({
    required this.fill,
    required this.border,
    required this.shadow,
    required this.activeFill,
    required this.activeBorder,
    required this.active,
    required this.inactive,
  });

  final Gradient fill;
  final Color border;
  final List<BoxShadow> shadow;
  final Color activeFill;
  final Color activeBorder;
  final Color active;
  final Color inactive;

  factory _GlassColors.of(BuildContext context) {
    final ff = context.ff;
    if (ff.isDark) {
      return _GlassColors(
        fill: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ff.tabBar.withValues(alpha: 0.78),
            ff.tabBar.withValues(alpha: 0.88),
          ],
        ),
        border: Colors.white.withValues(alpha: 0.10),
        shadow: [
          BoxShadow(
            offset: const Offset(0, 14),
            blurRadius: 32,
            spreadRadius: -12,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ],
        activeFill: Colors.white.withValues(alpha: 0.12),
        activeBorder: Colors.white.withValues(alpha: 0.14),
        active: ff.primary,
        inactive: ff.inkMuted,
      );
    }
    return _GlassColors(
      fill: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ff.surface.withValues(alpha: 0.82),
          Color.alphaBlend(
            ff.primarySoft.withValues(alpha: 0.35),
            ff.surface,
          ).withValues(alpha: 0.72),
        ],
      ),
      border: Colors.white.withValues(alpha: 0.75),
      shadow: [
        BoxShadow(
          offset: const Offset(0, 16),
          blurRadius: 36,
          spreadRadius: -14,
          color: ff.primaryStrong.withValues(alpha: 0.35),
        ),
        ...ff.cardShadow,
      ],
      activeFill: ff.primary.withValues(alpha: 0.12),
      activeBorder: ff.primary.withValues(alpha: 0.16),
      active: ff.primaryStrong,
      inactive: ff.primary.withValues(alpha: 0.55),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.active, required this.onTap});

  final FFNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = _GlassColors.of(context);
    final duration = context.motion(AppMotion.normal);
    final color = active ? glass.active : glass.inactive;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.92,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.curve,
          height: 46,
          padding: EdgeInsets.symmetric(
            horizontal: active ? AppSpacing.lg : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: active
                ? glass.activeFill
                : glass.activeFill.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: active
                  ? glass.activeBorder
                  : glass.activeBorder.withValues(alpha: 0),
            ),
          ),
          // Laid out at its natural width and clipped to the pill, so the
          // label's open/close animation can never overflow the tab slot.
          child: UnconstrainedBox(
            clipBehavior: Clip.hardEdge,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: duration,
                  builder: (context, c, _) =>
                      Icon(item.icon, size: 19, color: c),
                ),
                // The label slides open next to the icon on the active tab.
                TweenAnimationBuilder<double>(
                  tween: Tween(end: active ? 1 : 0),
                  duration: duration,
                  curve: AppMotion.curve,
                  builder: (context, t, child) => t == 0
                      ? const SizedBox.shrink()
                      : ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: t,
                            child: Opacity(opacity: t, child: child),
                          ),
                        ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.sm,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: context.text.buttonSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
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

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            gradient: ff.primaryGradient,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 8),
                blurRadius: 18,
                spreadRadius: -6,
                color: ff.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
          child: Center(
            child: Icon(FontAwesomeIcons.plus, size: 20, color: ff.onGradient),
          ),
        ),
      ),
    );
  }
}
