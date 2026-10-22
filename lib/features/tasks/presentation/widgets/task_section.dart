/// ============================================================
/// TASK SECTION — one "OVERDUE · 2" / "TODAY · 5" / "COMPLETED · 2" block
/// ============================================================
///
/// What: the section label (with "Reschedule all" on Overdue and a
/// collapse chevron on Completed) followed by its rows as a
/// [SliverReorderableList]: the drag handle reorders inside the section.
/// A drag in smart sort switches the list to manual order, keeping what
/// the user saw.
/// Why: sections are slivers so the whole screen is one lazily built
/// scroll view; the drop is shown optimistically until the stream catches
/// up, so rows never jump back mid-animation.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/state/task_labels.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_list_item.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_row.dart';

/// Builds the slivers of one section: label + rows.
List<Widget> taskSectionSlivers({
  required String sectionKey,
  required List<TaskItem> tasks,
  required DateTime now,
  required bool use24h,
  required bool collapsed,
  required bool reorderable,
  String? hideListId,
}) => [
  SliverToBoxAdapter(
    child: TaskSectionHeader(
      sectionKey: sectionKey,
      tasks: tasks,
      collapsed: collapsed,
    ),
  ),
  if (!collapsed)
    TaskSectionList(
      key: ValueKey('section-$sectionKey'),
      tasks: tasks,
      now: now,
      use24h: use24h,
      reorderable: reorderable,
      hideListId: hideListId,
    ),
];

/// "OVERDUE · 2 … Reschedule all" / "COMPLETED · 2 ⌄".
class TaskSectionHeader extends ConsumerWidget {
  const TaskSectionHeader({
    required this.sectionKey,
    required this.tasks,
    required this.collapsed,
    super.key,
  });

  final String sectionKey;
  final List<TaskItem> tasks;
  final bool collapsed;

  static const EdgeInsetsGeometry _padding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.screen,
    AppSpacing.md,
    AppSpacing.screen,
    0,
  );

  /// Label row height (the "Reschedule all" / chevron tap area).
  static const double _height = TaskSizes.sectionRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final title = '${TaskLabels.section(sectionKey)} · ${tasks.length}';
    if (sectionKey == 'completed') {
      void toggle() =>
          ref.read(collapsedTaskSectionsProvider.notifier).toggle(sectionKey);
      return Padding(
        padding: _padding,
        child: Semantics(
          button: true,
          expanded: !collapsed,
          label: collapsed
              ? tr('Show completed tasks')
              : tr('Hide completed tasks'),
          // excludeSemantics drops the child's tap action; re-add it.
          onTap: toggle,
          excludeSemantics: true,
          child: FFPressable(
            onTap: toggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: _height),
              alignment: AlignmentDirectional.centerStart,
              child: FFSectionLabel(
                title,
                padding: EdgeInsetsDirectional.zero,
                trailing: AnimatedRotation(
                  turns: !collapsed
                      ? 0
                      : Directionality.of(context) == TextDirection.rtl
                      ? 0.25
                      : -0.25,
                  duration: context.motion(AppMotion.fast),
                  child: Icon(
                    FontAwesomeIcons.chevronDown,
                    size: TaskSizes.glyph,
                    color: ff.inkFaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final reschedule = sectionKey == 'overdue' && tasks.isNotEmpty;
    return Padding(
      padding: _padding,
      child: Container(
        constraints: const BoxConstraints(minHeight: _height),
        alignment: AlignmentDirectional.centerStart,
        child: FFSectionLabel(
          title,
          padding: EdgeInsetsDirectional.zero,
          trailing: reschedule
              ? _SectionLink(
                  label: tr('Reschedule all'),
                  color: ff.danger,
                  onTap: () => rescheduleTasks(
                    context,
                    ref,
                    tasks,
                    title: tr('Reschedule all'),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Compact section-header link ("Reschedule all"): 13 pt bold body text
/// as in the mockup (not the 16 pt Lexend text button), in a 44 × 44 pt
/// minimum hit box (same height as the text button it replaces).
class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.minTap,
          minWidth: AppSizes.minTap,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: 1,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.sectionAction.copyWith(color: color),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The rows of one section, reorderable by their drag handles.
class TaskSectionList extends ConsumerStatefulWidget {
  const TaskSectionList({
    required this.tasks,
    required this.now,
    required this.use24h,
    required this.reorderable,
    this.hideListId,
    super.key,
  });

  final List<TaskItem> tasks;
  final DateTime now;
  final bool use24h;
  final bool reorderable;
  final String? hideListId;

  @override
  ConsumerState<TaskSectionList> createState() => _TaskSectionListState();
}

class _TaskSectionListState extends ConsumerState<TaskSectionList> {
  /// The order after a drop, until the repository stream emits it.
  List<TaskItem>? _optimistic;

  @override
  void didUpdateWidget(TaskSectionList old) {
    super.didUpdateWidget(old);
    if (!identical(old.tasks, widget.tasks)) _optimistic = null;
  }

  /// [target] is the final index (already adjusted for the removed row).
  Future<void> _onReorder(int oldIndex, int target) async {
    final shown = _optimistic ?? widget.tasks;
    if (target == oldIndex) return;
    final order = [...shown];
    order.insert(target, order.removeAt(oldIndex));
    setState(() => _optimistic = order);
    final sort = ref.read(taskSortProvider);
    // TaskActions.reorder takes ReorderableList's unadjusted new index.
    final newIndex = target > oldIndex ? target + 1 : target;
    await ref
        .read(taskActionsProvider)
        .reorder(
          shown,
          oldIndex,
          newIndex,
          sort: sort,
          // Smart → manual seeds every section's on-screen order.
          visible: sort == TaskSort.smart
              ? ref.read(visibleTasksProvider)
              : const [],
        );
    if (sort == TaskSort.smart) {
      await ref.read(taskSortProvider.notifier).set(TaskSort.manual);
      if (mounted) {
        showFFToast(
          context,
          tr('Sorted manually'),
          icon: FontAwesomeIcons.gripVertical,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _optimistic ?? widget.tasks;
    return SliverPadding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      sliver: SliverReorderableList(
        itemCount: tasks.length,
        onReorderItem: _onReorder,
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.scale(
            scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
            child: child,
          ),
          child: child,
        ),
        itemBuilder: (context, index) {
          final task = tasks[index];
          final handle = widget.reorderable
              ? ReorderableDragStartListener(
                  index: index,
                  // Screen readers can't drag: Move up / Move down do the
                  // same reorder as a drop one row away.
                  child: Semantics(
                    container: true,
                    label: tr('Reorder {title}', {'title': task.title}),
                    customSemanticsActions: {
                      if (index > 0)
                        CustomSemanticsAction(label: tr('Move up')): () =>
                            _onReorder(index, index - 1),
                      if (index < tasks.length - 1)
                        CustomSemanticsAction(label: tr('Move down')): () =>
                            _onReorder(index, index + 1),
                    },
                    child: const TaskDragHandle(),
                  ),
                )
              : null;
          return Padding(
            key: ValueKey(task.id),
            padding: const EdgeInsetsDirectional.only(
              bottom: AppSpacing.cardGap,
            ),
            child: TaskListItem(
              task: task,
              now: widget.now,
              use24h: widget.use24h,
              hideListId: widget.hideListId,
              dragHandle: handle,
            ),
          );
        },
      ),
    );
  }
}
