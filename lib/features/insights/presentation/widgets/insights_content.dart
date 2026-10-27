/// ============================================================
/// INSIGHTS CONTENT — the sections below the range chips (mockup 25)
/// ============================================================
///
/// What: [InsightsContent] lays out the KPI grid, productivity chart,
/// task timeline (Gantt), time split, habit streaks and weekly tip for one snapshot;
/// [InsightsSkeleton] mirrors that layout while the first snapshot loads.
/// Why: the screen only switches between loading / error / data; each
/// card handles its own "Not enough data" state.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/focus_timer_sheet.dart';
import 'package:focusflow/features/insights/presentation/widgets/habit_streaks_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_kpi_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_motion.dart';
import 'package:focusflow/features/insights/presentation/widgets/productivity_chart_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/task_timeline_card.dart';
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

  /// A rate as a count-up target (84.0 for 84%); null keeps the "—".
  static double? _pct(double? rate) => rate == null ? null : rate * 100;

  static String _fmtPct(double v) => '${v.round()}%';

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final focus = s.focusMinutes;
    final noFocus = focus.current == 0 && focus.previous == 0;
    void startFocus() => showFocusTimer(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsightsReveal(
          index: 0,
          child: InsightsKpiGrid(
            cards: [
              InsightsKpiCard(
                label: tr('Task completion'),
                value: InsightsFormat.percent(s.taskCompletion.current.rate),
                number: _pct(s.taskCompletion.current.rate),
                format: _fmtPct,
                delta: _rateDelta(s.taskCompletion),
              ),
              InsightsKpiCard(
                label: tr('Focus hours'),
                value: InsightsFormat.hours(focus.current),
                number: focus.current.toDouble(),
                format: (v) => InsightsFormat.hours(v.round()),
                delta: noFocus
                    ? null
                    // Hours with one decimal, like the value.
                    : KpiDelta(
                        ((focus.current - focus.previous) / 6).round() / 10,
                        tr('h'),
                      ),
                onTap: startFocus,
                semanticHint: tr('Starts a focus session'),
              ),
              InsightsKpiCard(
                label: tr('Habit consistency'),
                value: InsightsFormat.percent(s.habitConsistency.current.rate),
                number: _pct(s.habitConsistency.current.rate),
                format: _fmtPct,
                delta: _rateDelta(s.habitConsistency),
              ),
              InsightsKpiCard(
                label: tr('Notes created'),
                value: '${s.notesCreated.current}',
                number: s.notesCreated.current.toDouble(),
                format: (v) => '${v.round()}',
                delta: KpiDelta(
                  s.notesCreated.current - s.notesCreated.previous,
                  '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        InsightsReveal(index: 1, child: ProductivityChartCard(snapshot: s)),
        const SizedBox(height: AppSpacing.xxl),
        InsightsReveal(
          index: 2,
          child: TaskTimelineCard(timeline: s.timeline, window: s.window),
        ),
        const SizedBox(height: AppSpacing.xxl),
        InsightsReveal(index: 3, child: TimeSplitCard(split: s.split)),
        const SizedBox(height: AppSpacing.xxl),
        InsightsReveal(
          index: 4,
          child: HabitStreaksCard(rows: s.streaks, hasHabits: s.hasHabits),
        ),
        const SizedBox(height: AppSpacing.xxl),
        InsightsReveal(index: 5, child: WeeklyTipCard(tip: s.tip)),
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
