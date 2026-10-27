/// ============================================================
/// HABIT MONTHLY CHART — "Monthly completion" bars of the detail (16)
/// ============================================================
///
/// Six months of completion (fl_chart BarChart): the selected month (the
/// current one at first) solid, the others in the habit's soft tint. Every bar
/// carries its percentage on top, the selected one bold in the habit colour.
/// Tap a bar to select it. Month initials under the bars; no
/// axes or grid, as in the mockup. Animates unless reduce motion is on.
/// ============================================================
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/core/theme/app_colors.dart';

class HabitMonthlyChart extends StatefulWidget {
  const HabitMonthlyChart({
    required this.months,
    required this.colors,
    super.key,
  });

  /// Oldest first; the last one is the current month.
  final List<MonthlyCompletion> months;
  final ModuleColors colors;

  /// Height of a 0 % bar, so empty months still show a stub.
  static const double _stub = 0.03;

  /// Room above a 100 % bar for its label.
  static const double _headroom = 1.25;

  @override
  State<HabitMonthlyChart> createState() => _HabitMonthlyChartState();
}

class _HabitMonthlyChartState extends State<HabitMonthlyChart> {
  /// The tapped bar; null = the current month.
  int? _picked;

  List<MonthlyCompletion> get months => widget.months;
  ModuleColors get colors => widget.colors;

  int get _selected {
    final i = _picked;
    if (i != null && i >= 0 && i < months.length) return i;
    final cur = months.indexWhere((m) => m.isCurrent);
    return cur >= 0 ? cur : months.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final soft = Color.alphaBlend(
      colors.solid.withValues(alpha: ff.isDark ? 0.35 : 0.3),
      ff.surface,
    );
    final label = months
        .map(
          (m) =>
              '${DateFormats.of('MMMM').format(m.month)} '
              '${HabitFormat.percent(m.rate)}',
        )
        .join(', ');
    final labelStyle = context.text.caption.copyWith(
      fontSize: HabitDimens.chartLabel,
      fontWeight: FontWeight.w600,
      color: ff.inkFaint,
    );
    final selected = _selected;

    // Month labels grow with the text scale; reserve room for one line.
    final labelSpace =
        AppSpacing.sm +
        MediaQuery.textScalerOf(
          context,
        ).scale((labelStyle.fontSize ?? AppSpacing.md) * 1.45);
    final chartHeight = HabitDimens.chartHeight - AppSpacing.xxl + labelSpace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Monthly completion'),
          trailing: Text(tr('Tap a bar'), style: context.text.caption),
        ),
        const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
        FFCard(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Semantics(
            label: tr('Monthly completion: {label}', {'label': label}),
            excludeSemantics: true,
            child: SizedBox(
              height: chartHeight,
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = months.length;
                  final width = n == 0
                      ? 0.0
                      : ((c.maxWidth - AppSpacing.md * (n - 1)) / n).clamp(
                          AppSpacing.sm,
                          HabitDimens.chartBarMaxWidth,
                        );
                  return BarChart(
                    duration: context.motion(AppMotion.slow),
                    BarChartData(
                      minY: 0,
                      maxY: HabitMonthlyChart._headroom,
                      alignment: BarChartAlignment.spaceBetween,
                      barTouchData: BarTouchData(
                        // Labels are shown by us (every bar, always); a touch
                        // only picks the bar.
                        handleBuiltInTouches: false,
                        touchCallback: (event, response) {
                          final i = response?.spot?.touchedBarGroupIndex;
                          if (event is FlTapUpEvent && i != null) {
                            setState(() => _picked = i);
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: AppSpacing.xs,
                          fitInsideHorizontally: true,
                          getTooltipItem: (group, gi, rod, ri) {
                            final m = months[group.x];
                            final on = group.x == selected;
                            final pct = HabitFormat.percent(m.rate);
                            return BarTooltipItem(
                              pct,
                              labelStyle.copyWith(
                                fontWeight: on
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: on ? colors.solid : ff.inkMuted,
                              ),
                            );
                          },
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: labelSpace,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= n) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                space: AppSpacing.sm,
                                child: Text(
                                  DateFormats.of('MMM').format(months[i].month),
                                  style: labelStyle,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < n; i++)
                          BarChartGroupData(
                            x: i,
                            showingTooltipIndicators: const [0],
                            barRods: [
                              BarChartRodData(
                                toY: months[i].rate.clamp(
                                  HabitMonthlyChart._stub,
                                  1.0,
                                ),
                                width: width,
                                color: i == selected ? colors.solid : soft,
                                // Rounded tops, square bottoms (mockup 16).
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(
                                    HabitDimens.chartBarRadius,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
