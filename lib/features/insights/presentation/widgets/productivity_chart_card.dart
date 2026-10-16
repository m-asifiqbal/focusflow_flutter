/// ============================================================
/// PRODUCTIVITY CHART CARD — "Daily productivity" line (mockup 25)
/// ============================================================
///
/// What: a smooth fl_chart line of the productivity score (tasks
/// completed + habit check-ins per day, or per week on 90-day ranges),
/// with an accent gradient fill, white dots with an accent stroke, touch
/// tooltips and weekday / date labels; "Not enough data" when the range
/// has fewer than two points or no activity.
/// Why: colours come from tokens (accent + dark mode); animation follows
/// reduce motion like HabitMonthlyChart.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:intl/intl.dart' show DateFormat;

class ProductivityChartCard extends StatelessWidget {
  const ProductivityChartCard({required this.snapshot, super.key});

  final InsightsSnapshot snapshot;

  /// At most this many x labels (they would collide beyond).
  static const int _maxLabels = 7;

  String _label(ProductivityPoint p, int count) => p.days == 1 && count <= 7
      ? DateFormat('EEE').format(p.start)
      : DateFormat('MMM d').format(p.start);

  String _spoken(ProductivityPoint p) {
    final when = p.days == 1
        ? DateFormat('EEEE, MMM d').format(p.start)
        : 'Week of ${DateFormat('MMM d').format(p.start)}';
    return '$when: ${p.tasks} tasks, ${p.habits} habit check-ins';
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final points = snapshot.series;
    final weekly = points.isNotEmpty && points.first.days > 1;
    return FFCard(
      padding: const EdgeInsetsDirectional.all(InsightsDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and legend share a line when they fit, else the legend
          // wraps below (360 pt / text scale 1.3).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Semantics(
                header: true,
                child: Text(
                  weekly ? 'Weekly productivity' : 'Daily productivity',
                  style: context.text.sectionTitle.copyWith(
                    fontSize: InsightsDimens.cardTitle,
                  ),
                ),
              ),
              Text(
                'Tasks + habits',
                style: context.text.meta.copyWith(
                  color: ff.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: InsightsDimens.cardGap),
          if (!snapshot.hasSeriesData)
            InsightsNoData(
              message: points.length < 2
                  ? 'Pick a longer range to see a trend.'
                  : 'Complete tasks or check in habits to see your trend.',
            )
          else
            Semantics(
              label: 'Productivity chart. ${points.map(_spoken).join('. ')}',
              excludeSemantics: true,
              child: _Chart(points: points, labelOf: _label),
            ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.labelOf});

  final List<ProductivityPoint> points;
  final String Function(ProductivityPoint p, int count) labelOf;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final n = points.length;
    final maxScore = points.map((p) => p.score).fold(0, math.max);
    final maxY = math.max(1, maxScore) * 1.2;
    final step = (n / ProductivityChartCard._maxLabels).ceil();
    final labelStyle = context.text.caption.copyWith(color: ff.inkFaint);
    final labelSpace =
        AppSpacing.sm +
        MediaQuery.textScalerOf(
          context,
        ).scale((labelStyle.fontSize ?? AppSpacing.md) * 1.5);
    // Opaque dot centre: the dark-mode surface is translucent.
    final dotFill = Color.alphaBlend(ff.surface, ff.canvas);
    final spots = [
      for (var i = 0; i < n; i++)
        FlSpot(i.toDouble(), points[i].score.toDouble()),
    ];

    // Side padding leaves room for the first / last weekday label.
    return Container(
      height: InsightsDimens.chartHeight + labelSpace,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
      child: LineChart(
        duration: context.motion(AppMotion.slow),
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          clipData: const FlClipData.none(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: ff.divider, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: labelSpace,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= n || value != i.toDouble()) {
                    return const SizedBox.shrink();
                  }
                  final last = i == n - 1;
                  if (i % step != 0 && !last) return const SizedBox.shrink();
                  // Skip a regular label that would crowd the last one.
                  if (!last && step > 1 && n - 1 - i < step) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: AppSpacing.sm,
                    child: Text(labelOf(points[i], n), style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => ff.snackbar,
              tooltipBorderRadius: BorderRadius.circular(AppRadii.tile),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${labelOf(points[s.spotIndex], 0)}\n',
                    context.text.caption.copyWith(color: ff.onSnackbar),
                    children: [
                      TextSpan(
                        text:
                            '${points[s.spotIndex].tasks} tasks · '
                            '${points[s.spotIndex].habits} habits',
                        style: context.text.meta.copyWith(
                          color: ff.onSnackbar,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(color: ff.primary.withValues(alpha: 0.3)),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: InsightsDimens.dotRadius + 1,
                          color: dotFill,
                          strokeWidth: InsightsDimens.dotStroke,
                          strokeColor: ff.primary,
                        ),
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: ff.primary,
              barWidth: InsightsDimens.lineWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: n <= 14,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: InsightsDimens.dotRadius,
                      color: dotFill,
                      strokeWidth: InsightsDimens.dotStroke,
                      strokeColor: ff.primary,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ff.primary.withValues(alpha: ff.isDark ? 0.3 : 0.22),
                    ff.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
