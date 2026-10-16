/// ============================================================
/// HABIT CONSISTENCY CARD — heatmap section of the habit detail (16)
/// ============================================================
///
/// "Consistency ……… Last 4 months" header (tap toggles 4 months ⇄ 1 year)
/// over a card with the GitHub-style HabitHeatmap in the habit colour
/// (rest days outlined, not drawn as misses) and the "□ Rest day" +
/// "Less □□■■ More" legend. Tapping a day between the start date and today
/// opens the day editor.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_detail_providers.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_heatmap.dart';

class HabitConsistencyCard extends ConsumerWidget {
  const HabitConsistencyCard({
    required this.habit,
    required this.today,
    required this.onDay,
    super.key,
  });

  final Habit habit;
  final DateTime today;

  /// A tapped day in [start date, today].
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(habitHeatmapRangeProvider(habit.id));
    final values = ref.watch(habitHeatmapValuesProvider(habit.id));
    final restDays = ref.watch(habitHeatmapRestDaysProvider(habit.id));
    final weekStart = ref.watch(habitWeekStartProvider);
    final color = habit.colors.solid;
    final year = range == HabitHeatmapRange.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: 'Consistency',
          trailing: FFTextButton(
            label: range.label,
            semanticLabel: 'Heatmap range, ${range.label}. Tap to change',
            onPressed: ref
                .read(habitHeatmapRangeProvider(habit.id).notifier)
                .toggle,
            padding: EdgeInsetsDirectional.zero,
            style: context.text.buttonSmall.copyWith(
              fontSize: HabitDimens.rangeLink,
              color: context.ff.primary,
            ),
          ),
        ),
        const SizedBox(
          height:
              AppSpacing.md + AppSpacing.xxs - HabitDimens.actionHeaderInset,
        ),
        FFCard(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg + AppSpacing.xxs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HabitHeatmap(
                values: values,
                restDays: restDays,
                end: today,
                weeks: range.weeks,
                color: color,
                weekStart: weekStart,
                gap: year ? HabitDimens.heatmapGapYear : AppSpacing.xs,
                semanticLabel: 'Consistency, ${range.label.toLowerCase()}',
                onTap: (day) {
                  final d = DateTime(day.year, day.month, day.day);
                  if (d.isAfter(today) || d.isBefore(habit.startDate)) return;
                  onDay(d);
                },
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
              Row(
                children: [
                  if (restDays.isNotEmpty) const HabitRestDayKey(),
                  const Spacer(),
                  FFHeatmapLegend(color: color),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
