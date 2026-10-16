/// ============================================================
/// TASK ITEM ACTIONS — task rows of the shared actions sheet (screen 09)
/// ============================================================
///
/// What: Complete (or "Mark as not done"), Change due date and Priority,
/// shown above the generic rows of the long-press sheet.
/// Why: owned by the tasks feature (see
/// shared/item_actions/module_item_actions.dart); the flows themselves
/// (Undo snackbars, sheets) live in task_flows.dart so the list, the board
/// and the sheet behave identically.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';
import 'package:focusflow/features/insights/presentation/widgets/focus_timer_sheet.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Module rows for [item]. Each row's onTap runs after the sheet closes.
Future<ModuleItemActions> taskItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final task = await ref.read(tasksRepositoryProvider).getTask(item.ref.id);
  if (task == null || !task.isActive) return ModuleItemActions.none;
  return ModuleItemActions(
    leading: [
      FFActionItem(
        icon: task.isCompleted
            ? FontAwesomeIcons.arrowRotateLeft
            : FontAwesomeIcons.solidCircleCheck,
        label: task.isCompleted ? 'Mark as not done' : 'Complete',
        colors: ModuleStyle.tasks.colors,
        onTap: () {
          if (!context.mounted) return;
          if (task.isCompleted) {
            reopenTask(ref, task.id);
          } else {
            completeTask(context, ref, task.id, title: task.title);
          }
        },
      ),
      FFActionItem(
        icon: FontAwesomeIcons.calendarDays,
        label: task.dueDate == null ? 'Set due date' : 'Change due date',
        colors: TagPalette.work,
        onTap: () {
          if (context.mounted) {
            rescheduleTasks(context, ref, [task], title: 'Due date');
          }
        },
      ),
      if (!task.isCompleted)
        FFActionItem(
          icon: FontAwesomeIcons.stopwatch,
          label: 'Focus on this task',
          colors: ModuleStyle.notes.colors,
          onTap: () {
            if (context.mounted) {
              // Logs a focus session against the task (Insights › Focus hours).
              showFocusTimer(context, taskId: task.id, taskTitle: task.title);
            }
          },
        ),
      FFActionItem(
        icon: FontAwesomeIcons.solidFlag,
        label: 'Priority',
        colors: priorityTint(task.priority),
        onTap: () {
          if (context.mounted) {
            pickTaskPriority(context, ref, task.id, task.priority);
          }
        },
      ),
    ],
  );
}
