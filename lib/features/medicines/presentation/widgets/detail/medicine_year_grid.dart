/// ============================================================
/// MEDICINE YEAR GRID — twelve mini months of doses (detail)
/// ============================================================
///
/// Three months across, one square per day painted by how the day went
/// ([DayOutcome]): full colour = every dose taken, amber = some taken,
/// red = missed, slate = skipped, outline = nothing logged yet, faint =
/// nothing scheduled. Tap a month to open it in the Month view.
/// Why a painter: 365 squares as widgets would be ~400 render objects;
/// twelve CustomPaints are twelve. Outcomes are folded once per build.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_calendar.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/detail/medicine_month_grid.dart';

/// The colour a day's [outcome] is painted with.
Color outcomeColor(BuildContext context, DayOutcome outcome) {
  final ff = context.ff;
  return switch (outcome) {
    DayOutcome.taken => ff.success,
    DayOutcome.partial => ff.warning,
    DayOutcome.missed => ff.danger,
    DayOutcome.skipped => ActionTints.lock.solid,
    DayOutcome.pending => ff.inkFaint,
    DayOutcome.none => ff.divider,
  };
}

class MedicineYearGrid extends StatelessWidget {
  const MedicineYearGrid({
    required this.days,
    required this.weekStart,
    required this.onMonth,
    super.key,
  });

  /// Jan 1 … Dec 31 of one year, oldest first (never empty).
  final List<MedicineWeekDay> days;
  final int weekStart;

  /// A tapped month (its 1st).
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final year = days.first.day.year;
    final byMonth = List.generate(12, (_) => <MedicineWeekDay>[]);
    for (final d in days) {
      byMonth[d.day.month - 1].add(d);
    }
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MiniMonth(
                    first: DateTime(year, row * 3 + col + 1),
                    days: byMonth[row * 3 + col],
                    weekStart: weekStart,
                    onTap: onMonth,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.first,
    required this.days,
    required this.weekStart,
    required this.onTap,
  });

  final DateTime first;
  final List<MedicineWeekDay> days;
  final int weekStart;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final lead = leadingBlanks(first, weekStart);
    // 6 week rows always, so every month is the same height.
    final cells = List<DayOutcome?>.filled(42, null);
    for (var i = 0; i < days.length && lead + i < 42; i++) {
      cells[lead + i] = DayOutcome.of(days[i].states);
    }
    return Semantics(
      button: true,
      label: DateFormats.of('MMMM y').format(first),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(first),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormats.of('MMM').format(first),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: ff.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            LayoutBuilder(
              builder: (context, c) {
                final cell = (c.maxWidth - MedicineSizes.yearGap * 6) / 7;
                return CustomPaint(
                  size: Size(c.maxWidth, cell * 6 + MedicineSizes.yearGap * 5),
                  painter: _MonthPainter(
                    cells: cells,
                    colors: [
                      for (final o in DayOutcome.values)
                        outcomeColor(context, o),
                    ],
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPainter extends CustomPainter {
  const _MonthPainter({
    required this.cells,
    required this.colors,
    required this.rtl,
  });

  /// 42 cells (7 per week row); null = outside the month.
  final List<DayOutcome?> cells;

  /// Paint colour per [DayOutcome] index.
  final List<Color> colors;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = MedicineSizes.yearGap;
    final cell = (size.width - gap * 6) / 7;
    final radius = Radius.circular(cell * 0.28);
    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < cells.length; i++) {
      final o = cells[i];
      if (o == null) continue;
      final col = rtl ? 6 - i % 7 : i % 7;
      final rect = Rect.fromLTWH(
        col * (cell + gap),
        (i ~/ 7) * (cell + gap),
        cell,
        cell,
      );
      final color = colors[o.index];
      switch (o) {
        case DayOutcome.pending:
          ring.color = color.withValues(alpha: 0.7);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(0.5), radius),
            ring,
          );
        case DayOutcome.none:
          fill.color = color.withValues(alpha: 0.6);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
        case DayOutcome.taken ||
            DayOutcome.partial ||
            DayOutcome.missed ||
            DayOutcome.skipped:
          fill.color = color;
          canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
      }
    }
  }

  @override
  bool shouldRepaint(_MonthPainter old) =>
      old.rtl != rtl || !_same(old.cells, cells) || !_same(old.colors, colors);

  static bool _same<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
