/// ============================================================
/// INSIGHTS CONTENT — the sections below the range chips (mockup 25)
/// ============================================================
///
/// What: [InsightsContent] lays out the KPI grid, productivity chart,
/// time split, habit streaks and weekly tip for one snapshot;
/// [InsightsSkeleton] mirrors that layout while the first snapshot loads.
/// Why: the screen only switches between loading / error / data; each
/// card handles its own "Not enough data" state.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/focus_timer_sheet.dart';
import 'package:focusflow/features/insights/presentation/widgets/habit_streaks_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_kpi_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/productivity_chart_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/time_split_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/weekly_tip_card.dart';

class InsightsContent extends StatelessWidget {
  const InsightsContent({required this.snapshot, super.key});

  final InsightsSnapshot snapshot;

  /// Percentage-point change, or null when either window has no data.
  static KpiDelta? _rateDelta(Kpi<RatioMetric> k) {
    final a = k.current.rate;
    final b = k.previous.rate;
    if (a == null || b == null) return null;
    return KpiDelta((a * 100).round() - (b * 100).round(), '%');
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final focus = s.focusMinutes;
    final noFocus = focus.current == 0 && focus.previous == 0;
    void startFocus() => showFocusTimer(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsightsKpiGrid(
          cards: [
            InsightsKpiCard(
              label: 'Task completion',
              value: InsightsFormat.percent(s.taskCompletion.current.rate),
              delta: _rateDelta(s.taskCompletion),
            ),
            InsightsKpiCard(
              label: 'Focus hours',
              value: InsightsFormat.hours(focus.current),
              delta: noFocus
                  ? null
                  // Hours with one decimal, like the value.
                  : KpiDelta(
                      ((focus.current - focus.previous) / 6).round() / 10,
                      'h',
                    ),
              onTap: startFocus,
              semanticHint: 'Starts a focus session',
            ),
            InsightsKpiCard(
              label: 'Habit consistency',
              value: InsightsFormat.percent(s.habitConsistency.current.rate),
              delta: _rateDelta(s.habitConsistency),
            ),
            InsightsKpiCard(
              label: 'Notes created',
              value: '${s.notesCreated.current}',
              delta: KpiDelta(
                s.notesCreated.current - s.notesCreated.previous,
                '',
              ),
            ),
          ],
        ),
        if (noFocus) ...[
          const SizedBox(height: AppSpacing.md),
          FFSecondaryButton(
            label: 'Start a focus session',
            icon: FontAwesomeIcons.stopwatch,
            onPressed: startFocus,
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        ProductivityChartCard(snapshot: s),
        const SizedBox(height: AppSpacing.xxl),
        TimeSplitCard(split: s.split),
        const SizedBox(height: AppSpacing.xxl),
        HabitStreaksCard(rows: s.streaks, hasHabits: s.hasHabits),
        const SizedBox(height: AppSpacing.xxl),
        WeeklyTipCard(tip: s.tip),
      ],
    );
  }
}

/// Placeholder layout while the first snapshot loads.
class InsightsSkeleton extends StatelessWidget {
  const InsightsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget kpi() => const FFCard(
      padding: EdgeInsetsDirectional.all(InsightsDimens.kpiPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FFSkeleton(widthFactor: 0.7, height: 12),
          SizedBox(height: AppSpacing.md),
          FFSkeleton(widthFactor: 0.5, height: InsightsDimens.kpiValue),
        ],
      ),
    );
    return ExcludeSemantics(
      child: FFShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InsightsKpiGrid(cards: [kpi(), kpi(), kpi(), kpi()]),
            const SizedBox(height: AppSpacing.xxl),
            const FFSkeleton(
              height: InsightsDimens.chartSkeleton,
              radius: AppRadii.card,
            ),
            const SizedBox(height: AppSpacing.xxl),
            const FFSkeleton(
              height: InsightsDimens.splitSkeleton,
              radius: AppRadii.card,
            ),
          ],
        ),
      ),
    );
  }
}
