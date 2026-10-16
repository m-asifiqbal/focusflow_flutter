/// ============================================================
/// HOME TASKS SECTION — "Today's Tasks ……… 3 LEFT"
/// ============================================================
///
/// What: up to five tasks due on the selected day (open first by time,
/// completed last), the "N LEFT" badge, "View all" when there are more,
/// the per-day empty state with an inline "Add task", and (today only) the
/// "Get started" checklist until its three steps are done.
/// Why: completing goes through the tasks lane's flow (haptic in the check
/// circle, Undo snackbar); the list is a live stream, so completions on
/// other screens show here at once.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/home/presentation/widgets/home_task_tile.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeTasksSection extends ConsumerWidget {
  const HomeTasksSection({super.key});

  /// "Today's Tasks" / "Tomorrow's Tasks" / "Tasks · Wed, Jun 14".
  static String titleFor(DateTime day, DateTime today) {
    final diff = DateUtilsX.daysBetween(today, day);
    if (diff == 0) return "Today's Tasks";
    if (diff == 1) return "Tomorrow's Tasks";
    if (diff == -1) return "Yesterday's Tasks";
    return 'Tasks · ${DateFormat('EEE, MMM d').format(day)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(homeDayProvider);
    final today = ref.watch(todayProvider);
    final tasks = ref.watch(homeTasksProvider(day));
    final getStarted = ref.watch(homeGetStartedProvider);
    final firstRun = ref.watch(homeFirstRunProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final left = tasks.valueOrNull?.where((t) => !t.isCompleted).length ?? 0;
    final isToday = DateUtilsX.isSameDay(day, today);

    final Widget body = tasks.when(
      skipLoadingOnReload: true,
      error: (_, _) =>
          HomeErrorCard(onRetry: () => ref.invalidate(homeTasksProvider(day))),
      loading: () => const FFSkeletonList(count: 2, kind: FFSkeletonKind.row),
      data: (value) {
        if (value.isNotEmpty) return _TaskList(tasks: value, use24h: use24h);
        if (isToday && getStarted != null && !getStarted.isComplete) {
          return HomeGetStartedCard(progress: getStarted, firstRun: firstRun);
        }
        return HomeEmptyCard(
          colors: ModuleStyle.tasks.colors,
          icon: ModuleStyle.tasks.icon,
          title: isToday ? 'No tasks today' : 'No tasks this day',
          body: 'Enjoy the space, or plan something small.',
          ctaLabel: 'Add task',
          onCta: () =>
              context.push(AppRoutes.newTask(date: DateUtilsX.dayKey(day))),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: titleFor(day, today),
          trailing: left > 0 ? FFBadge('$left left') : null,
        ),
        const SizedBox(height: HomeDimens.headerGap),
        body,
      ],
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.use24h});

  final List<TaskItem> tasks;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = tasks.take(HomeRules.maxTasks).toList();
    final more = tasks.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, t) in shown.indexed) ...[
          if (i > 0) const SizedBox(height: HomeDimens.taskGap),
          FFOpenOriginTracker(
            key: ValueKey(t.id),
            radius: AppRadii.row,
            child: HomeTaskTile(
              task: t,
              use24h: use24h,
              onTap: () => context.push(AppRoutes.task(t.id)),
              onLongPress: () => showItemActions(context, ref, t.ref),
              onCheck: (complete) => complete
                  ? completeTask(context, ref, t.id, title: t.title)
                  : reopenTask(ref, t.id),
            ),
          ),
        ],
        if (more > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FFTextButton(
              label: 'View all ${tasks.length} tasks',
              onPressed: () => context.push(AppRoutes.tasks),
            ),
          ),
      ],
    );
  }
}
