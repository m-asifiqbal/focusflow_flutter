/// ============================================================
/// MEDICINE BREAKDOWN CARDS — trend, time of day, per medicine
/// ============================================================
///
/// * [TimeOfDayCard] — pie of the doses taken in the morning / afternoon /
///   evening (when the user's routine works, or doesn't).
/// * [AdherenceTrendCard] — the adherence % line over the period's buckets.
/// * [PerMedicineCard] — one row per medicine, weakest first: adherence
///   bar coloured by how well it goes (green ≥ 90 %, amber ≥ 70 %, red
///   below), "26 of 28 taken"; tap opens the medicine. Bars grow in.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_chart_cards.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';
import 'package:go_router/go_router.dart';

class TimeOfDayCard extends StatelessWidget {
  const TimeOfDayCard({required this.insights, super.key});

  final MedicineInsights insights;

  @override
  Widget build(BuildContext context) {
    final t = insights.timeOfDay;
    final parts = [
      (tr('Morning'), t.morning, ModuleStyle.reminders.solid),
      (tr('Afternoon'), t.afternoon, ModuleStyle.tasks.solid),
      (tr('Evening & night'), t.evening, ModuleStyle.habits.solid),
    ];
    String pct(int v) =>
        t.total == 0 ? '0%' : '${(v * 100 / t.total).round()}%';
    return MedicineInsightCard(
      title: tr('When you take them'),
      caption: tr('Doses taken by time of day'),
      child: t.total == 0
          ? InsightsNoData(message: tr('No doses taken in this period.'))
          : LayoutBuilder(
              builder: (context, box) {
                final size = math.min(
                  box.maxWidth * 0.42,
                  MedicineSizes.insightDonutMax,
                );
                return Row(
                  children: [
                    SizedBox.square(
                      dimension: size,
                      child: PieChart(
                        duration: context.motion(AppMotion.slow),
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                          sections: [
                            for (final (_, v, c) in parts)
                              if (v > 0)
                                PieChartSectionData(
                                  value: v.toDouble(),
                                  color: c,
                                  radius: size / 2,
                                  title: pct(v),
                                  titleStyle: context.text.caption.copyWith(
                                    color: InsightsColors.onGradient,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  titlePositionPercentageOffset: 0.6,
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        children: [
                          for (final (label, v, c) in parts)
                            InsightLegendRow(
                              color: c,
                              label: label,
                              value: '$v',
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class PerMedicineCard extends StatelessWidget {
  const PerMedicineCard({required this.insights, super.key});

  final MedicineInsights insights;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return MedicineInsightCard(
      title: tr('By medicine'),
      caption: tr('Adherence per medicine, weakest first'),
      child: Column(
        children: [
          for (final (i, share) in insights.perMedicine.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _MedicineRow(share: share, ff: ff),
          ],
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({required this.share, required this.ff});

  final MedicineShare share;
  final FFColors ff;

  @override
  Widget build(BuildContext context) {
    final m = share.medicine;
    final c = share.counts;
    final a = c.adherence ?? 0;
    final color = a >= 0.9 ? ff.success : (a >= 0.7 ? ff.warning : ff.danger);
    final name = m.name.trim().isEmpty ? tr('Untitled medicine') : m.name;
    return Semantics(
      button: true,
      label: tr('{name}: {percent} taken, {taken} of {total}', {
        'name': name,
        'percent': '${(a * 100).round()}%',
        'taken': c.taken,
        'total': c.total,
      }),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => context.push(AppRoutes.medicine(m.id)),
        child: Row(
          children: [
            FFIconTile.soft(
              icon: MedicineStyle.icon(m.form),
              colors: MedicineStyle.colors,
              size: AppSizes.iconTileSm,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.rowTitle,
                        ),
                      ),
                      Text(
                        '${(a * 100).round()}%',
                        style: context.text.rowTitle.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: SizedBox(
                      height: MedicineSizes.progressBar,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: color.withValues(alpha: 0.15),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: a),
                            duration: context.motion(AppMotion.slow * 3),
                            curve: AppMotion.curve,
                            builder: (_, v, _) => FractionallySizedBox(
                              widthFactor: v.clamp(0, 1),
                              heightFactor: 1,
                              alignment: AlignmentDirectional.centerStart,
                              child: ColoredBox(color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      tr('{taken} of {total} taken', {
                        'taken': c.taken,
                        'total': c.total,
                      }),
                      if (c.late > 0) tr('{n} late', {'n': c.late}),
                      if (c.missed > 0) tr('{n} missed', {'n': c.missed}),
                    ].join(' · '),
                    style: context.text.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Trend ───────────────────────────────

class AdherenceTrendCard extends StatelessWidget {
  const AdherenceTrendCard({required this.insights, super.key});

  final MedicineInsights insights;

  @override
  Widget build(BuildContext context) {
    final s = insights;
    final ff = context.ff;
    final buckets = s.buckets;
    final n = buckets.length;
    final spots = [
      for (var i = 0; i < n; i++)
        if (buckets[i].counts.adherence case final a?)
          FlSpot(i.toDouble(), (a * 100).roundToDouble()),
    ];
    final labelStyle = context.text.caption.copyWith(color: ff.inkFaint);
    final color = ff.primary;
    final dotFill = Color.alphaBlend(ff.surface, ff.canvas);
    return MedicineInsightCard(
      title: tr('Adherence trend'),
      caption: tr('Share of due doses taken'),
      child: spots.length < 2
          ? InsightsNoData(
              message: tr('Log doses on a few days to see a trend.'),
            )
          : SizedBox(
              height: InsightsDimens.chartHeight,
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
                    bottomTitles: const AxisTitles(),
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
                        for (final p in spots)
                          LineTooltipItem(
                            '${bucketName(s.period, buckets[p.x.toInt()].start)}\n${p.y.round()}%',
                            context.text.caption.copyWith(color: ff.onSnackbar),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: color,
                      barWidth: InsightsDimens.lineWidth,
                      dotData: FlDotData(
                        show: spots.length <= 31,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: InsightsDimens.dotRadius - 1,
                          color: dotFill,
                          strokeColor: color,
                          strokeWidth: InsightsDimens.dotStroke,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.25),
                            color.withValues(alpha: 0),
                          ],
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
