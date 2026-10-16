/// ============================================================
/// HABIT MONTHLY CHART — "Monthly completion" bars of the detail (16)
/// ============================================================
///
/// Six months of completion (fl_chart BarChart): past months in the habit's
/// soft tint, the current month solid. Month initials under the bars; no
/// axes or grid, as in the mockup. Animates unless reduce motion is on.
/// ============================================================
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:intl/intl.dart' show DateFormat;

class HabitMonthlyChart extends StatelessWidget {
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
              '${DateFormat('MMMM').format(m.month)} '
              '${HabitFormat.percent(m.rate)}',
        )
        .join(', ');
    final labelStyle = context.text.caption.copyWith(
      fontSize: HabitDimens.chartLabel,
      fontWeight: FontWeight.w600,
      color: ff.inkFaint,
    );

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
        const FFSectionHeader(title: 'Monthly completion'),
        const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
        FFCard(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Semantics(
            label: 'Monthly completion: $label',
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
                      maxY: 1,
                      alignment: BarChartAlignment.spaceBetween,
                      barTouchData: BarTouchData(enabled: false),
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
                                  DateFormat('MMM').format(months[i].month),
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
                            barRods: [
                              BarChartRodData(
                                toY: months[i].rate.clamp(_stub, 1.0),
                                width: width,
                                color: months[i].isCurrent
                                    ? colors.solid
                                    : soft,
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
