/// ============================================================
/// TASKS FILTER — what the Tasks list (screen 10) is showing
/// ============================================================
///
/// What: the selected smart list (chips "Today" / "Upcoming" / "All" and
/// the four stat tiles) or task list (folder chips "Work", "Personal"),
/// plus the sort / view modes, and the mapping to a repository
/// [TasksQuery].
/// Why: chips, stat tiles, the board view and tests all need the same
/// translation from "what the user tapped" to "what to query", so it is a
/// pure value type instead of logic inside widgets.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';

/// Smart lists: chips and stat tiles.
enum TaskSmartList {
  today,
  upcoming,
  overdue,
  completed,
  all;

  /// Chip / tile text in the active language.
  String get label => switch (this) {
    TaskSmartList.today => tr('Today'),
    TaskSmartList.upcoming => tr('Upcoming'),
    TaskSmartList.overdue => tr('Overdue'),
    TaskSmartList.completed => tr('Done'),
    TaskSmartList.all => tr('All'),
  };

  TasksScope get scope => switch (this) {
    TaskSmartList.today => TasksScope.today,
    TaskSmartList.upcoming => TasksScope.upcoming,
    TaskSmartList.overdue => TasksScope.overdue,
    TaskSmartList.completed => TasksScope.completed,
    TaskSmartList.all => TasksScope.all,
  };
}

/// Smart order (due date, priority) or manual drag-to-reorder order.
enum TaskSort { smart, manual }

/// Rows (sections) or the To do / Doing / Done board.
enum TaskView { list, board }

/// Either a smart list or a task list (folder) id.
@immutable
class TaskFilter {
  const TaskFilter.smart(TaskSmartList this.smart) : listId = null;

  const TaskFilter.list(String this.listId) : smart = null;

  static const TaskFilter today = TaskFilter.smart(TaskSmartList.today);

  final TaskSmartList? smart;
  final String? listId;

  bool get isList => listId != null;

  /// Builds the repository query relative to [day].
  TasksQuery toQuery({
    required DateTime day,
    String text = '',
    String? tagId,
  }) => TasksQuery(
    scope: smart?.scope ?? TasksScope.all,
    listId: listId,
    tagId: tagId,
    text: text.trim(),
    day: day,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskFilter && other.smart == smart && other.listId == listId;

  @override
  int get hashCode => Object.hash(smart, listId);

  @override
  String toString() => 'TaskFilter(${smart?.name ?? 'list:$listId'})';
}
