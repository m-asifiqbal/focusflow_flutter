/// ============================================================
/// PRAYER INSIGHT CHARTS — outcome donut and prayers by day / month
/// ============================================================
///
/// * [PrayerOutcomeCard] — donut of on time / late / made up / missed /
///   excused; tap a slice (or its legend row) to lift it and read its share.
/// * [PrayerBarsCard] — one stacked bar per day (Daily, Monthly) or month
///   (Yearly); tap a bar for its numbers.
/// Colours are the Prayer page's week-grid colours ([PrayerStyle.cell]), so
/// the two screens read the same; the card shell and legend rows are the
/// Insights ones (shared with Insights › Medicine).
/// ============================================================
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

/// The prayer outcomes, in chart order.
enum PrayerOutcome { onTime, late, madeUp, missed, excused }

extension PrayerOutcomeStyle on PrayerOutcome {
  String get label => switch (this) {
    PrayerOutcome.onTime => tr('On time'),
    PrayerOutcome.late => tr('Late'),
    PrayerOutcome.madeUp => tr('Made up'),
    PrayerOutcome.missed => tr('Missed'),
    PrayerOutcome.excused => tr('Excused'),
  };

  Color color(BuildContext context) =>
      PrayerStyle.cell(context.ff, switch (this) {
        PrayerOutcome.onTime => PrayerCell.onTime,
        PrayerOutcome.late => PrayerCell.late,
        PrayerOutcome.madeUp => PrayerCell.madeUp,
        PrayerOutcome.missed => PrayerCell.missed,
        PrayerOutcome.excused => PrayerCell.excused,
      });

  int of(PrayerCounts c) => switch (this) {
    PrayerOutcome.onTime => c.onTime,
    PrayerOutcome.late => c.late,
    PrayerOutcome.madeUp => c.madeUp,
    PrayerOutcome.missed => c.missed,
    PrayerOutcome.excused => c.excused,
  };
}

String _pct(int part, int total) =>
    total == 0 ? '0%' : '${(part * 100 / total).round()}%';

String prayerBucketName(PrayerPeriod p, DateTime d) => p == PrayerPeriod.yearly
    ? DateFormats.of('MMMM y').format(d)
    : DateFormats.of('EEE, MMM d').format(d);

String prayerBucketLabel(PrayerPeriod p, DateTime d, int i, int n) =>
    switch (p) {
      PrayerPeriod.daily => DateFormats.of('EEE').format(d),
      PrayerPeriod.monthly => i % 5 == 0 || i == n - 1 ? '${d.day}' : '',
      PrayerPeriod.yearly => DateFormats.of('MMMMM').format(d),
    };

// ─────────────────────────────── Donut ───────────────────────────────

class PrayerOutcomeCard extends StatefulWidget {
  const PrayerOutcomeCard({required this.insights, super.key});

  final PrayerInsights insights;

  @override
  State<PrayerOutcomeCard> createState() => _PrayerOutcomeCardState();
}

class _PrayerOutcomeCardState extends State<PrayerOutcomeCard> {
  PrayerOutcome? _picked;

  void _pick(PrayerOutcome? o) {
    FFHaptics.selection(context);
    setState(() => _picked = _picked == o ? null : o);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.insights.counts;
    final total = c.total;
    final picked = _picked;
    final shown = [
      for (final o in PrayerOutcome.values)
        if (o.of(c) > 0) o,
    ];
    final center = picked == null
        ? (InsightsFormat.percent(c.completion), tr('prayed'))
        : (_pct(picked.of(c), total), picked.label.toLowerCase());
    return MedicineInsightCard(
      title: tr('Prayer outcomes'),
      caption: tr('{count, plural, one {# prayer due} other {# prayers due}}', {
        'count': total,
      }),
      child: total == 0
          ? InsightsNoData(message: tr('No prayers were due in this period.'))
          : LayoutBuilder(
              builder: (context, box) {
                final size = math.min(
                  box.maxWidth * 0.42,
                  PrayerStyle.insightDonutMax,
                );
                final donut = SizedBox.square(
                  dimension: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        duration: context.motion(AppMotion.slow),
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 2,
                          centerSpaceRadius: size * 0.28,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, r) {
                              if (event is! FlTapUpEvent) return;
                              final i = r?.touchedSection?.touchedSectionIndex;
                              _pick(
                                i == null || i < 0 || i >= shown.length
                                    ? null
                                    : shown[i],
                              );
                            },
                          ),
                          sections: [
                            for (final o in shown)
                              PieChartSectionData(
                                value: o.of(c).toDouble(),
                                color: o
                                    .color(context)
                                    .withValues(
                                      alpha: picked == null || picked == o
                                          ? 1
                                          : 0.35,
                                    ),
                                radius: size * (picked == o ? 0.24 : 0.2),
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(center.$1, style: context.text.stat),
                            Text(center.$2, style: context.text.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                final legend = Column(
                  children: [
                    for (final o in PrayerOutcome.values)
                      InsightLegendRow(
                        color: o.color(context),
                        label: o.label,
                        value: '${o.of(c)} · ${_pct(o.of(c), total)}',
                        selected: picked == o,
                        onTap: () => _pick(o),
                      ),
                  ],
                );
                return Row(
                  children: [
                    donut,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
    );
  }
}

// ──────────────────────────── Stacked bars ────────────────────────────

class PrayerBarsCard extends StatelessWidget {
  const PrayerBarsCard({required this.insights, super.key});

  final PrayerInsights insights;

  @override
  Widget build(BuildContext context) {
    final s = insights;
    final ff = context.ff;
    final buckets = s.buckets;
    final n = buckets.length;
    final maxY = math.max(
      1,
      buckets.map((b) => b.counts.total).fold<int>(0, math.max),
    );
    final labelStyle = context.text.caption.copyWith(color: ff.inkFaint);
    final labelSpace =
        AppSpacing.sm +
        MediaQuery.textScalerOf(
          context,
        ).scale((labelStyle.fontSize ?? AppSpacing.md) * 1.5);
    return MedicineInsightCard(
      title: s.period == PrayerPeriod.yearly
          ? tr('Prayers by month')
          : tr('Prayers by day'),
      child: s.counts.isEmpty
          ? InsightsNoData(message: tr('No prayers were due in this period.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: InsightsDimens.chartHeight + labelSpace,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final width = ((box.maxWidth / n) * 0.6).clamp(
                        PrayerStyle.barMinWidth,
                        PrayerStyle.barMaxWidth,
                      );
                      return BarChart(
                        duration: context.motion(AppMotion.slow),
                        BarChartData(
                          minY: 0,
                          maxY: maxY * 1.15,
                          alignment: BarChartAlignment.spaceAround,
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            horizontalInterval: math.max(1, maxY / 3),
                            getDrawingHorizontalLine: (_) =>
                                FlLine(color: ff.divider, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => ff.snackbar,
                              getTooltipItem: (group, _, _, _) {
                                final b = buckets[group.x];
                                return BarTooltipItem(
                                  '${prayerBucketName(s.period, b.start)}\n'
                                  '${tr('{done} of {total} prayed', {'done': b.counts.done, 'total': b.counts.due})}',
                                  context.text.caption.copyWith(
                                    color: ff.onSnackbar,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            topTitles: const AxisTitles(),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: labelSpace,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= n) {
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
                          ),
                          barGroups: [
                            for (var i = 0; i < n; i++)
                              _group(context, i, buckets[i].counts, width),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final o in PrayerOutcome.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: InsightsDimens.legendDot,
                            height: InsightsDimens.legendDot,
                            decoration: BoxDecoration(
                              color: o.color(context),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.xxs,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(o.label, style: context.text.caption),
                        ],
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  BarChartGroupData _group(
    BuildContext context,
    int x,
    PrayerCounts c,
    double width,
  ) {
    var from = 0.0;
    final stack = <BarChartRodStackItem>[];
    for (final o in PrayerOutcome.values) {
      final v = o.of(c).toDouble();
      if (v == 0) continue;
      stack.add(BarChartRodStackItem(from, from + v, o.color(context)));
      from += v;
    }
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: from == 0 ? 0.0001 : from,
          width: width,
          rodStackItems: stack,
          color: from == 0 ? context.ff.divider : null,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.xs),
          ),
        ),
      ],
    );
  }
}
