/// ============================================================
/// TASKS HEADER — "Tasks · 7 due today · 2 overdue" (screen 10)
/// ============================================================
///
/// What: the large header with the list/board toggle and the ⋯ menu; in
/// multi-select it becomes a compact "3 selected" bar with Done, bulk
/// Complete, Reschedule and Select all.
/// Why: the counts come live from [taskStatsProvider]; bulk actions use
/// the same flows as single rows (Undo snackbars included).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_sections.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/state/task_labels.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_list_item.dart';
import 'package:focusflow/features/tasks/presentation/widgets/tasks_menus.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';

class TasksHeader extends ConsumerWidget {
  const TasksHeader({super.key});

  static const EdgeInsetsGeometry _padding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.screen,
    AppSpacing.sm,
    AppSpacing.screen,
    AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(itemSelectionProvider(tasksSelectionScope));
    if (selection.active) return const _SelectionHeader();
    final stats = ref.watch(taskStatsProvider).valueOrNull ?? TaskStats.empty;
    final view = ref.watch(taskViewProvider);
    final board = view == TaskView.board;
    return FFLargeHeader(
      title: 'Tasks',
      leading: const FFBackButton(),
      fitTitle: true,
      padding: _padding,
      subtitle: TaskLabels.headerSubtitle(
        dueToday: stats.today,
        overdue: stats.overdue,
      ),
      actions: [
        FFRoundIconButton(
          icon: board ? FontAwesomeIcons.tableColumns : FontAwesomeIcons.listUl,
          semanticLabel: board ? 'Show as list' : 'Show as board',
          onPressed: () => ref
              .read(taskViewProvider.notifier)
              .set(board ? TaskView.list : TaskView.board),
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.ellipsis,
          semanticLabel: 'More options',
          onPressed: () => showTasksMoreMenu(context, ref),
        ),
      ],
    );
  }
}

class _SelectionHeader extends ConsumerWidget {
  const _SelectionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(itemSelectionProvider(tasksSelectionScope));
    final selector = ref.read(
      itemSelectionProvider(tasksSelectionScope).notifier,
    );
    final visible = ref.watch(visibleTasksProvider);
    final chosen = [
      for (final t in visible)
        if (sel.contains(t.ref)) t,
    ];
    final open = chosen.where((t) => !t.isCompleted).toList();
    final allSelected = visible.isNotEmpty && chosen.length == visible.length;

    Future<void> completeAll() async {
      final controller = ref.read(taskCompletionProvider.notifier);
      for (final t in open) {
        controller.complete(t.id, after: Duration.zero);
      }
      selector.clear();
      showUndoSnackbar(
        context,
        message: open.length == 1
            ? '1 task completed'
            : '${open.length} tasks completed',
        icon: FontAwesomeIcons.solidCircleCheck,
        onUndo: () {
          for (final t in open) {
            controller.undo(t.id);
          }
        },
      );
    }

    // A compact nav header: the large title has no room for four actions
    // at 360 pt.
    return FFNavHeader(
      leading: FFNavAction(
        label: 'Done',
        emphasized: true,
        onPressed: selector.clear,
      ),
      title: sel.count == 0 ? 'Select tasks' : '${sel.count} selected',
      trailing: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.check,
          semanticLabel: 'Complete selected tasks',
          onPressed: open.isEmpty ? null : completeAll,
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.calendarDays,
          semanticLabel: 'Reschedule selected tasks',
          onPressed: chosen.isEmpty
              ? null
              : () async {
                  final changed = await rescheduleTasks(context, ref, chosen);
                  if (changed) selector.clear();
                },
        ),
        FFNavAction(
          label: allSelected ? 'None' : 'All',
          onPressed: () => allSelected
              ? selector.selectAll(const [])
              : selector.selectAll(visible.map((t) => t.ref)),
        ),
      ],
    );
  }
}
