/// ============================================================
/// FF CALENDAR DAY TILE — the "glass calendar" day for FFWeekStrip (pill)
/// ============================================================
///
/// Each day is a tiny desk calendar: two binder rings on top, a header band
/// and the weekday + date below.
/// * Selected — the vivid "glass" calendar: an accent-gradient body with a
///   frosted panel (milky sheen + bright hairline edge) over its lower part,
///   white weekday / number on the glass, and a soft accent glow.
/// * Other days — a light paper calendar: white body, soft accent header
///   band, faint rings; today gets an accent outline.
///
/// No BackdropFilter: the frost is painted (gradient + edge), so a scrolling
/// row of tiles stays cheap to render.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:intl/intl.dart';

class FFCalendarDayTile extends StatelessWidget {
  const FFCalendarDayTile({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.accent,
    this.dotColor,
    super.key,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;

  /// Selected body / header tint.
  final Color accent;

  /// Item dot under the date (null = no dot).
  final Color? dotColor;

  static const double width = 58;
  static const double height = 84;

  /// How far the binder rings poke above the tile.
  static const double ringOverhang = 5;
  static const double _radius = 18;
  static const double _band = 22;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height + ringOverhang,
      child: AnimatedSwitcher(
        duration: context.motion(AppMotion.normal),
        switchInCurve: AppMotion.curve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(selected),
          child: selected ? _glass(context) : _paper(context),
        ),
      ),
    );
  }

  Widget _labels(
    BuildContext context, {
    required Color weekday,
    required Color number,
    required Color? dot,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.E().format(day).toUpperCase(),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: context.text.meta.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: weekday,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${day.day}',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: context.text.stat.copyWith(fontSize: 22, color: number),
        ),
        const SizedBox(height: 4),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      ],
    );
  }

  /// The vivid selected calendar.
  Widget _glass(BuildContext context) {
    final ff = context.ff;
    final deep = Color.lerp(accent, Colors.black, 0.18)!;
    final light = Color.lerp(accent, Colors.white, 0.18)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: ringOverhang,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [light, accent, deep],
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 12),
                  blurRadius: 22,
                  spreadRadius: -8,
                  color: accent.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
        // Frosted panel over the lower part of the body.
        Positioned(
          left: 0,
          right: 0,
          top: ringOverhang + _band - 4,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius - 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.42),
                  Colors.white.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Center(
              child: _labels(
                context,
                weekday: ff.onGradient.withValues(alpha: 0.92),
                number: ff.onGradient,
                dot: dotColor == null ? null : ff.onGradient,
              ),
            ),
          ),
        ),
        ..._rings(Colors.white, shadow: deep.withValues(alpha: 0.35)),
      ],
    );
  }

  /// A plain "paper" calendar for the other days.
  Widget _paper(BuildContext context) {
    final ff = context.ff;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: ringOverhang,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ff.surface,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: isToday
                    ? accent.withValues(alpha: 0.55)
                    : ff.surfaceBorder,
                width: isToday ? 1.5 : 1,
              ),
              boxShadow: ff.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  height: _band - 6,
                  color: accent.withValues(alpha: ff.isDark ? 0.22 : 0.12),
                ),
                Expanded(
                  child: Center(
                    child: _labels(
                      context,
                      weekday: accent.withValues(alpha: 0.75),
                      number: ff.ink,
                      dot: dotColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ..._rings(accent.withValues(alpha: ff.isDark ? 0.6 : 0.4)),
      ],
    );
  }

  List<Widget> _rings(Color color, {Color? shadow}) => [
    for (final x in const [0.3, 0.7])
      Positioned(
        top: 0,
        left: width * x - 2.5,
        child: Container(
          width: 5,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: shadow == null
                ? null
                : [
                    BoxShadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: shadow,
                    ),
                  ],
          ),
        ),
      ),
  ];
}
