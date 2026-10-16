/// ============================================================
/// TASK TITLE CARD — title + notes fields at the top of screen 11
/// ============================================================
///
/// What: one card with the title (Lexend 20 w600) above a full-width
/// divider and the multi-line notes field (muted body text).
/// Why: the fields own their TextEditingControllers (seeded once from the
/// loaded task) and report every change to the editor controller, so the
/// form state stays the single source of truth for Save / discard.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskTitleCard extends StatefulWidget {
  const TaskTitleCard({
    required this.title,
    required this.notes,
    required this.onTitleChanged,
    required this.onNotesChanged,
    this.autofocus = false,
    super.key,
  });

  /// Initial values (read once).
  final String title;
  final String notes;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onNotesChanged;

  /// Focus the title (new task).
  final bool autofocus;

  @override
  State<TaskTitleCard> createState() => _TaskTitleCardState();
}

class _TaskTitleCardState extends State<TaskTitleCard> {
  late final _title = TextEditingController(text: widget.title);
  late final _notes = TextEditingController(text: widget.notes);
  final _notesFocus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const bare = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      isCollapsed: true,
      contentPadding: EdgeInsets.zero,
    );
    return FFCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: TextField(
              controller: _title,
              autofocus: widget.autofocus,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: widget.onTitleChanged,
              onSubmitted: (_) => _notesFocus.requestFocus(),
              style: context.text.editorTitle.copyWith(color: ff.ink),
              decoration: bare.copyWith(
                hintText: 'Task title',
                hintStyle: context.text.editorTitle.copyWith(
                  color: ff.inkFaint,
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: ff.divider),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              TaskSizes.labelGap,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _notes,
              focusNode: _notesFocus,
              minLines: 2,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: widget.onNotesChanged,
              style: context.text.editorNotes.copyWith(color: ff.inkMuted),
              decoration: bare.copyWith(
                hintText: 'Add notes',
                hintStyle: context.text.editorNotes.copyWith(
                  color: ff.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
