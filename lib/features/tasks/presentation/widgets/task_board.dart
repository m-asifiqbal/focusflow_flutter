/// ============================================================
/// TASK BOARD — the optional To do / Doing / Done view (screen 10)
/// ============================================================
///
/// What: three horizontally scrolling columns over the current filter.
/// Open tasks sit in To do or Doing (`boardStatus`), completed ones in
/// Done. Cards tick off like rows; "Start" / "To do" buttons move a card
/// between the open columns; tap opens the editor, long-press the actions
/// sheet.
/// Why: "Board view toggle (optional v1.1)". Moves go through
/// [TaskActions.moveOnBoard], so completion rules (repeat spawning, Undo)
/// are the same as in the list.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_row.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class TaskBoard extends ConsumerWidget {
  const TaskBoard({required this.bottomInset, super.key});

  /// Space to keep clear under the cards (tab bar).
  final double bottomInset;

  static const List<String> columns = ['To do', 'Doing', 'Done'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskBoardTasksProvider);
    final tasks = async.valueOrNull;
    if (tasks == null) {
      return async.hasError
          ? Center(
              child: FFTextButton(
                label: 'Retry',
                onPressed: () => ref.invalidate(taskBoardTasksProvider),
              ),
            )
          : const SizedBox.shrink();
    }
    final byColumn = [<TaskItem>[], <TaskItem>[], <TaskItem>[]];
    for (final t in tasks) {
      byColumn[t.isCompleted ? 2 : t.boardStatus.clamp(0, 1)].add(t);
    }
    final width = math.min(MediaQuery.sizeOf(context).width * 0.78, 300.0);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        0,
      ),
      itemCount: columns.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
      itemBuilder: (context, i) => SizedBox(
        width: width,
        child: _BoardColumn(
          index: i,
          tasks: byColumn[i],
          bottomInset: bottomInset,
        ),
      ),
    );
  }
}

class _BoardColumn extends ConsumerWidget {
  const _BoardColumn({
    required this.index,
    required this.tasks,
    required this.bottomInset,
  });

  final int index;
  final List<TaskItem> tasks;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final pending = ref.watch(taskCompletionProvider);
    final actions = ref.read(taskActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(
          '${TaskBoard.columns[index]} · ${tasks.length}',
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.md,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsetsDirectional.only(
              bottom: bottomInset + AppSpacing.xxxl,
            ),
            itemCount: tasks.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.cardGap),
            itemBuilder: (context, i) {
              final task = tasks[i];
              final move = switch (index) {
                0 => ('Start', FontAwesomeIcons.play, 1),
                1 => ('To do', FontAwesomeIcons.arrowLeft, 0),
                _ => null,
              };
              return Column(
                key: ValueKey(task.id),
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The editor grows out of this card, as from the list.
                  FFOpenOriginTracker(
                    radius: AppRadii.row,
                    child: TaskRow(
                      task: task,
                      now: now,
                      use24h: use24h,
                      pendingDone: pending.contains(task.id),
                      dragHandle: const SizedBox.shrink(),
                      onTap: () => context.push(AppRoutes.task(task.id)),
                      onLongPress: () =>
                          showItemActions(context, ref, task.ref),
                      onCheck: (_) => task.isCompleted
                          ? reopenTask(ref, task.id)
                          : completeTask(
                              context,
                              ref,
                              task.id,
                              title: task.title,
                              delayed: true,
                            ),
                    ),
                  ),
                  if (move != null)
                    FFTextButton(
                      label: move.$1,
                      icon: move.$2,
                      onPressed: () => actions.moveOnBoard(task, move.$3),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
