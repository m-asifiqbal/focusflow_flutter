/// ============================================================
/// TASK FLOWS — the UI flows around task writes (snackbars, sheets)
/// ============================================================
///
/// What: complete (with the 5 s Undo snackbar), reopen, subtask ticks (the
/// last one completes the task), reschedule via the
/// due date sheet (with Undo) and the priority sheet. Rows, swipe actions,
/// the long-press sheet (task_item_actions.dart), the board and the
/// editor all call these.
/// Why: CLAUDE.md rule 3 — every destructive action gets an Undo
/// snackbar — and rule 5 — widgets only trigger flows; the writes live in
/// [TaskCompletionController] / [TaskActions].
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/due_date_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

String _quoted(String title) =>
    title.trim().isEmpty ? 'Task' : '"${title.trim()}"';

/// Completes the open task [id] and shows "… completed · UNDO". With
/// [delayed] the row stays in place for 1.2 s (tap on the check) — skipped
/// under reduce motion. Undo reopens it and discards the next occurrence
/// a repeating task spawned.
void completeTask(
  BuildContext context,
  WidgetRef ref,
  String id, {
  required String title,
  bool delayed = false,
}) {
  final controller = ref.read(taskCompletionProvider.notifier);
  final wait = delayed && !context.reduceMotion
      ? TaskCompletionController.delay
      : Duration.zero;
  controller.complete(id, after: wait);
  showUndoSnackbar(
    context,
    message: '${_quoted(title)} completed',
    icon: FontAwesomeIcons.solidCircleCheck,
    onUndo: () => controller.undo(id),
  );
}

/// Reopens a completed task (tap on a filled check / "Mark as not done").
Future<void> reopenTask(WidgetRef ref, String id) =>
    ref.read(taskCompletionProvider.notifier).reopen(id);

/// A subtask's check circle was tapped on a row or board card. A task is
/// done exactly when all its subtasks are ([TaskActions.toggleSubtask]):
/// ticking the last open one completes the task with the same delay and
/// "… completed · UNDO" as its own check (Undo un-ticks that subtask too);
/// un-ticking one of a done task reopens it.
Future<void> toggleTaskSubtask(
  BuildContext context,
  WidgetRef ref,
  TaskItem task,
  Subtask subtask,
) async {
  // Everything the flow needs from context / ref is read before the await:
  // the row may be gone when the write lands.
  final actions = ref.read(taskActionsProvider);
  final controller = ref.read(taskCompletionProvider.notifier);
  final wait = context.reduceMotion
      ? Duration.zero
      : TaskCompletionController.delay;
  final outcome = await actions.toggleSubtask(
    task,
    subtask,
    completeAfter: wait,
  );
  if (outcome != SubtaskOutcome.completedTask || !context.mounted) return;
  showUndoSnackbar(
    context,
    message: '${_quoted(task.title)} completed',
    icon: FontAwesomeIcons.solidCircleCheck,
    onUndo: () => controller.undo(task.id),
  );
}

/// Asks for a new due date for [tasks] and moves them, with Undo.
/// Returns true when anything changed.
Future<bool> rescheduleTasks(
  BuildContext context,
  WidgetRef ref,
  List<TaskItem> tasks, {
  String title = 'Reschedule',
}) async {
  if (tasks.isEmpty) return false;
  final settings = ref.read(settingsProvider);
  final now = ref.read(clockProvider).now();
  final single = tasks.length == 1 ? tasks.first : null;
  final picked = await showDueDateSheet(
    context,
    today: now,
    weekStartsOn: settings.weekStartsOn,
    current: single?.dueDate,
    title: title,
    subtitle: single == null
        ? '${tasks.length} tasks'
        : (single.title.isEmpty ? null : single.title),
  );
  if (picked == null || !context.mounted) return false;
  final undo = await ref
      .read(taskActionsProvider)
      .reschedule(tasks, picked.value);
  if (!context.mounted) return true;
  final what = single == null ? '${tasks.length} tasks' : _quoted(single.title);
  showUndoSnackbar(
    context,
    message: picked.value == null ? '$what: date removed' : '$what rescheduled',
    icon: FontAwesomeIcons.calendarDays,
    onUndo: undo,
  );
  return true;
}

/// The priority choices (High → None) with their bar colours.
List<OptionItem<TaskPriority>> priorityOptions(BuildContext context) => [
  for (final p in TaskPriority.values.reversed)
    OptionItem(
      value: p,
      label: p == TaskPriority.none ? 'No priority' : p.label,
      dotColor: TaskStyle.priorityColor(p) ?? context.ff.inkFaint,
    ),
];

/// Picks a priority for task [id] (currently [current]).
Future<void> pickTaskPriority(
  BuildContext context,
  WidgetRef ref,
  String id,
  TaskPriority current,
) async {
  final picked = await showOptionSheet<TaskPriority>(
    context,
    title: 'Priority',
    options: priorityOptions(context),
    selected: current,
  );
  if (picked == null || picked.value == current) return;
  await ref.read(taskActionsProvider).setPriority(id, picked.value);
}

/// Icon tint of the "Priority" row (the task's current priority colour).
ModuleColors priorityTint(TaskPriority p) => switch (p) {
  TaskPriority.high => TagPalette.high,
  TaskPriority.medium => TagPalette.finance,
  TaskPriority.low => TagPalette.ideas,
  TaskPriority.none => ActionTints.lock,
};
