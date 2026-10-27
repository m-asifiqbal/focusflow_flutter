/// ============================================================
/// FF GANTT — horizontal timeline bars over a shared axis
/// ============================================================
///
/// What: one row per [FFGanttBar] (label + trailing text above a bar on a
/// faint track), a tick axis on top and a vertical grid behind the rows;
/// the "today" unit gets a highlighted column. The domain is [units] equal
/// cells (days, or months for a yearly view); a bar covers the cells
/// `startUnit … endUnit` (both inclusive). A bar that begins before / ends
/// after the domain is flat on that side ([FFGanttBar.continuesBefore] /
/// [FFGanttBar.continuesAfter]) so it reads as "keeps going".
/// Why: bars are positioned with integer-flex Rows (no per-frame layout
/// maths, RTL for free) and the grid is one CustomPaint, so a chart of a
/// dozen rows costs a handful of render objects and never animates.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';

/// A label on the axis, centred over the cell [unit].
@immutable
class FFGanttTick {
  const FFGanttTick(this.unit, this.label);

  final int unit;
  final String label;
}

/// One row of an [FFGantt].
@immutable
class FFGanttBar {
  const FFGanttBar({
    required this.label,
    required this.startUnit,
    required this.endUnit,
    required this.color,
    required this.semanticLabel,
    this.trailing,
    this.trailingColor,
    this.continuesBefore = false,
    this.continuesAfter = false,
    this.onTap,
  });

  final String label;

  /// Shown at the end of the label line (a percentage, a date…).
  final String? trailing;
  final Color? trailingColor;

  /// First / last cell covered (inclusive); clamped into the domain.
  final int startUnit;
  final int endUnit;
  final Color color;
  final bool continuesBefore;
  final bool continuesAfter;
  final String semanticLabel;
  final VoidCallback? onTap;
}

class FFGantt extends StatelessWidget {
  const FFGantt({
    required this.bars,
    required this.units,
    required this.ticks,
    this.todayUnit,
    super.key,
  });

  final List<FFGanttBar> bars;

  /// Number of cells of the axis (≥ 1).
  final int units;
  final List<FFGanttTick> ticks;

  /// Cell to highlight as "now" (null when it is outside the domain).
  final int? todayUnit;

  /// Height of one bar.
  static const double barHeight = 12;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final n = units < 1 ? 1 : units;
    final tickStyle = context.text.caption.copyWith(color: ff.inkFaint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Axis(ticks: ticks, units: n, style: tickStyle),
        const SizedBox(height: AppSpacing.xs),
        // The grid is painted once behind all rows.
        CustomPaint(
          painter: _GridPainter(
            units: n,
            ticks: [for (final t in ticks) t.unit],
            today: todayUnit,
            lineColor: ff.divider,
            todayColor: ff.primary.withValues(alpha: ff.isDark ? 0.22 : 0.12),
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final b in bars) _Row(bar: b, units: n)],
          ),
        ),
      ],
    );
  }
}

/// Tick labels, each centred over its cell.
class _Axis extends StatelessWidget {
  const _Axis({required this.ticks, required this.units, required this.style});

  final List<FFGanttTick> ticks;
  final int units;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Room for one line at the current text scale.
    final h = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? AppSpacing.md) * 1.4);
    return ExcludeSemantics(
      child: SizedBox(
        height: h,
        child: LayoutBuilder(
          builder: (context, c) {
            final cell = c.maxWidth / units;
            return Stack(
              children: [
                for (final t in ticks)
                  PositionedDirectional(
                    start: t.unit * cell,
                    width: cell,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        t.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: style,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.bar, required this.units});

  final FFGanttBar bar;
  final int units;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final start = bar.startUnit.clamp(0, units - 1);
    final end = bar.endUnit.clamp(start, units - 1);
    final lead = start;
    final span = end - start + 1;
    final tail = units - end - 1;
    const r = Radius.circular(FFGantt.barHeight / 2);
    final shape = BorderRadiusDirectional.horizontal(
      start: bar.continuesBefore ? Radius.zero : r,
      end: bar.continuesAfter ? Radius.zero : r,
    );
    final trailing = bar.trailing;
    return Semantics(
      button: bar.onTap != null,
      label: bar.semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: bar.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xs + AppSpacing.xxs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bar.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall.copyWith(color: ff.ink),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        trailing,
                        maxLines: 1,
                        style: context.text.caption.copyWith(
                          color: bar.trailingColor ?? ff.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                SizedBox(
                  height: FFGantt.barHeight,
                  child: Row(
                    // Stretch: a childless DecoratedBox would be 0 high.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (lead > 0) Spacer(flex: lead),
                      Expanded(
                        flex: span,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: bar.color,
                            borderRadius: shape,
                          ),
                        ),
                      ),
                      if (tail > 0) Spacer(flex: tail),
                    ],
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

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.units,
    required this.ticks,
    required this.today,
    required this.lineColor,
    required this.todayColor,
    required this.rtl,
  });

  final int units;
  final List<int> ticks;
  final int? today;
  final Color lineColor;
  final Color todayColor;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / units;
    double x(num unit) => rtl ? size.width - unit * cell : unit * cell;
    final t = today;
    if (t != null && t >= 0 && t < units) {
      final a = x(t);
      final b = x(t + 1);
      canvas.drawRect(
        Rect.fromLTRB(a < b ? a : b, 0, a < b ? b : a, size.height),
        Paint()..color = todayColor,
      );
    }
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (final u in ticks) {
      final dx = x(u + 0.5);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) =>
      o.units != units ||
      o.today != today ||
      o.lineColor != lineColor ||
      o.todayColor != todayColor ||
      o.rtl != rtl ||
      !_sameTicks(o.ticks, ticks);

  static bool _sameTicks(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
