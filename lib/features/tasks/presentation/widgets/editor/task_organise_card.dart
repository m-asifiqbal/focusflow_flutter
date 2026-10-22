/// ============================================================
/// TASK ORGANISE CARD — ORGANISE group of screen 11
/// ============================================================
///
/// What: List (task lists + "No list" + "New list…") · Tags ("#q3
/// #strategy", add / remove) · Linked note (searchable note picker).
/// Why: all three are form edits saved with the task; only "New list…"
/// writes right away because lists are shared between tasks.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_editor_controller.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_row.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/note_link_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/tags_sheet.dart';

/// Option value of "New list…" in the list sheet.
const String _newList = '\u0000new-list';

class TaskOrganiseCard extends ConsumerWidget {
  const TaskOrganiseCard({required this.args, required this.task, super.key});

  final TaskEditorArgs args;
  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(taskListsProvider).valueOrNull ?? const <Folder>[];
    final form = ref.read(taskEditorControllerProvider(args).notifier);
    final list = lists.where((f) => f.id == task.listId).firstOrNull;
    final listName = list?.name ?? task.listName;

    Future<void> pickList() async {
      final picked = await showOptionSheet<String?>(
        context,
        title: tr('List'),
        options: [
          OptionItem<String?>(
            value: null,
            label: tr('No list'),
            icon: FontAwesomeIcons.folderOpen,
            colors: ActionTints.lock,
          ),
          for (final f in lists)
            OptionItem<String?>(
              value: f.id,
              label: f.name,
              icon: TaskStyle.listIcon(f),
              colors: TaskStyle.labelColors(f.name, hex: f.colorHex),
            ),
          OptionItem<String?>(
            value: _newList,
            label: tr('New list…'),
            icon: FontAwesomeIcons.plus,
            colors: ModuleStyle.notes.colors,
          ),
        ],
        selected: task.listId,
      );
      if (picked == null || !context.mounted) return;
      if (picked.value == _newList) {
        final name = await showTextInputSheet(
          context,
          title: tr('New list'),
          hint: tr('List name'),
          confirmLabel: tr('Create list'),
        );
        if (name != null) await form.createList(name);
        return;
      }
      final id = picked.value;
      form.setList(id, lists.where((f) => f.id == id).firstOrNull?.name);
    }

    Future<void> pickTags() async {
      final names = await showTagsSheet(
        context,
        current: [for (final t in task.tags) t.name],
      );
      if (names != null) form.setTags(names);
    }

    Future<void> pickNote() async {
      final picked = await showNoteLinkSheet(
        context,
        currentId: task.linkedNoteId,
      );
      if (picked == null) return;
      form.setLinkedNote(picked.value?.id, picked.value?.title);
    }

    return FFGroupedList(
      children: [
        TaskEditorRow(
          icon: FontAwesomeIcons.solidFolder,
          colors: TagPalette.design,
          title: tr('List'),
          value: task.listId == null ? tr('None') : (listName ?? tr('List')),
          onTap: pickList,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.tag,
          colors: TagPalette.travel,
          title: tr('Tags'),
          value: task.tags.isEmpty
              ? tr('None')
              : task.tags.map((t) => '#${t.name}').join(' '),
          onTap: pickTags,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.link,
          colors: ModuleStyle.notes.colors,
          title: tr('Linked note'),
          value: task.linkedNoteId == null
              ? tr('None')
              : (task.linkedNoteTitle ?? tr('Note')),
          onTap: pickNote,
        ),
      ],
    );
  }
}
