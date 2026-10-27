/// ============================================================
/// HABIT HEATMAP — the consistency grid of the habit detail (16)
/// ============================================================
///
/// What: the GitHub-style grid of FFHeatmap ([weeks] columns × 7 rows,
/// rows from [weekStart], the last column holds [end], 4 opacity levels of
/// [color], days after [end] dashed) plus a fifth look: **rest days** — days
/// the habit wasn't due (off days of a specific-days habit, every-N-days
/// gaps, an N× per week habit after its weekly quota) — are drawn as a
/// thin outline instead of the "empty" level, so they never read as
/// misses. A rest day with a (bonus) log shows its level as usual.
/// [calendar] turns the grid on its side for the Week and Month ranges: one
/// row per week, seven columns (weekday initials on top, the date inside
/// each cell), so a single week or month gets big, readable, tappable cells;
/// [from] hides the days before the 1st of the month.
/// Why not FFHeatmap: the core widget (shared with Insights) only knows
/// values; rest days are a habit concept. [HabitRestDayKey] is the legend
/// entry for the outline.
/// ============================================================
library;

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

/// Fill opacity for each level (0 = empty) — the same as FFHeatmap's.
const List<double> _levels = [0.08, 0.35, 0.65, 1.0];

/// Painter levels beyond the 0…3 fill levels.
const int _future = -1;
const int _rest = -2;
const int _hidden = -3;

int _levelOf(double v) {
  if (v.isNaN || v <= 0) return 0;
  if (v <= 1 / 3) return 1;
  if (v <= 2 / 3) return 2;
  return 3;
}

class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    required this.values,
    required this.end,
    required this.color,
    this.restDays = const {},
    this.weeks = 17,
    this.weekStart = DateTime.monday,
    this.onTap,
    this.gap = AppSpacing.xs,
    this.semanticLabel,
    this.calendar = false,
    this.from,
    super.key,
  });

  /// Day → completion 0..1 (time of day ignored).
  final Map<DateTime, double> values;

  /// Days the habit wasn't due (time of day ignored).
  final Set<DateTime> restDays;

  /// Last day shown (today); later days in its week are "future".
  final DateTime end;
  final Color color;
  final int weeks;

  /// [DateTime.monday] … [DateTime.sunday].
  final int weekStart;
  final ValueChanged<DateTime>? onTap;
  final double gap;
  final String? semanticLabel;

  /// Weeks as rows × 7 weekday columns (Week / Month ranges) instead of
  /// weeks as columns × 7 weekday rows.
  final bool calendar;

  /// First day drawn (earlier days of the first week are left blank).
  final DateTime? from;

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// The painter level of [day]: -1 future, -2 rest (no progress), 0…3.
  static int levelFor({
    required DateTime day,
    required DateTime end,
    required Map<int, double> byDay,
    required Set<int> rest,
    DateTime? from,
  }) {
    if (from != null && day.isBefore(from)) return _hidden;
    if (day.isAfter(end)) return _future;
    final level = _levelOf(byDay[_key(day)] ?? 0);
    if (level == 0 && rest.contains(_key(day))) return _rest;
    return level;
  }

  /// Painter level of [day] for this widget's data (tests).
  int levelOf(DateTime day) => levelFor(
    day: DateTime(day.year, day.month, day.day),
    end: DateTime(end.year, end.month, end.day),
    byDay: {for (final e in values.entries) _key(e.key): e.value},
    rest: {for (final d in restDays) _key(d)},
    from: from == null ? null : DateTime(from!.year, from!.month, from!.day),
  );

  /// Whether [day] is drawn as a rest day.
  bool isRestCell(DateTime day) => levelOf(day) == _rest;

  @override
  Widget build(BuildContext context) {
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
    final rest = <int>{for (final d in restDays) _key(d)};
    final active = byDay.values.where((v) => v > 0).length;
    final ff = context.ff;
    final fromDay = from == null
        ? null
        : DateTime(from!.year, from!.month, from!.day);

    return Semantics(
      label:
          semanticLabel ??
          tr('Activity over the last {weeks} weeks: {active} active days', {
            'weeks': weeks,
            'active': active,
          }),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : weeks * HabitDimens.heatmapFallbackCell;
          // Calendar: 7 columns, so its cells are wide; the heatmap: [weeks].
          final cols = calendar ? 7 : weeks;
          final cell = ((width - gap * (cols - 1)) / cols).clamp(
            4.0,
            calendar ? HabitDimens.calendarCellMax : 40.0,
          );
          DateTime dayAt(int col, int r) => DateTime(
            firstDay.year,
            firstDay.month,
            firstDay.day + col * 7 + r,
          );
          final painter = _HabitHeatmapPainter(
            weeks: weeks,
            cell: cell,
            gap: gap,
            color: color,
            outline: ff.chipBorder,
            rtl: Directionality.of(context) == TextDirection.rtl,
            calendar: calendar,
            ink: ff.ink,
            faint: ff.inkFaint,
            labels: calendar ? DateUtilsX.weekdayInitials(weekStart) : const [],
            labelStyle: context.text.sectionLabel,
            dateOf: (col, r) => dayAt(col, r).day,
            level: (col, r) => levelFor(
              day: dayAt(col, r),
              end: endDay,
              byDay: byDay,
              rest: rest,
              from: fromDay,
            ),
          );
          final grid = CustomPaint(size: painter.size, painter: painter);
          if (onTap == null) return grid;
          return GestureDetector(
            onTapUp: (details) {
              final hit = painter.hitCell(details.localPosition);
              if (hit == null) return;
              final d = dayAt(hit.$1, hit.$2);
              final shown =
                  !d.isAfter(endDay) &&
                  (fromDay == null || !d.isBefore(fromDay));
              if (shown) onTap!(d);
            },
            child: grid,
          );
        },
      ),
    );
  }
}

class _HabitHeatmapPainter extends CustomPainter {
  _HabitHeatmapPainter({
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.color,
    required this.outline,
    required this.rtl,
    required this.level,
    this.calendar = false,
    this.ink = const Color(0xFF000000),
    this.faint = const Color(0xFF888888),
    this.labels = const [],
    this.labelStyle = const TextStyle(),
    this.dateOf = _noDate,
  });

  static int _noDate(int col, int row) => 0;

  final int weeks;
  final double cell;
  final double gap;
  final Color color;
  final Color outline;
  final bool rtl;

  /// Week rows × 7 weekday columns, with initials on top and dates inside.
  final bool calendar;
  final Color ink;
  final Color faint;
  final List<String> labels;
  final TextStyle labelStyle;

  /// Day of the month of a cell (the calendar prints it).
  final int Function(int col, int row) dateOf;

  /// -3 = hidden, -2 = rest, -1 = future, 0..3 = level.
  final int Function(int col, int row) level;

  /// Height of the weekday header (calendar only).
  double get _header => calendar ? HabitDimens.calendarHeader : 0;

  Size get size => calendar
      ? Size(cell * 7 + gap * 6, _header + cell * weeks + gap * (weeks - 1))
      : Size(cell * weeks + gap * (weeks - 1), cell * 7 + gap * 6);

  /// Left edge of the visual column [v] (0 = leading side).
  double _left(int v) => v * (cell + gap);

  /// Where cell ([col] = week, [r] = weekday row) sits.
  Rect _rect(int col, int r) {
    if (calendar) {
      final v = rtl ? 6 - r : r;
      return Rect.fromLTWH(_left(v), _header + col * (cell + gap), cell, cell);
    }
    final v = rtl ? weeks - 1 - col : col;
    return Rect.fromLTWH(_left(v), r * (cell + gap), cell, cell);
  }

  (int, int)? hitCell(Offset p) {
    if (calendar) {
      final col = ((p.dy - _header) / (cell + gap)).floor();
      final v = (p.dx / (cell + gap)).floor();
      if (col < 0 || col >= weeks || v < 0 || v > 6) return null;
      if (p.dx > _left(v) + cell ||
          p.dy - _header > col * (cell + gap) + cell) {
        return null;
      }
      return (col, rtl ? 6 - v : v);
    }
    for (var col = 0; col < weeks; col++) {
      final x = _rect(col, 0).left;
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
    final restStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;
    if (calendar) {
      for (var r = 0; r < labels.length && r < 7; r++) {
        _text(
          canvas,
          labels[r],
          faint,
          labelStyle,
          Offset(_rect(0, r).center.dx, _header / 2),
        );
      }
    }
    for (var col = 0; col < weeks; col++) {
      for (var r = 0; r < 7; r++) {
        final l = level(col, r);
        if (l == _hidden) continue;
        final rect = _rect(col, r);
        Color? textColor;
        if (l == _future) {
          _dashed(
            canvas,
            RRect.fromRectAndRadius(rect.deflate(0.5), radius),
            dash,
          );
          textColor = faint;
        } else if (l == _rest) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(0.5), radius),
            restStroke,
          );
          textColor = faint;
        } else {
          fill.color = color.withValues(alpha: _levels[l]);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
          textColor = l >= 2 ? AppPalette.white : ink;
        }
        if (calendar) {
          _text(
            canvas,
            '${dateOf(col, r)}',
            textColor,
            labelStyle.copyWith(fontSize: (cell * 0.34).clamp(10.0, 15.0)),
            rect.center,
          );
        }
      }
    }
  }

  void _text(Canvas canvas, String t, Color c, TextStyle style, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: style.copyWith(color: c),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
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
  bool shouldRepaint(_HabitHeatmapPainter old) => true;
}

/// "□ Rest day" legend entry for [HabitHeatmap]'s outlined cells.
class HabitRestDayKey extends StatelessWidget {
  const HabitRestDayKey({this.cell = HabitDimens.heatmapLegendCell, super.key});

  final double cell;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cell,
            height: cell,
            decoration: BoxDecoration(
              border: Border.all(color: context.ff.chipBorder),
              borderRadius: BorderRadius.circular(cell * 0.24),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
          Text(tr('Rest day'), style: context.text.caption),
        ],
      ),
    );
  }
}
