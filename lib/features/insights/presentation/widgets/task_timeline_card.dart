/// ============================================================
/// TASK TIMELINE CARD — Gantt of the tasks due in the range (Overview)
/// ============================================================
///
/// What: one bar per task from the day it was created to its due day, on an
/// axis of the selected range: red = overdue, tasks colour = still open,
/// green = done. A flat edge means the task was created before the range
/// started. At most [TaskTimeline.maxRows] rows (overdue first); the caption
/// says when more exist. Tap a row to open the task.
/// Why: the KPI and the donut count tasks; this shows *when* they were
/// meant to happen and which ones slipped. The rows come ready-made in the
/// snapshot, so drawing adds no queries.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_timeline.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:go_router/go_router.dart';

/// Axis labels for [window]: every day up to a week (weekday initials),
/// otherwise about five evenly spaced dates.
List<FFGanttTick> timelineTicks(InsightsWindow window) {
  final n = window.days;
  if (n <= 7) {
    final f = DateFormats.of('EEEEE');
    return [
      for (var u = 0; u < n; u++)
        FFGanttTick(u, f.format(DateUtilsX.addDays(window.start, u))),
    ];
  }
  final step = (n / 5).ceil();
  final f = DateFormats.of('MMM d');
  return [
    for (var u = 0; u < n; u += step)
      FFGanttTick(u, f.format(DateUtilsX.addDays(window.start, u))),
  ];
}

class TaskTimelineCard extends ConsumerWidget {
  const TaskTimelineCard({
    required this.timeline,
    required this.window,
    super.key,
  });

  final TaskTimeline timeline;
  final InsightsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final ff = context.ff;
    final n = window.days;
    final todayUnit = DateUtilsX.daysBetween(window.start, today);
    final colors = {
      TimelineState.overdue: ff.danger,
      TimelineState.open: ModuleStyle.tasks.solid,
      TimelineState.done: ff.success,
    };
    final names = {
      TimelineState.overdue: tr('Overdue'),
      TimelineState.open: tr('Still open'),
      TimelineState.done: tr('Done'),
    };
    final due = DateFormats.of('MMM d');
    final bars = [
      for (final t in timeline.rows)
        FFGanttBar(
          label: t.title.trim().isEmpty ? tr('Untitled task') : t.title,
          trailing: due.format(t.end),
          trailingColor: t.state == TimelineState.overdue
              ? colors[t.state]
              : null,
          startUnit: DateUtilsX.daysBetween(window.start, t.start),
          endUnit: DateUtilsX.daysBetween(window.start, t.end),
          continuesBefore: t.start.isBefore(window.start),
          color: colors[t.state]!,
          semanticLabel: tr('{title}, due {date}, {state}', {
            'title': t.title.trim().isEmpty ? tr('Untitled task') : t.title,
            'date': due.format(t.end),
            'state': names[t.state]!,
          }),
          onTap: () => context.push(AppRoutes.task(t.id)),
        ),
    ];
    return FFCard(
      padding: const EdgeInsetsDirectional.all(InsightsDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr('Task timeline'),
              style: context.text.sectionTitle.copyWith(
                fontSize: InsightsDimens.cardTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            timeline.total > timeline.rows.length
                ? tr('Showing {shown} of {total} tasks due in this range', {
                    'shown': timeline.rows.length,
                    'total': timeline.total,
                  })
                : tr('From created to due date'),
            style: context.text.meta,
          ),
          const SizedBox(height: InsightsDimens.cardGap),
          if (timeline.isEmpty)
            InsightsNoData(
              icon: FontAwesomeIcons.listCheck,
              message: tr('No tasks are due in this range.'),
            )
          else ...[
            FFGantt(
              bars: bars,
              units: n,
              ticks: timelineTicks(window),
              todayUnit: todayUnit >= 0 && todayUnit < n ? todayUnit : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                for (final s in TimelineState.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: InsightsDimens.legendDot,
                        height: InsightsDimens.legendDot,
                        decoration: BoxDecoration(
                          color: colors[s],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                      Text(names[s]!, style: context.text.caption),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
