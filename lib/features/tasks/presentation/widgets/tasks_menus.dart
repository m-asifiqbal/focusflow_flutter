/// ============================================================
/// TASKS MENUS — the "⋯" menu and the tag filter of the Tasks list
/// ============================================================
///
/// What: [showTasksMoreMenu] (Select tasks · Sort manually / by due date ·
/// Show / Hide completed · New list) and [pickTaskTagFilter] (the sliders
/// button in the search field).
/// Why: menu choices only flip providers / settings or call repositories;
/// keeping them out of the screen keeps it short and readable.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_list_item.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The header's "⋯" menu.
Future<void> showTasksMoreMenu(BuildContext context, WidgetRef ref) {
  final sort = ref.read(taskSortProvider);
  final showCompleted = ref.read(settingsProvider).tasksShowCompleted;
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: tr('Tasks'),
        icon: FontAwesomeIcons.checkDouble,
        colors: TagPalette.work,
        meta: tr('View options'),
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.solidSquareCheck,
          label: tr('Select tasks'),
          colors: ModuleStyle.tasks.colors,
          onTap: () => ref
              .read(itemSelectionProvider(tasksSelectionScope).notifier)
              .start(),
        ),
        FFActionItem(
          icon: sort == TaskSort.smart
              ? FontAwesomeIcons.gripVertical
              : FontAwesomeIcons.arrowDownWideShort,
          label: sort == TaskSort.smart
              ? tr('Sort manually')
              : tr('Sort by due date'),
          colors: TagPalette.design,
          onTap: () => ref
              .read(taskSortProvider.notifier)
              .set(sort == TaskSort.smart ? TaskSort.manual : TaskSort.smart),
        ),
        FFActionItem(
          icon: showCompleted
              ? FontAwesomeIcons.eyeSlash
              : FontAwesomeIcons.eye,
          label: showCompleted ? tr('Hide completed') : tr('Show completed'),
          colors: ActionTints.lock,
          onTap: () => ref
              .read(settingsProvider.notifier)
              .update((s) => s.copyWith(tasksShowCompleted: !showCompleted)),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.folderPlus,
          label: tr('New list'),
          colors: TagPalette.ideas,
          onTap: () => _newList(context, ref),
        ),
      ],
    ),
  );
}

Future<void> _newList(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;
  final name = await showTextInputSheet(
    context,
    title: tr('New list'),
    hint: tr('List name'),
    confirmLabel: tr('Create'),
  );
  if (name == null) return;
  final id = await ref
      .read(foldersRepositoryProvider)
      .create(ItemType.task, name);
  ref.read(taskFilterProvider.notifier).select(TaskFilter.list(id));
}

/// The sliders button: filter by one tag (or any).
Future<void> pickTaskTagFilter(BuildContext context, WidgetRef ref) async {
  final tags = await ref.read(tagsRepositoryProvider).watchTags().first;
  if (!context.mounted) return;
  final current = ref.read(taskTagFilterProvider);
  final picked = await showOptionSheet<String?>(
    context,
    title: tr('Filter by tag'),
    subtitle: tags.isEmpty ? tr('No tags yet — add some in the editor') : null,
    options: [
      OptionItem(
        value: null,
        label: tr('Any tag'),
        icon: FontAwesomeIcons.tags,
        colors: ActionTints.lock,
      ),
      for (final Tag t in tags)
        OptionItem(
          value: t.id,
          label: '#${t.name}',
          dotColor: TaskStyle.labelColors(t.name, hex: t.colorHex).solid,
        ),
    ],
    selected: current?.id,
  );
  if (picked == null) return;
  final tag = tags.where((t) => t.id == picked.value).firstOrNull;
  ref.read(taskTagFilterProvider.notifier).set(tag);
}
