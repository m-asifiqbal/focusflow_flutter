/// ============================================================
/// TASK ROW — one task card of the Tasks list (screen 10)
/// ============================================================
///
/// What: radius-20 card with the 4 pt priority bar on the start edge, the
/// blue check circle, title, meta line (due label · list/tag pill · repeat
/// icon · reminder bell), optional "n/m subtasks" progress, the subtasks
/// themselves (each with its own check circle: tick one without opening the
/// task; completing the task ticks them all) and the drag handle. Completed (or pending-complete) rows are struck through and
/// muted. In multi-select mode the check becomes a selection toggle.
/// Why: the row is pure presentation — callbacks come from the screen,
/// which talks to the controllers (no repository calls here).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/state/task_labels.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({
    required this.task,
    required this.now,
    required this.onTap,
    required this.onCheck,
    this.onLongPress,
    this.use24h = false,
    this.pendingDone = false,
    this.selectionMode = false,
    this.selected = false,
    this.hideListName,
    this.dragHandle,
    this.onSubtaskToggle,
    super.key,
  });

  final TaskItem task;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Check circle tapped (true = complete). In selection mode: toggle.
  final ValueChanged<bool> onCheck;
  final bool use24h;

  /// Shown as done while the completion is pending (1.2 s).
  final bool pendingDone;
  final bool selectionMode;
  final bool selected;

  /// List id whose pill is redundant (the list chip is selected).
  final String? hideListName;

  /// A subtask's check circle tapped. Null (selection mode, previews) makes
  /// the subtasks read-only.
  final ValueChanged<Subtask>? onSubtaskToggle;

  /// Subtasks drawn on the card; the rest is "+ n more" (opens the task).
  static const int maxSubtasksShown = 5;

  /// The handle, already wrapped in a drag listener by the list (null =
  /// not reorderable here; a static handle is drawn instead).
  final Widget? dragHandle;

  bool get _done => task.isCompleted || pendingDone;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final bar = _done ? null : TaskStyle.priorityColor(task.priority);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final card = FFCard(
      radius: AppRadii.row,
      padding: EdgeInsetsDirectional.zero,
      color: selected ? ff.primarySoft : null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          if (bar != null)
            PositionedDirectional(
              start: 0,
              top: AppSpacing.lg,
              bottom: AppSpacing.lg,
              width: TaskSizes.accentBar,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.horizontal(
                    left: rtl
                        ? const Radius.circular(TaskSizes.accentBarRadius)
                        : Radius.zero,
                    right: rtl
                        ? Radius.zero
                        : const Radius.circular(TaskSizes.accentBarRadius),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TaskSizes.inlineGap,
              TaskSizes.inlineGap,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _check(context),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _content(context)),
                const SizedBox(width: AppSpacing.xs),
                // Reserves the handle's visual box; the 44 pt hit area is
                // laid over it below so the row keeps its measured size.
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: TaskSizes.inlineGap),
                  child: SizedBox(
                    width: TaskDragHandle.boxWidth,
                    height: TaskDragHandle.boxHeight,
                  ),
                ),
              ],
            ),
          ),
          if (!selectionMode)
            PositionedDirectional(
              end: 0,
              top: TaskDragHandle.hitTop,
              width: AppSizes.minTap,
              height: AppSizes.minTap,
              child: dragHandle ?? const TaskDragHandle(),
            ),
        ],
      ),
    );
    return Semantics(
      label: TaskLabels.semantics(task, now, use24h: use24h),
      selected: selectionMode ? selected : null,
      child: card,
    );
  }

  Widget _check(BuildContext context) {
    final ff = context.ff;
    if (selectionMode) {
      return FFCheckCircle(
        checked: selected,
        color: ff.primary,
        size: TaskSizes.check,
        semanticLabel: selected
            ? 'Deselect ${task.title}'
            : 'Select ${task.title}',
        onChanged: onCheck,
      );
    }
    return FFCheckCircle(
      checked: _done,
      color: TaskStyle.module.solid,
      size: TaskSizes.check,
      semanticLabel: _done
          ? 'Mark ${task.title} as not done'
          : 'Complete ${task.title}',
      onChanged: onCheck,
    );
  }

  Widget _content(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: context.motion(AppMotion.fast),
            style: text.cardTitle.copyWith(
              color: _done ? ff.inkMuted : ff.ink,
              decoration: _done ? TextDecoration.lineThrough : null,
              decorationColor: ff.inkMuted,
              decorationThickness: 2,
            ),
            child: Text(
              task.title.isEmpty ? 'Untitled task' : task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ..._meta(context),
          if (task.subtasks.isNotEmpty) ...[
            if (!_done) ...[
              const SizedBox(height: AppSpacing.sm),
              _SubtaskProgress(task: task),
            ],
            const SizedBox(height: AppSpacing.xs),
            _SubtaskList(
              subtasks: task.subtasks,
              parentDone: _done,
              onToggle: selectionMode ? null : onSubtaskToggle,
              onMore: onTap,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _meta(BuildContext context) {
    final ff = context.ff;
    final due = TaskLabels.rowDue(task, now, use24h: use24h);
    final overdue = task.isOverdue(now) && !_done;
    final dueColor = overdue ? ff.danger : ff.inkMuted;
    final pill = _pillLabel();
    final items = <Widget>[
      if (due != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TaskLabels.rowDueIsTime(task, now)
                  ? FontAwesomeIcons.clock
                  : FontAwesomeIcons.calendar,
              size: TaskSizes.glyphSm,
              color: dueColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                due,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.taskRowMeta.copyWith(color: dueColor),
              ),
            ),
          ],
        ),
      if (pill != null) FFTag(pill.$1, colors: pill.$2),
      if (task.isRepeating)
        Semantics(
          label: 'Repeats',
          child: Icon(
            FontAwesomeIcons.arrowsRotate,
            size: TaskSizes.glyphMeta,
            color: _done ? ff.inkFaint : TaskStyle.module.solid,
          ),
        ),
      if (task.hasReminder)
        Semantics(
          label: 'Reminder',
          child: Icon(
            FontAwesomeIcons.bell,
            size: TaskSizes.glyphMeta,
            color: _done ? ff.inkFaint : ModuleStyle.reminders.solid,
          ),
        ),
    ];
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: TaskSizes.inlineGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    ];
  }

  /// The list name (unless filtering by that list), else the first tag.
  (String, dynamic)? _pillLabel() {
    final list = task.listName;
    if (list != null && list.isNotEmpty && task.listId != hideListName) {
      return (list, TaskStyle.labelColors(list));
    }
    if (task.tags.isNotEmpty) {
      final tag = task.tags.first;
      return (tag.name, TaskStyle.labelColors(tag.name, hex: tag.colorHex));
    }
    return null;
  }
}

/// The 2×3 dot grip at the row's end.
/// The grip at a task row's end. Fills a 44 × 44 pt hit area (laid over
/// the row's end padding) and draws the glyph where the mockup's 24 × 36
/// box puts it, so dragging is easy without moving the visuals.
class TaskDragHandle extends StatelessWidget {
  const TaskDragHandle({super.key});

  /// The handle's visual box at the row's end (centred on the title's
  /// first line).
  static const double boxWidth = 24;
  static const double boxHeight = 36;

  /// Top of the 44 pt hit area inside the card: the visual box's centre
  /// (row padding + offset + half its height) minus half the hit area.
  static const double hitTop =
      TaskSizes.inlineGap * 2 + boxHeight / 2 - AppSizes.minTap / 2;

  /// Hit-area padding around the visual box, measured from the card's end:
  /// the row's end padding, and what is left of 44 pt at the start.
  static const double _endInset = AppSpacing.md;
  static const double _startInset = AppSizes.minTap - boxWidth - _endInset;

  @override
  Widget build(BuildContext context) {
    // Opaque: the whole 44 pt box starts a drag, not only the glyph.
    return MetaData(
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: _startInset,
          end: _endInset,
        ),
        child: Center(
          child: Icon(
            FontAwesomeIcons.gripVertical,
            size: TaskSizes.glyphMd,
            color: context.ff.inkFaint.withValues(
              alpha: context.ff.isDark ? 0.35 : 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// The task's subtasks, one tappable row each (44 pt, the check circle's
/// hit area). While the task itself is done — or about to be (the 1.2 s
/// pending completion) — every subtask shows ticked: completing a task
/// completes its subtasks.
class _SubtaskList extends StatelessWidget {
  const _SubtaskList({
    required this.subtasks,
    required this.parentDone,
    required this.onToggle,
    required this.onMore,
  });

  final List<Subtask> subtasks;
  final bool parentDone;
  final ValueChanged<Subtask>? onToggle;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final shown = subtasks.take(TaskRow.maxSubtasksShown).toList();
    final more = subtasks.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final sub in shown)
          _SubtaskTile(
            subtask: sub,
            done: parentDone || sub.done,
            onToggle: onToggle,
          ),
        if (more > 0)
          Semantics(
            button: true,
            label: 'Show $more more subtasks',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMore,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTap),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.sm,
                    ),
                    child: Text(
                      '+ $more more',
                      style: context.text.meta.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ff.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubtaskTile extends StatelessWidget {
  const _SubtaskTile({
    required this.subtask,
    required this.done,
    required this.onToggle,
  });

  final Subtask subtask;
  final bool done;
  final ValueChanged<Subtask>? onToggle;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final title = subtask.title.trim().isEmpty ? 'Subtask' : subtask.title;
    return Row(
      children: [
        FFCheckCircle(
          checked: done,
          color: TaskStyle.module.solid,
          size: TaskSizes.subtaskRowCheck,
          semanticLabel: done
              ? 'Mark subtask $title as not done'
              : 'Complete subtask $title',
          onChanged: onToggle == null ? null : (_) => onToggle!(subtask),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: context.motion(AppMotion.fast),
            style: context.text.taskRowMeta.copyWith(
              color: done ? ff.inkFaint : ff.ink,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: ff.inkFaint,
            ),
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _SubtaskProgress extends StatelessWidget {
  const _SubtaskProgress({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Row(
      children: [
        SizedBox(
          width: TaskSizes.progressWidth,
          height: TaskSizes.progressHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: task.subtaskProgress,
              backgroundColor: ff.ink.withValues(alpha: 0.07),
              color: TaskStyle.module.solid,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            '${task.subtaskDone}/${task.subtaskTotal} subtasks',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.meta.copyWith(
              fontWeight: FontWeight.w500,
              color: ff.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
