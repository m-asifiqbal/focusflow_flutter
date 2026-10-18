/// ============================================================
/// TASKS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Scope filters are SQL (index on deleted/archived/due_date); subtasks and
/// tags are loaded in one query each per list. Multi-row writes (save with
/// subtasks, repeat spawning, reminder sync) run in a transaction. The
/// linked "Remind me" reminder is kept in sync here through
/// [LinkedReminders] so every path (save, complete, reschedule, repeat)
/// moves it consistently.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/fts_query.dart';
import 'package:focusflow/core/database/daos/items_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/reminders_dao.dart';
import 'package:focusflow/core/database/daos/tasks_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/reminders/data/repository/linked_reminders.dart';
import 'package:focusflow/features/tasks/data/repository/task_mapper.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/entities/task_sections.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';

class TasksRepositoryImpl extends RepositoryBase implements TasksRepository {
  TasksRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = TasksDao(db),
       _org = OrganisationDao(db),
       _items = ItemsDao(db),
       _reminders = RemindersDao(db),
       _linked = LinkedReminders(db, newId),
       _tags = TagWriter(OrganisationDao(db), newId);

  final TasksDao _dao;
  final OrganisationDao _org;
  final ItemsDao _items;
  final RemindersDao _reminders;
  final LinkedReminders _linked;
  final TagWriter _tags;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.tasks,
    db.subtasks,
    db.folders,
    db.notes,
    db.itemTags,
    db.tags,
  };

  static const _smartOrder =
      't.is_pinned DESC, CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END, '
      't.due_date ASC, COALESCE(t.due_time_minutes, -1) ASC, '
      't.priority DESC, t.sort_order ASC';

  // ───────────────────────────── Reading ──────────────────────────────

  Future<List<TaskItem>> _load(
    String where,
    List<Variable> vars, {
    String orderBy = _smartOrder,
    int? limit,
  }) async {
    final rows = await _dao
        .queryTasks(
          where: where,
          variables: vars,
          orderBy: orderBy,
          limit: limit,
        )
        .get();
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.row.id).toList();
    final subs = await _dao.subtasksByTask(ids);
    final tags = await _org.tagsByItem(ItemType.task, itemIds: ids);
    return [
      for (final r in rows)
        TaskMapper.fromRow(
          r,
          subtasks: subs[r.row.id] ?? const [],
          tags: ItemMappers.tags(tags[r.row.id]),
        ),
    ];
  }

  ({String where, List<Variable> vars, String orderBy}) _queryParts(
    TasksQuery q,
  ) {
    final day = DateUtilsX.dateOnly(q.day ?? clock.now());
    final next = DateUtilsX.addDays(day, 1);
    // completed_at is a real instant (local bounds); due_date is a floating
    // day (DateUtilsX.toStoredDay bounds).
    final start = Variable<DateTime>(day);
    final end = Variable<DateTime>(next);
    final dueStart = Variable<DateTime>(DateUtilsX.toStoredDay(day));
    final dueEnd = Variable<DateTime>(DateUtilsX.toStoredDay(next));
    final where = <String>[activeSql('t')];
    final vars = <Variable>[];
    var orderBy = _smartOrder;
    switch (q.scope) {
      case TasksScope.all:
        break;
      case TasksScope.today:
        where.add(
          '((t.completed_at IS NULL AND t.due_date < ?) OR '
          '(t.completed_at >= ? AND t.completed_at < ?))',
        );
        vars.addAll([dueEnd, start, end]);
      case TasksScope.upcoming:
        where.add('t.completed_at IS NULL AND t.due_date >= ?');
        vars.add(dueEnd);
      case TasksScope.overdue:
        where.add('t.completed_at IS NULL AND t.due_date < ?');
        vars.add(dueStart);
      case TasksScope.completed:
        where.add('t.completed_at IS NOT NULL');
        orderBy = 't.completed_at DESC';
      case TasksScope.noDate:
        where.add('t.completed_at IS NULL AND t.due_date IS NULL');
    }
    if (q.listId != null) {
      where.add('t.folder_id = ?');
      vars.add(Variable.withString(q.listId!));
    }
    if (q.tagId != null) {
      where.add(
        "EXISTS (SELECT 1 FROM item_tags it WHERE it.item_type = 'task' "
        'AND it.item_id = t.id AND it.tag_id = ?)',
      );
      vars.add(Variable.withString(q.tagId!));
    }
    final match = FtsQuery.fromInput(q.text);
    if (match != null) {
      where.add(
        't.rowid IN (SELECT rowid FROM tasks_fts WHERE tasks_fts MATCH ?)',
      );
      vars.add(Variable.withString(match));
    }
    return (where: where.join(' AND '), vars: vars, orderBy: orderBy);
  }

  @override
  Stream<List<TaskItem>> watchTasks(TasksQuery query) =>
      db.watchComputed(_tables, () {
        final p = _queryParts(query);
        return _load(p.where, p.vars, orderBy: p.orderBy, limit: query.limit);
      });

  @override
  Stream<TaskSections> watchSections(TasksQuery query, {bool manual = false}) =>
      watchTasks(query).map(
        (tasks) =>
            TaskSections.build(tasks, query.day ?? clock.now(), manual: manual),
      );

  @override
  Stream<TaskItem?> watchTask(String id) =>
      db.watchComputed(_tables, () => getTask(id));

  @override
  Future<TaskItem?> getTask(String id) async {
    final list = await _load('t.id = ?', [Variable.withString(id)]);
    return list.isEmpty ? null : list.first;
  }

  @override
  Stream<TaskStats> watchStats(DateTime now) {
    final day = DateUtilsX.dateOnly(now);
    return _dao
        .stats(day, DateUtilsX.addDays(day, 1))
        .watchSingle()
        .map(
          (r) => TaskStats(
            today: r.read<int>('today'),
            overdue: r.read<int>('overdue'),
            upcoming: r.read<int>('upcoming'),
            done: r.read<int>('done'),
            noDate: r.read<int>('no_date'),
            doneToday: r.read<int>('done_today'),
            dueTodayTotal: r.read<int>('due_today_all'),
          ),
        )
        .distinct();
  }

  @override
  Stream<List<TaskItem>> watchTasksForDay(DateTime day) {
    final d = DateUtilsX.dateOnly(day);
    return watchTasksInRange(d, DateUtilsX.addDays(d, 1));
  }

  @override
  Stream<List<TaskItem>> watchTasksInRange(DateTime from, DateTime to) =>
      db.watchComputed(
        _tables,
        () =>
            _load('${activeSql('t')} AND t.due_date >= ? AND t.due_date < ?', [
              Variable<DateTime>(DateUtilsX.toStoredDay(from)),
              Variable<DateTime>(DateUtilsX.toStoredDay(to)),
            ]),
      );

  @override
  Stream<List<TaskItem>> watchCompletedInRange(DateTime from, DateTime to) =>
      db.watchComputed(
        _tables,
        () => _load(_dao.completedInRangeWhere, [
          Variable<DateTime>(from),
          Variable<DateTime>(to),
        ], orderBy: 't.completed_at ASC'),
      );

  // ───────────────────────────── Writing ──────────────────────────────

  @override
  Future<String> save(TaskItem task) => db.transaction(() async {
    final s = stamp();
    var id = task.id;
    final existing = id.isEmpty ? null : await _dao.rowById(id);
    final content = TaskMapper.contentCompanion(task);
    if (existing == null) {
      if (id.isEmpty) id = newId();
      await _dao.insertTask(
        content.copyWith(
          id: Value(id),
          createdAt: Value(s.now),
          updatedAt: Value(s.now),
          sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
          syncVersion: const Value(1),
          deviceId: Value(deviceId),
        ),
      );
    } else {
      await _dao.updateTask(id, content, s);
    }
    await _saveSubtasks(id, task.subtasks, s.now);
    await _tags.replaceTags(ItemType.task, id, task.tags.map((t) => t.name), s);
    // An edit that leaves the schedule alone keeps the reminder's time (it
    // may have been rescheduled / zone-aligned on its own).
    await _syncReminder(
      id,
      s,
      keepTime: existing != null && _sameSchedule(existing, content),
    );
    return id;
  });

  static bool _sameSchedule(TaskRow row, TasksCompanion next) {
    final a = row.dueDate, b = next.dueDate.value;
    final sameDay = a == null || b == null ? a == b : a.isAtSameMomentAs(b);
    return sameDay &&
        row.dueTimeMinutes == next.dueTimeMinutes.value &&
        row.remindOffsetMinutes == next.remindOffsetMinutes.value;
  }

  /// Diffs [subtasks] against the stored ones (order = list order).
  Future<void> _saveSubtasks(
    String taskId,
    List<Subtask> subtasks,
    DateTime now,
  ) async {
    final stored = {for (final s in await _dao.subtasksOf(taskId)) s.id: s};
    final keep = <String>{};
    for (var i = 0; i < subtasks.length; i++) {
      final sub = subtasks[i];
      final order = i.toDouble();
      final old = sub.isNew ? null : stored[sub.id];
      if (old == null) {
        await _dao.insertSubtask(
          SubtasksCompanion.insert(
            id: sub.isNew ? newId() : sub.id,
            taskId: taskId,
            title: Value(sub.title.trim()),
            done: Value(sub.done),
            sortOrder: Value(order),
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        keep.add(old.id);
        if (old.title != sub.title.trim() ||
            old.done != sub.done ||
            old.sortOrder != order) {
          await _dao.updateSubtask(
            old.id,
            SubtasksCompanion(
              title: Value(sub.title.trim()),
              done: Value(sub.done),
              sortOrder: Value(order),
              updatedAt: Value(now),
            ),
          );
        }
      }
    }
    for (final id in stored.keys) {
      if (!keep.contains(id)) await _dao.deleteSubtask(id);
    }
  }

  /// Makes the task's own "Remind me" reminder match its current state.
  /// [keepTime]: the task's schedule did not change, so an existing open
  /// reminder keeps its trigger time (a missed reminder the user
  /// rescheduled must not snap back on the next unrelated task save); only
  /// its title follows the task.
  Future<void> _syncReminder(
    String taskId,
    WriteStamp s, {
    bool keepTime = false,
  }) async {
    final row = await _dao.rowById(taskId);
    if (row == null) return;
    final task = TaskMapper.fromRow((
      row: row,
      listName: null,
      linkedNoteTitle: null,
    ));
    final link = task.ref;
    final at = task.reminderAt;
    if (at == null) {
      if (task.reminderId != null) {
        await _linked.remove(link, reminderId: task.reminderId, stamp: s);
      }
      return;
    }
    final current = task.reminderId == null
        ? null
        : await _reminders.rowById(task.reminderId!);
    if (current != null && LinkedReminders.isInactive(current)) {
      // The user archived / trashed this task's reminder: respect that
      // instead of reviving it on the next save. "Remind me" turns off and
      // the reminder stays in Archive / Recently Deleted.
      await _items.updateItems(
        ItemType.task,
        [taskId],
        {
          'reminder_id': const Variable<String>(null),
          'remind_offset_minutes': const Variable<int>(null),
        },
        s,
      );
      return;
    }
    if (task.isCompleted) {
      if (current != null && current.completedAt == null) {
        await _linked.setDone(current.id, done: true, stamp: s);
      }
      return;
    }
    if (keepTime && current != null && current.completedAt == null) {
      if (current.title != task.title) {
        await _reminders.updateReminder(
          current.id,
          RemindersCompanion(title: Value(task.title)),
          s,
        );
      }
      return;
    }
    final upToDate =
        current != null &&
        current.triggerAt == at &&
        current.title == task.title &&
        current.completedAt == null;
    if (upToDate) return;
    await _linked.upsert(
      link,
      title: task.title,
      at: at,
      currentReminderId: current?.id,
      adoptLinked: false,
      stamp: s,
    );
  }

  @override
  Future<TaskCompletion> toggleComplete(String id) async {
    final row = await _dao.rowById(id);
    if (row == null) {
      return TaskCompletion(taskId: id, completed: false);
    }
    if (row.completedAt != null) {
      await uncomplete(id);
      return TaskCompletion(taskId: id, completed: false);
    }
    return _complete(id);
  }

  @override
  Future<TaskCompletion> complete(String id) => _complete(id);

  Future<TaskCompletion> _complete(String id) => db.transaction(() async {
    final s = stamp();
    final task = await getTask(id);
    // Checked inside the transaction: never re-complete (or spawn a second
    // next occurrence for) a task completed in the meantime.
    if (task == null || task.isCompleted) {
      return TaskCompletion(taskId: id, completed: false);
    }
    await _dao.updateTask(id, TasksCompanion(completedAt: Value(s.now)), s);
    final nextId = await _spawnNextOccurrence(task, s);
    if (nextId == null) await _syncReminder(id, s);
    return TaskCompletion(
      taskId: id,
      completed: true,
      nextOccurrenceId: nextId,
    );
  });

  /// For a repeating task: inserts the next open occurrence and moves the
  /// reminder onto it. Returns the new id, or null (not repeating / series
  /// over).
  Future<String?> _spawnNextOccurrence(TaskItem task, WriteStamp s) async {
    final rule = RecurrenceRule.tryParse(task.repeatRule);
    if (rule == null) return null;
    final today = DateUtilsX.dateOnly(s.now);
    final minutes = task.dueTimeMinutes;
    final anchor =
        task.dueAt ??
        (minutes == null ? today : DateUtilsX.atMinutes(today, minutes));
    // Next date after the current one, but never in a day already past.
    final after = anchor.isBefore(today)
        ? today.subtract(const Duration(seconds: 1))
        : anchor;
    final next = rule.nextAfter(anchor, after);
    if (next == null) return null;
    var nextRule = rule;
    final count = rule.count;
    if (count != null) {
      final used = rule.occurrencesBetween(anchor, anchor, next).length;
      if (count - used < 1) return null;
      nextRule = rule.copyWith(count: count - used);
    }
    final nextId = newId();
    final copy = task.copyWith(
      id: nextId,
      dueDate: DateUtilsX.dateOnly(next),
      repeatRule: nextRule.toRRule(),
      clearCompletedAt: true,
      clearReminderId: true,
      boardStatus: 0,
      subtasks: [for (final sub in task.subtasks) Subtask.draft(sub.title)],
    );
    await _dao.insertTask(
      TaskMapper.contentCompanion(copy).copyWith(
        id: Value(nextId),
        createdAt: Value(s.now),
        updatedAt: Value(s.now),
        sortOrder: Value(task.sortOrder),
        syncVersion: const Value(1),
        deviceId: Value(deviceId),
      ),
    );
    await _saveSubtasks(nextId, copy.subtasks, s.now);
    await _tags.replaceTags(
      ItemType.task,
      nextId,
      task.tags.map((t) => t.name),
      s,
    );
    final rid = task.reminderId;
    final at = copy.reminderAt;
    if (rid != null && at != null && await _reminders.rowById(rid) != null) {
      await _linked.relink(rid, copy.ref, title: copy.title, at: at, stamp: s);
      await _items.updateItems(
        ItemType.task,
        [task.id],
        {'reminder_id': const Variable<String>(null)},
        s,
      );
      await _items.updateItems(
        ItemType.task,
        [nextId],
        {'reminder_id': Variable.withString(rid)},
        s,
      );
    } else {
      await _syncReminder(nextId, s);
    }
    return nextId;
  }

  @override
  Future<void> uncomplete(String id, {String? discardNextOccurrenceId}) =>
      db.transaction(() async {
        final s = stamp();
        final row = await _dao.rowById(id);
        if (row == null) return;
        final spawnedId = discardNextOccurrenceId;
        if (spawnedId != null) {
          final spawned = await _dao.rowById(spawnedId);
          final rid = spawned?.reminderId;
          if (spawned != null) {
            if (rid != null && row.reminderId == null) {
              // Hand the reminder back to the reopened task.
              await _items.updateItems(
                ItemType.task,
                [id],
                {'reminder_id': Variable.withString(rid)},
                s,
              );
              await _reminders.updateReminder(
                rid,
                RemindersCompanion(
                  linkedItemId: Value(id),
                  linkedItemType: Value(ItemType.task.key),
                ),
                s,
              );
            } else if (rid != null) {
              await _linked.deleteRows([rid]);
            }
            await _dao.deleteSubtasksOf([spawnedId]);
            await _org.deleteItemTagsOf(ItemType.task, [spawnedId]);
            await _dao.deleteTask(spawnedId);
          }
        }
        await _dao.updateTask(
          id,
          const TasksCompanion(completedAt: Value(null)),
          s,
        );
        await _syncReminder(id, s);
      });

  @override
  Future<void> reschedule(List<String> ids, DateTime? date) => db.transaction(
    () async {
      final s = stamp();
      for (final id in ids) {
        await _dao.updateTask(
          id,
          TasksCompanion(
            dueDate: Value(date == null ? null : DateUtilsX.toStoredDay(date)),
            dueTimeMinutes: date == null
                ? const Value(null)
                : const Value.absent(),
          ),
          s,
        );
        await _syncReminder(id, s);
      }
    },
  );

  @override
  Future<void> reorder(String id, {String? afterId, String? beforeId}) async {
    final after = afterId == null ? null : await _dao.rowById(afterId);
    final before = beforeId == null ? null : await _dao.rowById(beforeId);
    await _dao.updateTask(
      id,
      TasksCompanion(
        sortOrder: Value(sortBetween(after?.sortOrder, before?.sortOrder)),
      ),
      stamp(),
    );
  }

  @override
  Future<void> setPriority(String id, TaskPriority priority) => _dao.updateTask(
    id,
    TasksCompanion(priority: Value(priority.index)),
    stamp(),
  );

  // ───────────────────────────── Subtasks ─────────────────────────────

  /// Subtasks have no sync columns: bump the parent task instead.
  Future<void> _touchTask(String taskId, WriteStamp s) =>
      _items.touch(ItemType.task, [taskId], s);

  @override
  Future<String> addSubtask(String taskId, String title) =>
      db.transaction(() async {
        final s = stamp();
        final id = newId();
        await _dao.insertSubtask(
          SubtasksCompanion.insert(
            id: id,
            taskId: taskId,
            title: Value(title.trim()),
            sortOrder: Value(
              ((await _dao.maxSubtaskSortOrder(taskId)) ?? -1) + 1,
            ),
            createdAt: s.now,
            updatedAt: s.now,
          ),
        );
        await _touchTask(taskId, s);
        return id;
      });

  Future<void> _updateSubtask(
    String subtaskId,
    SubtasksCompanion Function(SubtaskRow row) change,
  ) => db.transaction(() async {
    final row = await _dao.subtaskById(subtaskId);
    if (row == null) return;
    final s = stamp();
    await _dao.updateSubtask(
      subtaskId,
      change(row).copyWith(updatedAt: Value(s.now)),
    );
    await _touchTask(row.taskId, s);
  });

  @override
  Future<void> toggleSubtask(String subtaskId) => _updateSubtask(
    subtaskId,
    (row) => SubtasksCompanion(done: Value(!row.done)),
  );

  @override
  Future<void> renameSubtask(String subtaskId, String title) => _updateSubtask(
    subtaskId,
    (_) => SubtasksCompanion(title: Value(title.trim())),
  );

  @override
  Future<void> reorderSubtasks(String taskId, List<String> orderedIds) =>
      db.transaction(() async {
        final s = stamp();
        for (var i = 0; i < orderedIds.length; i++) {
          await _dao.updateSubtask(
            orderedIds[i],
            SubtasksCompanion(
              sortOrder: Value(i.toDouble()),
              updatedAt: Value(s.now),
            ),
          );
        }
        await _touchTask(taskId, s);
      });

  @override
  Future<void> deleteSubtask(String subtaskId) => db.transaction(() async {
    final row = await _dao.subtaskById(subtaskId);
    if (row == null) return;
    await _dao.deleteSubtask(subtaskId);
    await _touchTask(row.taskId, stamp());
  });
}
