/// ============================================================
/// TASK MAPPER — tasks / subtasks rows ⇄ TaskItem entities
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/tasks_dao.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

abstract final class TaskMapper {
  static Subtask subtask(SubtaskRow r) =>
      Subtask(id: r.id, title: r.title, done: r.done, sortOrder: r.sortOrder);

  static TaskItem fromRow(
    TaskListRow r, {
    List<SubtaskRow> subtasks = const [],
    List<Tag> tags = const [],
  }) {
    final t = r.row;
    return TaskItem(
      id: t.id,
      title: t.title,
      notes: t.notes,
      dueDate: t.dueDate == null ? null : DateUtilsX.fromStoredDay(t.dueDate!),
      dueTimeMinutes: t.dueTimeMinutes,
      priority: TaskPriority.fromValue(t.priority),
      repeatRule: (t.repeatRule?.isEmpty ?? true) ? null : t.repeatRule,
      remindOffsetMinutes: t.remindOffsetMinutes,
      reminderId: t.reminderId,
      linkedNoteId: t.linkedNoteId,
      linkedNoteTitle: t.linkedNoteId == null ? null : r.linkedNoteTitle,
      listId: t.folderId,
      listName: r.listName,
      tags: tags,
      subtasks: List.unmodifiable(subtasks.map(subtask)),
      completedAt: t.completedAt,
      isPinned: t.isPinned,
      isFavorite: t.isFavorite,
      colorHex: t.colorHex,
      sortOrder: t.sortOrder,
      boardStatus: t.boardStatus,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      archivedAt: t.archivedAt,
      deletedAt: t.deletedAt,
    );
  }

  /// Editable columns (not id / created / sync / lifecycle / reminderId /
  /// sortOrder).
  static TasksCompanion contentCompanion(TaskItem t) => TasksCompanion(
    title: Value(t.title.trim()),
    notes: Value(t.notes),
    dueDate: Value(
      t.dueDate == null ? null : DateUtilsX.toStoredDay(t.dueDate!),
    ),
    dueTimeMinutes: Value(t.dueDate == null ? null : t.dueTimeMinutes),
    priority: Value(t.priority.index),
    repeatRule: Value(t.repeatRule),
    remindOffsetMinutes: Value(t.remindOffsetMinutes),
    linkedNoteId: Value(t.linkedNoteId),
    folderId: Value(t.listId),
    completedAt: Value(t.completedAt),
    isPinned: Value(t.isPinned),
    isFavorite: Value(t.isFavorite),
    colorHex: Value(t.colorHex),
    boardStatus: Value(t.boardStatus),
  );
}
