/// ============================================================
/// FF HEATMAP — GitHub-style consistency grid (habit detail, insights)
/// ============================================================
///
/// [weeks] columns × 7 rows (rows start at [weekStart]); the last column
/// holds [end]. Each day maps its 0..1 value to 4 levels (empty, ⅓, ⅔,
/// full) of [color]; days after [end] get a dashed outline. Cells size to
/// the available width. [FFHeatmapLegend] draws the "Less □□■■ More" key.
/// ============================================================
library;

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';

/// Fill opacity for each level (0 = empty).
const List<double> _levels = [0.08, 0.35, 0.65, 1.0];

int _levelOf(double v) {
  if (v.isNaN || v <= 0) return 0;
  if (v <= 1 / 3) return 1;
  if (v <= 2 / 3) return 2;
  return 3;
}

class FFHeatmap extends StatelessWidget {
  const FFHeatmap({
    required this.values,
    required this.end,
    this.weeks = 17,
    this.color,
    this.weekStart = DateTime.monday,
    this.onTap,
    this.gap = 4,
    this.semanticLabel,
    super.key,
  });

  /// Day → completion 0..1 (time of day ignored).
  final Map<DateTime, double> values;

  /// Last day shown (usually today); later days in its week are "future".
  final DateTime end;
  final int weeks;

  /// Defaults to primary (use the habit / module colour).
  final Color? color;

  /// [DateTime.monday] … [DateTime.sunday].
  final int weekStart;
  final ValueChanged<DateTime>? onTap;
  final double gap;
  final String? semanticLabel;

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ff.primary;
    final endDay = DateTime(end.year, end.month, end.day);
    final row = (endDay.weekday - weekStart + 7) % 7;
    final firstDay = DateTime(
      endDay.year,
      endDay.month,
      endDay.day - row - (weeks - 1) * 7,
    );
    final byDay = <int, double>{
      for (final e in values.entries) _key(e.key): e.value,
    };
    final active = byDay.values.where((v) => v > 0).length;

    return Semantics(
      label:
          semanticLabel ??
          'Activity over the last $weeks weeks: $active active days',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : weeks * 18.0;
          final cell = ((width - gap * (weeks - 1)) / weeks).clamp(4.0, 40.0);
          final height = cell * 7 + gap * 6;
          DateTime dayAt(int col, int r) => DateTime(
            firstDay.year,
            firstDay.month,
            firstDay.day + col * 7 + r,
          );
          final painter = _HeatmapPainter(
            weeks: weeks,
            cell: cell,
            gap: gap,
            color: c,
            rtl: Directionality.of(context) == TextDirection.rtl,
            level: (col, r) {
              final d = dayAt(col, r);
              if (d.isAfter(endDay)) return -1;
              return _levelOf(byDay[_key(d)] ?? 0);
            },
          );
          final grid = CustomPaint(
            size: Size(cell * weeks + gap * (weeks - 1), height),
            painter: painter,
          );
          if (onTap == null) return grid;
          return GestureDetector(
            onTapUp: (details) {
              final hit = painter.hitCell(details.localPosition);
              if (hit == null) return;
              final d = dayAt(hit.$1, hit.$2);
              if (!d.isAfter(endDay)) onTap!(d);
            },
            child: grid,
          );
        },
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.color,
    required this.rtl,
    required this.level,
  });

  final int weeks;
  final double cell;
  final double gap;
  final Color color;
  final bool rtl;

  /// -1 = future, 0..3 = level.
  final int Function(int col, int row) level;

  double _x(int col) {
    final visual = rtl ? weeks - 1 - col : col;
    return visual * (cell + gap);
  }

  (int, int)? hitCell(Offset p) {
    for (var col = 0; col < weeks; col++) {
      final x = _x(col);
      if (p.dx < x || p.dx > x + cell) continue;
      final r = (p.dy / (cell + gap)).floor();
      if (r < 0 || r > 6) return null;
      return (col, r);
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(cell * 0.24);
    final fill = Paint();
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.4);
    for (var col = 0; col < weeks; col++) {
      for (var r = 0; r < 7; r++) {
        final rect = Rect.fromLTWH(_x(col), r * (cell + gap), cell, cell);
        final l = level(col, r);
        if (l < 0) {
          _dashed(
            canvas,
            RRect.fromRectAndRadius(rect.deflate(0.5), radius),
            dash,
          );
        } else {
          fill.color = color.withValues(alpha: _levels[l]);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
        }
      }
    }
  }

  void _dashed(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 2.5), paint);
        d += 5;
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => true;
}

/// "Less □ □ ■ ■ More" key for [FFHeatmap].
class FFHeatmapLegend extends StatelessWidget {
  const FFHeatmapLegend({
    this.color,
    this.lessLabel = 'Less',
    this.moreLabel = 'More',
    this.cell = 12,
    super.key,
  });

  final Color? color;
  final String lessLabel;
  final String moreLabel;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ff.primary;
    final style = context.text.caption;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lessLabel, style: style),
          const SizedBox(width: 6),
          for (final a in _levels) ...[
            Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: c.withValues(alpha: a),
                borderRadius: BorderRadius.circular(cell * 0.24),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          const SizedBox(width: 2),
          Text(moreLabel, style: style),
        ],
      ),
    );
  }
}
