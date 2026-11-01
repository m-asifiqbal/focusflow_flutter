/// ============================================================
/// PRAYER INSIGHT SHAPES — trend line and the Venn of days
/// ============================================================
///
/// * [PrayerTrendCard] — two lines over the period's buckets: the share of
///   due prayers prayed (filled, in the Prayer colour) and the share on
///   time (dashed, green). Tap a point for both numbers.
/// * [PrayerVennCard] — three circles (on time · late or made up · missed)
///   with the number of days in each region (the shared [InsightsVenn]),
///   and the plain-language reading below.
/// ============================================================
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_venn.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/insights/prayer_insight_charts.dart';

// ─────────────────────────────── Trend ───────────────────────────────

class PrayerTrendCard extends StatelessWidget {
  const PrayerTrendCard({required this.insights, super.key});

  final PrayerInsights insights;

  @override
  Widget build(BuildContext context) {
    final s = insights;
    final ff = context.ff;
    final buckets = s.buckets;
    final n = buckets.length;
    final prayed = [
      for (var i = 0; i < n; i++)
        if (buckets[i].counts.completion case final r?)
          FlSpot(i.toDouble(), (r * 100).roundToDouble()),
    ];
    final onTime = [
      for (var i = 0; i < n; i++)
        if (buckets[i].counts.onTimeRate case final r?)
          FlSpot(i.toDouble(), (r * 100).roundToDouble()),
    ];
    final labelStyle = context.text.caption.copyWith(color: ff.inkFaint);
    final labelSpace =
        AppSpacing.sm +
        MediaQuery.textScalerOf(
          context,
        ).scale((labelStyle.fontSize ?? AppSpacing.md) * 1.5);
    final prayedColor = PrayerStyle.module.inkFor(ff.brightness);
    final onTimeColor = PrayerOutcome.onTime.color(context);
    final dotFill = Color.alphaBlend(ff.surface, ff.canvas);

    LineChartBarData line(
      List<FlSpot> spots,
      Color color, {
      bool fill = false,
    }) => LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: InsightsDimens.lineWidth,
      dashArray: fill ? null : const [6, 4],
      dotData: FlDotData(
        show: spots.length <= 12,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: InsightsDimens.dotRadius - 1,
          color: dotFill,
          strokeColor: color,
          strokeWidth: InsightsDimens.dotStroke,
        ),
      ),
      belowBarData: BarAreaData(
        show: fill,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ),
      ),
    );

    return MedicineInsightCard(
      title: tr('Prayer trend'),
      caption: tr('Share of due prayers prayed, and prayed on time'),
      child: prayed.length < 2
          ? InsightsNoData(
              message: tr('Mark prayers on a few days to see a trend.'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: InsightsDimens.chartHeight + labelSpace,
                  child: LineChart(
                    duration: context.motion(AppMotion.slow),
                    LineChartData(
                      minX: 0,
                      maxX: (n - 1).toDouble(),
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: ff.divider, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: labelSpace,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (v != i || i < 0 || i >= n) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                space: AppSpacing.sm,
                                child: Text(
                                  prayerBucketLabel(
                                    s.period,
                                    buckets[i].start,
                                    i,
                                    n,
                                  ),
                                  style: labelStyle,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 50,
                            reservedSize: AppSpacing.xxxl + AppSpacing.lg,
                            // Only 0 / 50 / 100: fl_chart also labels the
                            // axis ends, which would overlap.
                            getTitlesWidget: (v, meta) => v % 50 != 0
                                ? const SizedBox.shrink()
                                : SideTitleWidget(
                                    meta: meta,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${v.round()}%',
                                        maxLines: 1,
                                        style: labelStyle,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => ff.snackbar,
                          getTooltipItems: (spots) => [
                            for (final (k, p) in spots.indexed)
                              LineTooltipItem(
                                [
                                  if (k == 0)
                                    prayerBucketName(
                                      s.period,
                                      buckets[p.x.toInt()].start,
                                    ),
                                  p.barIndex == 0
                                      ? tr('Prayed {percent}', {
                                          'percent': '${p.y.round()}%',
                                        })
                                      : tr('On time {percent}', {
                                          'percent': '${p.y.round()}%',
                                        }),
                                ].join('\n'),
                                context.text.caption.copyWith(
                                  color: ff.onSnackbar,
                                ),
                              ),
                          ],
                        ),
                      ),
                      lineBarsData: [
                        line(prayed, prayedColor, fill: true),
                        line(onTime, onTimeColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Key(color: prayedColor, label: tr('Prayed')),
                    _Key(
                      color: onTimeColor,
                      label: tr('On time'),
                      dashed: true,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// A line-chart legend entry: a short solid or dashed stroke and a label.
class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < (dashed ? 2 : 1); i++)
        Container(
          width: dashed ? AppSpacing.sm : AppSpacing.lg + AppSpacing.xs,
          height: InsightsDimens.lineWidth,
          margin: const EdgeInsetsDirectional.only(end: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      const SizedBox(width: AppSpacing.xxs),
      Text(label, style: context.text.caption),
    ],
  );
}

// ─────────────────────────────── Venn ────────────────────────────────

class PrayerVennCard extends StatelessWidget {
  const PrayerVennCard({required this.insights, super.key});

  final PrayerInsights insights;

  @override
  Widget build(BuildContext context) {
    final v = insights.venn;
    final onTime = PrayerOutcome.onTime.color(context);
    final late = PrayerOutcome.late.color(context);
    final missed = PrayerOutcome.missed.color(context);
    return MedicineInsightCard(
      title: tr('Your days at a glance'),
      caption: tr(
        '{count, plural, one {# day with prayers} other {# days with prayers}}',
        {'count': v.days},
      ),
      child: v.days == 0
          ? InsightsNoData(message: tr('No prayers were due in this period.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InsightsVenn(
                  regions: (
                    a: v.onTimeOnly,
                    b: v.lateOnly,
                    c: v.missedOnly,
                    ab: v.onTimeLate,
                    ac: v.onTimeMissed,
                    bc: v.lateMissed,
                    abc: v.all,
                  ),
                  colors: (onTime, late, missed),
                  labels: (
                    PrayerOutcome.onTime.label,
                    tr('Late / made up'),
                    PrayerOutcome.missed.label,
                  ),
                  semanticLabel: tr(
                    'Venn diagram of days. {a} days all on time, {b} days with a late or made-up prayer only, {c} days with a missed prayer only, {d} days with several kinds.',
                    {
                      'a': v.onTimeOnly,
                      'b': v.lateOnly,
                      'c': v.missedOnly,
                      'd': v.onTimeLate + v.onTimeMissed + v.lateMissed + v.all,
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    InsightsFactChip(
                      color: onTime,
                      text: tr(
                        '{count, plural, one {# day all on time} other {# days all on time}}',
                        {'count': v.onTimeOnly},
                      ),
                    ),
                    if (v.lateNotMissed > 0)
                      InsightsFactChip(
                        color: late,
                        text: tr(
                          '{count, plural, one {# day all prayed, some late} other {# days all prayed, some late}}',
                          {'count': v.lateNotMissed},
                        ),
                      ),
                    if (v.withMissed > 0)
                      InsightsFactChip(
                        color: missed,
                        text: tr(
                          '{count, plural, one {# day with a prayer missed} other {# days with a prayer missed}}',
                          {'count': v.withMissed},
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
