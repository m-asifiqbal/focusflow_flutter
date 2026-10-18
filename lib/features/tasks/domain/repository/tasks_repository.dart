/// ============================================================
/// TASKS REPOSITORY (contract)
/// ============================================================
///
/// Lists stream *active* tasks only (archived / deleted never appear).
/// [save] owns everything attached to a task: subtasks (diffed by id),
/// tags (by name) and the linked "Remind me" reminder — the editor does not
/// need to call the reminders repository itself.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/entities/task_sections.dart';

enum TasksScope {
  /// Every active task (open + completed).
  all,

  /// Open tasks due today or overdue + tasks completed today (the
  /// "Today" chip shows OVERDUE / TODAY / COMPLETED).
  today,

  /// Open tasks due after today.
  upcoming,

  /// Open tasks due before today.
  overdue,

  /// Completed tasks.
  completed,

  /// Open tasks without a due date.
  noDate,
}

@immutable
class TasksQuery {
  const TasksQuery({
    this.scope = TasksScope.all,
    this.listId,
    this.tagId,
    this.text = '',
    this.day,
    this.limit,
  });

  final TasksScope scope;

  /// Task list (folder) filter.
  final String? listId;
  final String? tagId;

  /// Full-text filter (title + notes, prefix match per word).
  final String text;

  /// Reference day for today / upcoming / overdue (default: today).
  final DateTime? day;
  final int? limit;

  TasksQuery copyWith({
    TasksScope? scope,
    String? listId,
    bool clearList = false,
    String? tagId,
    bool clearTag = false,
    String? text,
    DateTime? day,
  }) => TasksQuery(
    scope: scope ?? this.scope,
    listId: clearList ? null : (listId ?? this.listId),
    tagId: clearTag ? null : (tagId ?? this.tagId),
    text: text ?? this.text,
    day: day ?? this.day,
    limit: limit,
  );

  @override
  bool operator ==(Object other) =>
      other is TasksQuery &&
      other.scope == scope &&
      other.listId == listId &&
      other.tagId == tagId &&
      other.text == text &&
      other.day == day &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(scope, listId, tagId, text, day, limit);
}

/// Result of [TasksRepository.toggleComplete].
@immutable
class TaskCompletion {
  const TaskCompletion({
    required this.taskId,
    required this.completed,
    this.nextOccurrenceId,
    this.completedSubtaskIds = const [],
  });

  final String taskId;

  /// The task's new state.
  final bool completed;

  /// Id of the next occurrence spawned by completing a repeating task
  /// (pass it to `uncomplete(..., discardNextOccurrenceId:)` for Undo).
  final String? nextOccurrenceId;

  /// Subtasks this completion ticked (those that were still open):
  /// completing a task completes its subtasks. Pass them to
  /// `uncomplete(..., reopenSubtaskIds:)` for Undo, so a subtask the user
  /// had finished before stays finished.
  final List<String> completedSubtaskIds;
}

abstract interface class TasksRepository {
  /// Active tasks for a list scope, with subtasks, tags, list name and
  /// linked note title. Order: pinned, due date/time, priority, manual.
  Stream<List<TaskItem>> watchTasks(TasksQuery query);

  /// [watchTasks] grouped with [TaskSections.build] relative to
  /// `query.day` (default today). Set [manual] for drag-to-reorder order.
  Stream<TaskSections> watchSections(TasksQuery query, {bool manual = false});

  /// One task in any lifecycle state (null when gone).
  Stream<TaskItem?> watchTask(String id);
  Future<TaskItem?> getTask(String id);

  /// Creates ([TaskItem.isNew]) or updates a task: subtasks are diffed by
  /// id (new → inserted, missing → deleted, order = list order), tags are
  /// set by name, and the linked reminder is created / moved / removed
  /// from `remindOffsetMinutes` + due date. Returns the id.
  Future<String> save(TaskItem task);

  /// Completes an open task or reopens a completed one. Completing a
  /// repeating task also creates the next occurrence (an open copy due on
  /// the next date of its rule, subtasks reset) and moves the reminder to
  /// it.
  Future<TaskCompletion> toggleComplete(String id);

  /// Idempotent complete: completes [id] only if it is still open (same
  /// side effects as [toggleComplete]). When the task is already completed
  /// (e.g. on another screen or device) or gone, nothing is written and the
  /// result has `completed: false` — "this call did not complete it".
  Future<TaskCompletion> complete(String id);

  /// Reopens a task. [reopenSubtaskIds] (from [TaskCompletion]) are
  /// un-ticked again. [discardNextOccurrenceId] (from [TaskCompletion])
  /// permanently removes the spawned next occurrence — Undo of a repeat.
  Future<void> uncomplete(
    String id, {
    String? discardNextOccurrenceId,
    List<String> reopenSubtaskIds = const [],
  });

  /// Moves tasks to [date] (local day; time of day kept). Null clears the
  /// due date. Linked reminders follow.
  Future<void> reschedule(List<String> ids, DateTime? date);

  /// Manual order: place [id] between [afterId] (above) and [beforeId]
  /// (below); either may be null at the ends.
  Future<void> reorder(String id, {String? afterId, String? beforeId});

  Future<void> setPriority(String id, TaskPriority priority);

  /// Stat tiles relative to [now]'s day.
  Stream<TaskStats> watchStats(DateTime now);

  /// Active tasks due on [day] (open + completed) — Home / calendar agenda.
  Stream<List<TaskItem>> watchTasksForDay(DateTime day);

  /// Active tasks due in [from, to) — calendar month dots.
  Stream<List<TaskItem>> watchTasksInRange(DateTime from, DateTime to);

  /// Active tasks completed in [from, to) (`completedAt` is an instant;
  /// pass local bounds), oldest completion first — Insights.
  Stream<List<TaskItem>> watchCompletedInRange(DateTime from, DateTime to);

  // ───────────────────────── Subtasks ─────────────────────────
  /// Appends a subtask. Returns its id.
  Future<String> addSubtask(String taskId, String title);
  Future<void> toggleSubtask(String subtaskId);
  Future<void> renameSubtask(String subtaskId, String title);

  /// Persists the order of a task's subtasks ([orderedIds] = new order).
  Future<void> reorderSubtasks(String taskId, List<String> orderedIds);
  Future<void> deleteSubtask(String subtaskId);
}
