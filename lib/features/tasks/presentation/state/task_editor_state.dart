/// ============================================================
/// TASK EDITOR STATE — the form behind screen 11 (new / edit task)
/// ============================================================
///
/// What:
///   * [TaskEditorArgs] — which task to open (`/tasks/:id`) or the prefill
///     of a new one (`/tasks/new?title&date&time&priority&tag&rrule`).
///   * [EditorSubtask] — a subtask row with a stable local [key] (new rows
///     have no id yet, but reorder / focus / swipe need an identity).
///   * [TaskEditorState] — the task as loaded ([original]) plus the edited
///     [draft]; [toTask] is what Save writes, [isDirty] drives the discard
///     confirmation.
/// Why: everything the editor changes stays in memory until Save, so
/// Cancel can throw it away; plain immutable classes keep this pure Dart.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

/// Route arguments of the task editor. [id] null = new task; the other
/// fields are the raw query parameters of `/tasks/new`.
@immutable
class TaskEditorArgs {
  const TaskEditorArgs({
    this.id,
    this.title,
    this.date,
    this.time,
    this.priority,
    this.tag,
    this.repeatRule,
  });

  /// Reads `/tasks/:id` (+ query) — `new` opens an empty editor.
  factory TaskEditorArgs.fromRoute(String id, Map<String, String> query) {
    if (id != 'new') return TaskEditorArgs(id: id);
    String? text(String key) {
      final v = query[key]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return TaskEditorArgs(
      title: text('title'),
      date: text('date'),
      time: int.tryParse(query['time'] ?? ''),
      priority: int.tryParse(query['priority'] ?? ''),
      tag: text('tag'),
      repeatRule: text('rrule'),
    );
  }

  /// Existing task id; null for a new task.
  final String? id;
  final String? title;

  /// `yyyy-MM-dd`.
  final String? date;

  /// Minutes after midnight.
  final int? time;

  /// [TaskPriority] index (0 none … 3 high).
  final int? priority;
  final String? tag;
  final String? repeatRule;

  bool get isNew => id == null;

  @override
  bool operator ==(Object other) =>
      other is TaskEditorArgs &&
      other.id == id &&
      other.title == title &&
      other.date == date &&
      other.time == time &&
      other.priority == priority &&
      other.tag == tag &&
      other.repeatRule == repeatRule;

  @override
  int get hashCode =>
      Object.hash(id, title, date, time, priority, tag, repeatRule);
}

/// One subtask row of the editor.
@immutable
class EditorSubtask {
  const EditorSubtask({required this.key, required this.subtask});

  /// Stable local identity (the id for stored subtasks).
  final String key;
  final Subtask subtask;

  String get title => subtask.title;
  bool get done => subtask.done;

  EditorSubtask copyWith({String? title, bool? done}) => EditorSubtask(
    key: key,
    subtask: subtask.copyWith(title: title, done: done),
  );

  @override
  bool operator ==(Object other) =>
      other is EditorSubtask && other.key == key && other.subtask == subtask;

  @override
  int get hashCode => Object.hash(key, subtask);
}

@immutable
class TaskEditorState {
  const TaskEditorState({
    required this.original,
    required this.draft,
    required this.subtasks,
    this.saving = false,
  });

  /// The task as opened (the prefilled draft for a new task).
  final TaskItem original;

  /// The edited task; its `subtasks` are ignored in favour of [subtasks].
  final TaskItem draft;
  final List<EditorSubtask> subtasks;

  /// A save is in flight (Save shows as disabled).
  final bool saving;

  bool get isNew => original.isNew;

  /// Title required (validation).
  bool get canSave => draft.title.trim().isNotEmpty && !saving;

  int get subtaskDone => subtasks.where((s) => s.done).length;

  /// What Save writes: trimmed title, rows without a title dropped.
  TaskItem toTask() => draft.copyWith(
    title: draft.title.trim(),
    notes: draft.notes.trim(),
    subtasks: [
      for (final s in subtasks)
        if (s.title.trim().isNotEmpty)
          s.subtask.copyWith(title: s.title.trim()),
    ],
  );

  /// True when Save would change something (Cancel asks to discard).
  bool get isDirty => toTask() != _baseline;

  TaskItem get _baseline => original.copyWith(
    title: original.title.trim(),
    notes: original.notes.trim(),
  );

  TaskEditorState copyWith({
    TaskItem? draft,
    List<EditorSubtask>? subtasks,
    bool? saving,
  }) => TaskEditorState(
    original: original,
    draft: draft ?? this.draft,
    subtasks: subtasks ?? this.subtasks,
    saving: saving ?? this.saving,
  );

  static const _subsEq = ListEquality<EditorSubtask>();

  @override
  bool operator ==(Object other) =>
      other is TaskEditorState &&
      other.original == original &&
      other.draft == draft &&
      _subsEq.equals(other.subtasks, subtasks) &&
      other.saving == saving;

  @override
  int get hashCode =>
      Object.hash(original, draft, _subsEq.hash(subtasks), saving);
}
