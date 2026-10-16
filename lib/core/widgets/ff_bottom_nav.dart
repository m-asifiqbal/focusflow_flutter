/// ============================================================
/// FF BOTTOM NAV — Home · Library · [+] · Insights · Settings
/// ============================================================
///
/// Tab bar (`ff.tabBar`, rounded top corners, 64 pt + bottom safe area)
/// with a raised 60 pt gradient FAB in a 4 pt canvas-coloured ring, lifted
/// 28 pt above the bar. Active tab = primary + dot under the label;
/// inactive = primary @45% (light) / faint ink (dark).
///
/// The widget's own height includes the FAB's raised area (transparent), so
/// use it with `Scaffold(extendBody: true)` — [FFScaffold] does this.
/// [currentIndex] is the tab index 0..3 (the FAB is not a tab).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

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

  /// Centre FAB (always opens Quick Add).
  final VoidCallback onFab;

  /// Exactly 4 tabs (2 either side of the FAB).
  final List<FFNavItem> items;
  final String fabSemanticLabel;

  static const List<FFNavItem> defaultItems = [
    FFNavItem(icon: FontAwesomeIcons.house, label: 'Home'),
    FFNavItem(icon: FontAwesomeIcons.layerGroup, label: 'Library'),
    FFNavItem(icon: FontAwesomeIcons.chartPie, label: 'Insights'),
    FFNavItem(icon: FontAwesomeIcons.gear, label: 'Settings'),
  ];

  static const double _raise = AppSizes.fabRaise + AppSizes.fabRing;
  static const double _fabOuter = AppSizes.fab + AppSizes.fabRing * 2;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final barHeight =
        AppSizes.tabBar + (bottomInset > 0 ? bottomInset : AppSpacing.sm);
    final shadow = ff.cardShadow.isEmpty
        ? null
        : [
            BoxShadow(
              offset: const Offset(0, -6),
              blurRadius: 24,
              spreadRadius: -10,
              color: ff.cardShadow.first.color,
            ),
          ];

    Widget tab(int i) => Expanded(
      child: _Tab(
        item: items[i],
        active: i == currentIndex,
        onTap: () => onTap(i),
      ),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: barHeight + _raise,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ff.tabBar,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.hero),
                  ),
                  border: ff.isDark
                      ? Border(top: BorderSide(color: ff.surfaceBorder))
                      : null,
                  boxShadow: shadow,
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: barHeight - AppSizes.tabBar),
                  child: Row(
                    children: [
                      tab(0),
                      tab(1),
                      const SizedBox(width: _fabOuter + AppSpacing.md),
                      tab(2),
                      tab(3),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _Fab(onTap: onFab, semanticLabel: fabSemanticLabel),
              ),
            ),
          ],
        ),
      ),
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
    final ff = context.ff;
    final color = active
        ? ff.primary
        : (ff.isDark ? ff.inkFaint : ff.primary.withValues(alpha: 0.45));
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 5),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: context.text.buttonSmall.copyWith(
                fontSize: 11.5,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: context.motion(AppMotion.fast),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: ff.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          width: FFBottomNav._fabOuter,
          height: FFBottomNav._fabOuter,
          padding: const EdgeInsets.all(AppSizes.fabRing),
          decoration: BoxDecoration(color: ff.canvas, shape: BoxShape.circle),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ff.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: ff.heroShadow,
            ),
            child: Center(
              child: Icon(
                FontAwesomeIcons.plus,
                size: 22,
                color: ff.onGradient,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
