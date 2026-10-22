/// ============================================================
/// TASK SUBTASK ROW — one editable subtask of screen 11
/// ============================================================
///
/// What: check circle · inline title field (strike-through when done) ·
/// drag handle; swipe left to delete. Enter on a non-empty title asks for
/// the next row; the screen-reader "Delete subtask" action mirrors the
/// swipe.
/// Why: rows are 48 pt like the mockup and keep their own controller so
/// typing never fights rebuilds from the form state.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskSubtaskRow extends StatefulWidget {
  const TaskSubtaskRow({
    required this.row,
    required this.index,
    required this.color,
    required this.onToggle,
    required this.onRename,
    required this.onSubmit,
    required this.onDelete,
    this.autofocus = false,
    super.key,
  });

  final EditorSubtask row;

  /// Position in the reorderable list (drag handle).
  final int index;

  /// Check circle colour (Tasks blue).
  final Color color;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;

  /// Enter pressed on a non-empty title.
  final VoidCallback onSubmit;
  final VoidCallback onDelete;
  final bool autofocus;

  @override
  State<TaskSubtaskRow> createState() => _TaskSubtaskRowState();
}

class _TaskSubtaskRowState extends State<TaskSubtaskRow> {
  late final _text = TextEditingController(text: widget.row.title);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(TaskSubtaskRow old) {
    super.didUpdateWidget(old);
    // Undo / restore can bring back a different title for this key.
    if (widget.row.title != _text.text && !_focus.hasFocus) {
      _text.text = widget.row.title;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submitted(String value) {
    if (value.trim().isEmpty) {
      _focus.unfocus();
      return;
    }
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final done = widget.row.done;
    final title = widget.row.title.trim();
    final reduce = context.reduceMotion;
    final style = context.text.editorValue.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: done ? ff.inkFaint : ff.ink,
      decoration: done ? TextDecoration.lineThrough : null,
      decorationColor: ff.inkFaint,
    );
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TaskSizes.inlineGap,
        AppSpacing.xxs,
        AppSpacing.xxs,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          FFCheckCircle(
            checked: done,
            size: TaskSizes.subtaskCheck,
            color: widget.color,
            semanticLabel: title.isEmpty
                ? tr('Subtask done')
                : tr('{title} done', {'title': title}),
            onChanged: (_) => widget.onToggle(),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              autofocus: widget.autofocus,
              style: style,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: widget.onRename,
              onSubmitted: _submitted,
              onEditingComplete: () {},
              decoration: InputDecoration(
                hintText: tr('Subtask'),
                hintStyle: style.copyWith(
                  color: ff.inkFaint,
                  decoration: TextDecoration.none,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: TaskSizes.rowGap,
                ),
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: widget.index,
            child: Semantics(
              label: title.isEmpty
                  ? tr('Reorder subtask')
                  : tr('Reorder {title}', {'title': title}),
              button: true,
              child: SizedBox.square(
                dimension: AppSizes.minTap,
                child: Center(
                  child: Icon(
                    FontAwesomeIcons.gripLines,
                    size: TaskSizes.glyph,
                    color: Color.lerp(ff.inkFaint, ff.surface, 0.35),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: tr('Delete subtask')): widget.onDelete,
      },
      child: Dismissible(
        key: ValueKey('swipe-${widget.row.key}'),
        direction: DismissDirection.endToStart,
        movementDuration: reduce ? Duration.zero : AppMotion.normal,
        resizeDuration: reduce ? null : AppMotion.fast,
        onDismissed: (_) => widget.onDelete(),
        background: ColoredBox(
          color: ff.danger,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
              child: Icon(
                FontAwesomeIcons.trashCan,
                size: TaskSizes.glyphMd,
                color: ff.onPrimary,
                semanticLabel: tr('Delete'),
              ),
            ),
          ),
        ),
        child: content,
      ),
    );
  }
}
