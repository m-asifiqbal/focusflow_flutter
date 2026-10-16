/// ============================================================
/// TASK SUBTASKS SECTION — "SUBTASKS · 2/3  + Add" of screen 11
/// ============================================================
///
/// What: label with the done/total count and "+ Add", then a card of
/// subtask rows — check circle, inline-editable title (Enter adds the next
/// row), drag handle to reorder; swipe a row left to delete (Undo).
/// Why: subtasks are edited in the form and saved with the task, so every
/// gesture just calls the editor controller; rows keep their own text
/// controllers keyed by the row's stable local key.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_editor_controller.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_subtask_row.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskSubtasksSection extends ConsumerStatefulWidget {
  const TaskSubtasksSection({
    required this.args,
    required this.subtasks,
    super.key,
  });

  final TaskEditorArgs args;
  final List<EditorSubtask> subtasks;

  @override
  ConsumerState<TaskSubtasksSection> createState() =>
      _TaskSubtasksSectionState();
}

class _TaskSubtasksSectionState extends ConsumerState<TaskSubtasksSection> {
  /// The row that should take focus when it is built (just added).
  String? _focusKey;

  TaskEditorController get _form =>
      ref.read(taskEditorControllerProvider(widget.args).notifier);

  void _add({String? afterKey}) {
    final key = _form.addSubtask(afterKey: afterKey);
    setState(() => _focusKey = key);
  }

  void _delete(EditorSubtask row) {
    final index = _form.removeSubtask(row.key);
    if (index < 0) return;
    showUndoSnackbar(
      context,
      message: row.title.trim().isEmpty
          ? 'Subtask deleted'
          : '"${row.title.trim()}" deleted',
      icon: FontAwesomeIcons.trashCan,
      onUndo: () => _form.restoreSubtask(index, row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final rows = widget.subtasks;
    final done = rows.where((r) => r.done).length;
    final radius = BorderRadius.circular(AppRadii.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A 44 pt row (tap target of "+ Add") drawn 3 pt low so the label
        // sits 19 pt above the card like the mockup.
        Transform.translate(
          offset: const Offset(0, TaskSizes.hairGap),
          child: SizedBox(
            height: AppSizes.minTap,
            child: FFSectionLabel(
              rows.isEmpty ? 'Subtasks' : 'Subtasks · $done/${rows.length}',
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs,
              ),
              trailing: FFTextButton(
                label: '+ Add',
                semanticLabel: 'Add subtask',
                onPressed: _add,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xxs,
                ),
                style: context.text.editorInlineAction.copyWith(
                  color: ff.primary,
                ),
              ),
            ),
          ),
        ),
        FFCard(
          padding: EdgeInsetsDirectional.zero,
          child: rows.isEmpty
              ? FFListRow(
                  leading: Icon(
                    FontAwesomeIcons.plus,
                    size: TaskSizes.glyphCheck,
                    color: ff.primary,
                  ),
                  title: 'Add a subtask',
                  chevron: false,
                  onTap: _add,
                )
              : ClipRRect(
                  borderRadius: radius,
                  child: ReorderableList(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    onReorderItem: _form.moveSubtask,
                    proxyDecorator: (child, _, _) => Material(
                      color: ff.surface,
                      borderRadius: radius,
                      elevation: 6,
                      shadowColor: ff.scrim,
                      child: child,
                    ),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return TaskSubtaskRow(
                        key: ValueKey(row.key),
                        row: row,
                        index: i,
                        color: TaskStyle.module.solid,
                        autofocus: row.key == _focusKey,
                        onToggle: () => _form.toggleSubtask(row.key),
                        onRename: (t) => _form.renameSubtask(row.key, t),
                        onSubmit: () => _add(afterKey: row.key),
                        onDelete: () => _delete(row),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
