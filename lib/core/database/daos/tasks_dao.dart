/// ============================================================
/// TASKS DAO — row-level queries for `tasks` + `subtasks`
/// ============================================================
///
/// [queryTasks] takes a WHERE fragment (alias `t`) composed by the
/// repository from a TasksQuery; it always joins the list (folder) name and
/// the linked note's title. Subtasks are loaded in one query for a whole
/// list ([subtasksByTask]) to avoid N+1 reads.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';
import 'package:focusflow/core/utils/date_utils.dart';

part 'tasks_dao.g.dart';

/// A task row plus joined display columns.
typedef TaskListRow = ({
  TaskRow row,
  String? listName,
  String? linkedNoteTitle,
});

@DriftAccessor(tables: [Tasks, Subtasks, Folders, Notes, ItemTags, Tags])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.attachedDatabase);

  static const _select =
      'SELECT t.*, f.name AS list_name, '
      'CASE WHEN n.deleted_at IS NULL THEN n.title ELSE NULL END AS linked_note_title '
      'FROM tasks t '
      'LEFT JOIN folders f ON f.id = t.folder_id AND f.deleted_at IS NULL '
      'LEFT JOIN notes n ON n.id = t.linked_note_id';

  TaskListRow _map(QueryRow r) => (
    row: tasks.map(r.data),
    listName: r.readNullable<String>('list_name'),
    linkedNoteTitle: r.readNullable<String>('linked_note_title'),
  );

  /// Tasks matching [where] (SQL over alias `t`, bound [variables]).
  Selectable<TaskListRow> queryTasks({
    required String where,
    List<Variable> variables = const [],
    String orderBy = 't.sort_order ASC',
    int? limit,
  }) => customSelect(
    '$_select WHERE $where ORDER BY $orderBy'
    '${limit == null ? '' : ' LIMIT $limit'}',
    variables: variables,
    readsFrom: {tasks, folders, notes, itemTags, subtasks},
  ).map(_map);

  /// WHERE fragment (alias `t`) for active tasks whose `completed_at`
  /// instant is in [?1, ?2) — bind local bounds (Insights).
  String get completedInRangeWhere =>
      '${activeSql('t')} AND t.completed_at IS NOT NULL '
      'AND t.completed_at >= ? AND t.completed_at < ?';

  Selectable<TaskListRow> taskById(String id) => customSelect(
    '$_select WHERE t.id = ?',
    variables: [Variable.withString(id)],
    readsFrom: {tasks, folders, notes},
  ).map(_map);

  Future<TaskRow?> rowById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TaskRow>> rowsByIds(Iterable<String> ids) =>
      (select(tasks)..where((t) => t.id.isIn(ids))).get();

  Future<void> insertTask(TasksCompanion task) => into(tasks).insert(task);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updateTask(String id, TasksCompanion changes, WriteStamp stamp) =>
      (update(
        tasks,
      )..where((t) => t.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<double?> maxSortOrder() {
    final max = tasks.sortOrder.max();
    return (selectOnly(
      tasks,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }

  /// Open / done counts relative to the local day [dayStart, dayEnd).
  /// `due_date` is a floating day (?1/?2, DateUtilsX.toStoredDay);
  /// `completed_at` is an instant (?3/?4, local bounds).
  Selectable<QueryRow> stats(
    DateTime dayStart,
    DateTime dayEnd,
  ) => customSelect(
    'SELECT '
    'COALESCE(SUM(CASE WHEN completed_at IS NULL AND due_date >= ?1 AND due_date < ?2 THEN 1 ELSE 0 END), 0) AS today, '
    'COALESCE(SUM(CASE WHEN completed_at IS NULL AND due_date < ?1 THEN 1 ELSE 0 END), 0) AS overdue, '
    'COALESCE(SUM(CASE WHEN completed_at IS NULL AND due_date >= ?2 THEN 1 ELSE 0 END), 0) AS upcoming, '
    'COALESCE(SUM(CASE WHEN completed_at IS NULL AND due_date IS NULL THEN 1 ELSE 0 END), 0) AS no_date, '
    'COALESCE(SUM(CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS done, '
    'COALESCE(SUM(CASE WHEN completed_at >= ?3 AND completed_at < ?4 THEN 1 ELSE 0 END), 0) AS done_today, '
    'COALESCE(SUM(CASE WHEN due_date >= ?1 AND due_date < ?2 THEN 1 ELSE 0 END), 0) AS due_today_all '
    'FROM tasks WHERE ${activeSql()}',
    variables: [
      Variable<DateTime>(DateUtilsX.toStoredDay(dayStart)),
      Variable<DateTime>(DateUtilsX.toStoredDay(dayEnd)),
      Variable<DateTime>(dayStart),
      Variable<DateTime>(dayEnd),
    ],
    readsFrom: {tasks},
  );

  // ───────────────────────────── Subtasks ─────────────────────────────

  /// Subtasks of [taskIds] (all tasks when null), keyed by task id, each
  /// list in sort order.
  Future<Map<String, List<SubtaskRow>>> subtasksByTask([
    Iterable<String>? taskIds,
  ]) async {
    final q = select(subtasks)
      ..orderBy([
        (s) => OrderingTerm.asc(s.sortOrder),
        (s) => OrderingTerm.asc(s.createdAt),
      ]);
    if (taskIds != null) q.where((s) => s.taskId.isIn(taskIds));
    final rows = await q.get();
    final result = <String, List<SubtaskRow>>{};
    for (final s in rows) {
      result.putIfAbsent(s.taskId, () => []).add(s);
    }
    return result;
  }

  Future<List<SubtaskRow>> subtasksOf(String taskId) async =>
      (await subtasksByTask([taskId]))[taskId] ?? const [];

  Future<SubtaskRow?> subtaskById(String id) =>
      (select(subtasks)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> insertSubtask(SubtasksCompanion row) =>
      into(subtasks).insert(row);

  Future<int> updateSubtask(String id, SubtasksCompanion changes) =>
      (update(subtasks)..where((s) => s.id.equals(id))).write(changes);

  Future<int> deleteSubtask(String id) =>
      (delete(subtasks)..where((s) => s.id.equals(id))).go();

  Future<int> deleteSubtasksOf(Iterable<String> taskIds) =>
      (delete(subtasks)..where((s) => s.taskId.isIn(taskIds))).go();

  /// How many subtasks of [taskId] are still open (a COUNT, not the rows).
  Future<int> openSubtaskCount(String taskId) {
    final count = subtasks.id.count();
    return (selectOnly(subtasks)
          ..addColumns([count])
          ..where(subtasks.taskId.equals(taskId) & subtasks.done.equals(false)))
        .map((r) => r.read(count) ?? 0)
        .getSingle();
  }

  Future<double?> maxSubtaskSortOrder(String taskId) {
    final max = subtasks.sortOrder.max();
    return (selectOnly(subtasks)
          ..addColumns([max])
          ..where(subtasks.taskId.equals(taskId)))
        .map((r) => r.read(max))
        .getSingle();
  }
}
