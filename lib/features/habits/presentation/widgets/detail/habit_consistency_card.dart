/// ============================================================
/// HABIT CONSISTENCY CARD — heatmap section of the habit detail (16)
/// ============================================================
///
/// "Consistency ……… This week ⌄" header: the range link has a chevron and
/// opens a small sheet to pick This week (the default) · This month · Last 4
/// months · Last year
/// over a card with the HabitHeatmap in the habit colour (a calendar for the
/// week and month, the GitHub-style grid for 4 months and a year)
/// (rest days outlined, not drawn as misses) and the "□ Rest day" +
/// "Less □□■■ More" legend. Tapping a day between the start date and today
/// opens the day editor.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
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

  /// The range sheet: the four spans, the current one ticked.
  void _pick(BuildContext context, WidgetRef ref, HabitHeatmapRange current) {
    showFFActionSheet(
      context,
      FFActionSheetData(
        header: FFActionSheetHeader(
          title: tr('Consistency'),
          icon: FontAwesomeIcons.calendarDays,
          colors: habit.colors,
        ),
        actions: [
          for (final r in HabitHeatmapRange.values)
            FFActionItem(
              icon: r == current ? FontAwesomeIcons.check : r.icon,
              label: r.label,
              colors: habit.colors,
              onTap: () => ref
                  .read(habitHeatmapRangeProvider(habit.id).notifier)
                  .select(r),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(habitHeatmapRangeProvider(habit.id));
    final values = ref.watch(habitHeatmapValuesProvider(habit.id));
    final restDays = ref.watch(habitHeatmapRestDaysProvider(habit.id));
    final weekStart = ref.watch(habitWeekStartProvider);
    final color = habit.colors.solid;
    final year = range == HabitHeatmapRange.year;
    final calendar = range.isCalendar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Consistency'),
          trailing: _RangeLink(
            range: range,
            onPressed: () => _pick(context, ref, range),
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
                weeks: range.weeksFor(today, weekStart),
                calendar: calendar,
                from: range.firstDay(today),
                color: color,
                weekStart: weekStart,
                gap: year ? HabitDimens.heatmapGapYear : AppSpacing.xs,
                semanticLabel: tr('Consistency, {toLowerCase}', {
                  'toLowerCase': range.label.toLowerCase(),
                }),
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

/// "This week ⌄": the current range and a chevron that says it can be
/// changed (44-pt tap target).
class _RangeLink extends StatelessWidget {
  const _RangeLink({required this.range, required this.onPressed});

  final HabitHeatmapRange range;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = context.ff.primary;
    return Semantics(
      button: true,
      label: tr('Heatmap range, {label}. Tap to change', {
        'label': range.label,
      }),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        scale: 0.96,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                range.label,
                style: context.text.buttonSmall.copyWith(
                  fontSize: HabitDimens.rangeLink,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
              Icon(FontAwesomeIcons.chevronDown, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
