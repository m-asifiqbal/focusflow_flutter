/// ============================================================
/// TASKS LIST PROVIDERS — live state of the Tasks list (screen 10)
/// ============================================================
///
/// What: the user's choices (filter chip / stat tile, search text, tag
/// filter, sort, view, collapsed sections) as small Notifiers, and the
/// live data derived from them (sections, stats, task lists) as
/// StreamProviders over the TasksRepository / FoldersRepository.
/// Why: CLAUDE.md rule 5 — UI → providers → repositories; every list is a
/// stream so edits from the editor, Quick Add or sync appear instantly.
/// Sort and view persist per device in SharedPreferences (they are view
/// preferences, not synced settings); backups carry them with the settings
/// (BackedUpPreferences).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/entities/task_sections.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

// ───────────────────────────── User choices ─────────────────────────────

/// Selected chip / stat tile (defaults to Today).
class TaskFilterController extends AutoDisposeNotifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.today;

  void select(TaskFilter filter) => state = filter;
}

final taskFilterProvider =
    NotifierProvider.autoDispose<TaskFilterController, TaskFilter>(
      TaskFilterController.new,
    );

/// Search field text.
class TaskSearchController extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  void set(String text) => state = text;
}

final taskSearchProvider =
    NotifierProvider.autoDispose<TaskSearchController, String>(
      TaskSearchController.new,
    );

/// Tag chosen in the search field's filter sheet (null = any tag).
class TaskTagFilterController extends AutoDisposeNotifier<Tag?> {
  @override
  Tag? build() => null;

  void set(Tag? tag) => state = tag;
}

final taskTagFilterProvider =
    NotifierProvider.autoDispose<TaskTagFilterController, Tag?>(
      TaskTagFilterController.new,
    );

/// A device-local enum preference stored under [key].
abstract class _EnumPref<T extends Enum> extends Notifier<T> {
  String get key;
  List<T> get values;
  T get fallback;

  @override
  T build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    return values.firstWhere((v) => v.name == raw, orElse: () => fallback);
  }

  Future<void> set(T value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setString(key, value.name);
  }
}

/// Smart (due date · priority) or manual (drag-to-reorder) order.
class TaskSortController extends _EnumPref<TaskSort> {
  @override
  String get key => BackedUpPreferences.tasksSort;
  @override
  List<TaskSort> get values => TaskSort.values;
  @override
  TaskSort get fallback => TaskSort.smart;
}

final taskSortProvider = NotifierProvider<TaskSortController, TaskSort>(
  TaskSortController.new,
);

/// List (sections) or board (To do / Doing / Done).
class TaskViewController extends _EnumPref<TaskView> {
  @override
  String get key => BackedUpPreferences.tasksView;
  @override
  List<TaskView> get values => TaskView.values;
  @override
  TaskView get fallback => TaskView.list;
}

final taskViewProvider = NotifierProvider<TaskViewController, TaskView>(
  TaskViewController.new,
);

/// Section keys the user collapsed ("completed").
class CollapsedTaskSections extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String key) {
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    state = next;
  }
}

final collapsedTaskSectionsProvider =
    NotifierProvider.autoDispose<CollapsedTaskSections, Set<String>>(
      CollapsedTaskSections.new,
    );

// ───────────────────────────── Live data ─────────────────────────────

/// The sections of the current filter (OVERDUE / TODAY / UPCOMING /
/// NO DATE / COMPLETED), honouring "Show completed" (Settings › Tasks).
final taskSectionsProvider = StreamProvider.autoDispose<TaskSections>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final query = filter.toQuery(
    day: ref.watch(todayProvider),
    text: ref.watch(taskSearchProvider),
    tagId: ref.watch(taskTagFilterProvider)?.id,
  );
  final manual = ref.watch(taskSortProvider) == TaskSort.manual;
  final showCompleted =
      ref.watch(settingsProvider.select((s) => s.tasksShowCompleted)) ||
      filter.smart == TaskSmartList.completed;
  return ref
      .watch(tasksRepositoryProvider)
      .watchSections(query, manual: manual)
      .map(
        (s) => showCompleted
            ? s
            : TaskSections(
                overdue: s.overdue,
                today: s.today,
                upcoming: s.upcoming,
                noDate: s.noDate,
              ),
      );
});

/// Flat task list of the current filter (board view).
final taskBoardTasksProvider = StreamProvider.autoDispose<List<TaskItem>>((
  ref,
) {
  final query = ref
      .watch(taskFilterProvider)
      .toQuery(
        day: ref.watch(todayProvider),
        text: ref.watch(taskSearchProvider),
        tagId: ref.watch(taskTagFilterProvider)?.id,
      );
  return ref.watch(tasksRepositoryProvider).watchTasks(query);
});

/// Stat tiles + header counts, relative to today.
final taskStatsProvider = StreamProvider.autoDispose<TaskStats>(
  (ref) => ref
      .watch(tasksRepositoryProvider)
      .watchStats(ref.watch(minuteClockProvider)),
);

/// Task lists (folders of the task module) for chips and pickers.
final taskListsProvider = StreamProvider.autoDispose<List<Folder>>(
  (ref) => ref.watch(foldersRepositoryProvider).watchFolders(ItemType.task),
);

/// Every tag (most used first) for the filter / tag pickers.
final allTagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsRepositoryProvider).watchTags(),
);

/// Every task the list currently shows, in display order ("Select all",
/// bulk complete / reschedule).
final visibleTasksProvider = Provider.autoDispose<List<TaskItem>>((ref) {
  final s = ref.watch(taskSectionsProvider).valueOrNull;
  if (s == null) return const [];
  return [for (final (_, tasks) in s.nonEmpty) ...tasks];
});
