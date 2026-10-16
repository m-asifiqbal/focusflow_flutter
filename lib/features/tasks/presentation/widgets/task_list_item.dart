/// ============================================================
/// TASK LIST ITEM — a [TaskRow] wired to the app (screen 10)
/// ============================================================
///
/// What: wraps one row in [ItemSwipe] (swipe left → Archive / Delete,
/// swipe right → Complete) and connects it to the completion controller,
/// multi-select, the long-press actions sheet and the editor.
/// Why: the row itself stays pure presentation; this widget is the only
/// place that knows what a tap / check / swipe means.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/widgets/ff_open_origin.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_row.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/item_actions/item_swipe.dart';
import 'package:go_router/go_router.dart';

/// Multi-select scope of the Tasks list.
const String tasksSelectionScope = 'tasks';

class TaskListItem extends ConsumerWidget {
  const TaskListItem({
    required this.task,
    required this.now,
    this.use24h = false,
    this.hideListId,
    this.dragHandle,
    super.key,
  });

  final TaskItem task;
  final DateTime now;
  final bool use24h;

  /// List whose pill is redundant (that list's chip is selected).
  final String? hideListId;

  /// Drag handle wrapped in a drag-start listener (null = static handle).
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      taskCompletionProvider.select((ids) => ids.contains(task.id)),
    );
    final selection = ref.watch(itemSelectionProvider(tasksSelectionScope));
    final selecting = selection.active;
    final selected = selection.contains(task.ref);
    final selector = ref.read(
      itemSelectionProvider(tasksSelectionScope).notifier,
    );

    void onCheck(bool value) {
      if (selecting) {
        selector.toggle(task.ref);
      } else if (task.isCompleted) {
        reopenTask(ref, task.id);
      } else if (!pending) {
        completeTask(context, ref, task.id, title: task.title, delayed: true);
      }
    }

    final row = TaskRow(
      task: task,
      now: now,
      use24h: use24h,
      pendingDone: pending,
      selectionMode: selecting,
      selected: selected,
      hideListName: hideListId,
      dragHandle: dragHandle,
      onCheck: onCheck,
      onTap: () => selecting
          ? selector.toggle(task.ref)
          : context.push(AppRoutes.task(task.id)),
      onLongPress: () => selecting
          ? selector.toggle(task.ref)
          : showItemActions(context, ref, task.ref),
    );

    return ItemSwipe(
      item: task.ref,
      title: task.title,
      isPinned: task.isPinned,
      isFavorite: task.isFavorite,
      radius: AppRadii.row,
      enabled: !selecting,
      completeLabel: task.isCompleted ? 'Undo' : 'Complete',
      onComplete: () => task.isCompleted
          ? reopenTask(ref, task.id)
          : completeTask(context, ref, task.id, title: task.title),
      // The editor grows out of this row (open-container transition).
      child: FFOpenOriginTracker(radius: AppRadii.row, child: row),
    );
  }
}
