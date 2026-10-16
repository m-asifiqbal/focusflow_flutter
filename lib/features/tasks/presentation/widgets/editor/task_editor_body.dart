/// ============================================================
/// TASK EDITOR BODY — the scrolling form of screen 11
/// ============================================================
///
/// What: title card → SCHEDULE → PRIORITY → ORGANISE → SUBTASKS →
/// Archive / Delete (existing tasks), spaced like the mockup (20 pt
/// gutters, 26 pt between sections).
/// Why: keeps the screen file to navigation and lifecycle flows; this
/// widget only lays out the sections over the current form state.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_editor_controller.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_chrome.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_organise_card.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_priority_selector.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_schedule_card.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_subtasks_section.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_title_card.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskEditorBody extends ConsumerWidget {
  const TaskEditorBody({
    required this.args,
    required this.state,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  final TaskEditorArgs args;
  final TaskEditorState state;

  /// Null hides Archive.
  final VoidCallback? onArchive;
  final VoidCallback onDelete;

  /// Space between a card and the next section label (mockup: 32 pt from
  /// the card to the label's centre, 20 pt from there to the next card).
  static const double _sectionGap = TaskSizes.sectionGap;

  /// Section label → its card.
  static const EdgeInsetsDirectional labelPadding =
      EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        TaskSizes.labelGap,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.read(taskEditorControllerProvider(args).notifier);
    final task = state.draft;
    const gap = SizedBox(height: _sectionGap);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        TaskTitleCard(
          title: task.title,
          notes: task.notes,
          autofocus: state.isNew && task.title.isEmpty,
          onTitleChanged: form.setTitle,
          onNotesChanged: form.setNotes,
        ),
        gap,
        const FFSectionLabel('Schedule', padding: labelPadding),
        TaskScheduleCard(args: args, task: task),
        gap,
        const FFSectionLabel('Priority', padding: labelPadding),
        TaskPrioritySelector(value: task.priority, onChanged: form.setPriority),
        gap,
        const FFSectionLabel('Organise', padding: labelPadding),
        TaskOrganiseCard(args: args, task: task),
        // The subtasks header is a 44 pt row (its "+ Add" tap target).
        const SizedBox(height: AppSpacing.sm),
        TaskSubtasksSection(args: args, subtasks: state.subtasks),
        if (!state.isNew) ...[
          const SizedBox(height: AppSpacing.xxl),
          TaskEditorFooter(onArchive: onArchive, onDelete: onDelete),
        ],
      ],
    );
  }
}
