/// ============================================================
/// TASK EDITOR CONTROLLER — form logic of screen 11 (new / edit task)
/// ============================================================
///
/// What: loads the task (or builds a prefilled draft for `/tasks/new`),
/// applies every edit to an in-memory [TaskEditorState] and writes it all
/// at once on [save] through `TasksRepository.save` — which diffs the
/// subtasks, sets tags by name and keeps the linked "Remind me" reminder
/// (and so its notification) in sync.
/// Why: Cancel must be able to throw edits away, and widgets stay free of
/// business rules (e.g. a reminder needs a date, a repeat needs an anchor).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Thrown by the editor when `/tasks/:id` no longer exists.
class TaskNotFoundException implements Exception {
  const TaskNotFoundException();

  @override
  String toString() => 'This task no longer exists';
}

class TaskEditorController
    extends AutoDisposeFamilyAsyncNotifier<TaskEditorState, TaskEditorArgs> {
  var _nextKey = 0;

  @override
  Future<TaskEditorState> build(TaskEditorArgs arg) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    if (arg.isNew) return _newDraft(arg);
    final task = await ref.read(tasksRepositoryProvider).getTask(arg.id!);
    if (task == null) throw const TaskNotFoundException();
    return TaskEditorState(
      original: task,
      draft: task,
      subtasks: [
        for (final s in task.subtasks) EditorSubtask(key: s.id, subtask: s),
      ],
    );
  }

  Future<TaskEditorState> _newDraft(TaskEditorArgs arg) async {
    final now = ref.read(clockProvider).now();
    DateTime? date;
    final dateKey = arg.date;
    if (dateKey != null) {
      try {
        date = DateUtilsX.parseDayKey(dateKey);
      } on FormatException {
        date = null;
      }
    }
    final rrule = RecurrenceRule.tryParse(arg.repeatRule)?.toRRule();
    // A repeat needs an anchor day; a time without a day means today.
    if (date == null && (rrule != null || arg.time != null)) {
      date = DateUtilsX.dateOnly(now);
    }
    final time = arg.time;
    final listId = await _defaultListId();
    var task = TaskItem.draft(
      now: now,
      title: arg.title ?? '',
      dueDate: date,
      dueTimeMinutes: time != null && time >= 0 && time < 1440 ? time : null,
      priority: TaskPriority.fromValue(arg.priority ?? 0),
      listId: listId,
      tags: [if (arg.tag != null) Tag(id: '', name: arg.tag!)],
    );
    if (rrule != null) task = task.copyWith(repeatRule: rrule);
    return TaskEditorState(original: task, draft: task, subtasks: const []);
  }

  /// Settings › Tasks default list, if it still exists.
  Future<String?> _defaultListId() async {
    final id = ref.read(settingsProvider).tasksDefaultListId;
    if (id == null) return null;
    final folder = await ref.read(foldersRepositoryProvider).getFolder(id);
    return folder?.id;
  }

  TaskEditorState? get _form => state.valueOrNull;

  void _update(TaskEditorState Function(TaskEditorState s) change) {
    final s = _form;
    if (s == null) return;
    state = AsyncData(change(s));
  }

  void _draft(TaskItem Function(TaskItem t) change) =>
      _update((s) => s.copyWith(draft: change(s.draft)));

  // ───────────────────────── Fields ─────────────────────────

  void setTitle(String title) => _draft((t) => t.copyWith(title: title));

  void setNotes(String notes) => _draft((t) => t.copyWith(notes: notes));

  /// New due day; null clears date, time, repeat and reminder (they all
  /// need a day).
  void setDate(DateTime? day) => _draft(
    (t) => day == null
        ? t.copyWith(
            clearDueDate: true,
            clearRepeatRule: true,
            clearRemindOffset: true,
          )
        : t.copyWith(dueDate: DateUtilsX.dateOnly(day)),
  );

  /// Minutes after midnight; null = all day. Picking a time on an undated
  /// task schedules it for [today].
  void setTime(int? minutes, {required DateTime today}) => _draft(
    (t) => minutes == null
        ? t.copyWith(clearDueTime: true)
        : t.copyWith(
            dueDate: t.dueDate ?? DateUtilsX.dateOnly(today),
            dueTimeMinutes: minutes,
          ),
  );

  /// RRULE text; null = does not repeat. A repeat anchors on [today] when
  /// the task has no date yet.
  void setRepeat(String? rrule, {required DateTime today}) => _draft(
    (t) => rrule == null
        ? t.copyWith(clearRepeatRule: true)
        : t.copyWith(
            repeatRule: rrule,
            dueDate: t.dueDate ?? DateUtilsX.dateOnly(today),
          ),
  );

  /// Minutes before the task; null = no reminder. Needs a day, so an
  /// undated task is scheduled for [today]. Choosing a reminder asks for
  /// notification permission the first time.
  void setRemind(int? minutes, {required DateTime today}) {
    _draft(
      (t) => minutes == null
          ? t.copyWith(clearRemindOffset: true)
          : t.copyWith(
              remindOffsetMinutes: minutes,
              dueDate: t.dueDate ?? DateUtilsX.dateOnly(today),
            ),
    );
    if (minutes != null) unawaited(_askNotificationPermission());
  }

  /// Set when the editor closed (the permission prompt is fire-and-forget
  /// and must not touch a disposed ref).
  bool _disposed = false;

  Future<void> _askNotificationPermission() async {
    try {
      final now = await ref.read(notificationPermissionProvider.future);
      if (!_disposed && now == NotificationPermission.notDetermined) {
        await requestNotificationPermission(ref);
      }
    } catch (_) {
      // Also covers the editor closing mid-request (StateError).
      // The reminder is still saved; Settings › Notifications explains
      // how to enable alerts.
    }
  }

  void setPriority(TaskPriority p) => _draft((t) => t.copyWith(priority: p));

  /// Task list (folder); null id = no list.
  void setList(String? id, String? name) => _draft(
    (t) => id == null
        ? t.copyWith(clearList: true)
        : t.copyWith(listId: id, listName: name),
  );

  /// Creates a task list called [name] (written right away — lists are
  /// shared, not part of this task) and selects it.
  Future<void> createList(String name) async {
    final id = await ref
        .read(foldersRepositoryProvider)
        .create(ItemType.task, name.trim());
    setList(id, name.trim());
  }

  /// Replaces the tags by [names]; tags already on the task are kept as
  /// they are (so re-picking the same set is not an edit).
  void setTags(List<String> names) => _draft((t) {
    final tags = <Tag>[];
    for (final raw in names) {
      final name = raw.replaceAll('#', '').trim();
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (tags.any((x) => x.name.toLowerCase() == lower)) continue;
      tags.add(
        t.tags.firstWhere(
          (x) => x.name.toLowerCase() == lower,
          orElse: () => Tag(id: '', name: name),
        ),
      );
    }
    return t.copyWith(tags: tags);
  });

  /// Links a note; null id removes the link.
  void setLinkedNote(String? id, String? title) => _draft(
    (t) => id == null
        ? t.copyWith(clearLinkedNote: true)
        : t.copyWith(linkedNoteId: id, linkedNoteTitle: title),
  );

  // ───────────────────────── Subtasks ─────────────────────────

  /// Adds an empty subtask after [afterKey] (or at the end). Returns its key
  /// so the row can take focus.
  String addSubtask({String? afterKey, String title = ''}) {
    final key = 'new-${_nextKey++}';
    _update((s) {
      final list = [...s.subtasks];
      final at = afterKey == null
          ? list.length
          : list.indexWhere((e) => e.key == afterKey) + 1;
      final row = EditorSubtask(key: key, subtask: Subtask.draft(title));
      list.insert(at <= 0 || at > list.length ? list.length : at, row);
      return s.copyWith(subtasks: list);
    });
    return key;
  }

  void toggleSubtask(String key) =>
      _editSubtask(key, (e) => e.copyWith(done: !e.done));

  void renameSubtask(String key, String title) =>
      _editSubtask(key, (e) => e.copyWith(title: title));

  void _editSubtask(String key, EditorSubtask Function(EditorSubtask) change) =>
      _update(
        (s) => s.copyWith(
          subtasks: [for (final e in s.subtasks) e.key == key ? change(e) : e],
        ),
      );

  /// Moves a row to its final position [newIndex] (as `onReorderItem`
  /// reports it — already adjusted for the removed row).
  void moveSubtask(int oldIndex, int newIndex) => _update((s) {
    final list = [...s.subtasks];
    if (oldIndex < 0 || oldIndex >= list.length) return s;
    final row = list.removeAt(oldIndex);
    final to = newIndex.clamp(0, list.length);
    list.insert(to, row);
    return s.copyWith(subtasks: list);
  });

  /// Removes a row; returns its index (for Undo via [restoreSubtask]).
  int removeSubtask(String key) {
    final index = _form?.subtasks.indexWhere((e) => e.key == key) ?? -1;
    if (index < 0) return index;
    _update((s) => s.copyWith(subtasks: [...s.subtasks]..removeAt(index)));
    return index;
  }

  void restoreSubtask(int index, EditorSubtask row) => _update((s) {
    final list = [...s.subtasks];
    list.insert(index.clamp(0, list.length), row);
    return s.copyWith(subtasks: list);
  });

  // ───────────────────────── Save ─────────────────────────

  /// Writes the task (create or update). Returns its id, or null when the
  /// form is invalid / already saving. When the task has (or had) a
  /// "Remind me", the OS schedule is updated before this returns, so the
  /// reminder fires even if the app is closed right after saving.
  Future<String?> save() async {
    final s = _form;
    if (s == null || !s.canSave) return null;
    state = AsyncData(s.copyWith(saving: true));
    try {
      final task = s.toTask();
      final id = await ref.read(tasksRepositoryProvider).save(task);
      if (task.remindOffsetMinutes != null || task.reminderId != null) {
        await flushNotifications(ref);
      }
      return id;
    } finally {
      final now = _form;
      if (now != null) state = AsyncData(now.copyWith(saving: false));
    }
  }
}

/// The editor form for one route ([TaskEditorArgs]).
final taskEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TaskEditorController, TaskEditorState, TaskEditorArgs>(
      TaskEditorController.new,
    );
