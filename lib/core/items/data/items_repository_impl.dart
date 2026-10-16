/// ============================================================
/// ITEMS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Generic over the five item tables (ItemsDao). Day-relative Library
/// numbers that need domain rules (repeating reminders, habit schedules and
/// streaks) are delegated to the optional [RemindersRepository] /
/// [HabitsRepository] passed in — wiring happens in
/// shared/providers/repository_providers.dart.
/// ============================================================
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/focus_sessions_dao.dart';
import 'package:focusflow/core/database/daos/habits_dao.dart';
import 'package:focusflow/core/database/daos/inbox_dao.dart';
import 'package:focusflow/core/database/daos/items_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/reminders_dao.dart';
import 'package:focusflow/core/database/daos/tasks_dao.dart';
import 'package:focusflow/core/database/daos/vault_dao.dart';
import 'package:focusflow/core/items/attachment_files.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/data/stream_utils.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';

class ItemsRepositoryImpl extends RepositoryBase implements ItemsRepository {
  ItemsRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
    required AttachmentFileStore files,
    RemindersRepository? reminders,
    HabitsRepository? habits,
  }) : _fileStore = files,
       _remindersRepo = reminders,
       _habitsRepo = habits,
       _dao = ItemsDao(db),
       _org = OrganisationDao(db),
       _tasks = TasksDao(db),
       _reminders = RemindersDao(db),
       _habits = HabitsDao(db),
       _vault = VaultDao(db),
       _inbox = InboxDao(db),
       _focus = FocusSessionsDao(db),
       _tagWriter = TagWriter(OrganisationDao(db), newId);

  final AttachmentFileStore _fileStore;
  final RemindersRepository? _remindersRepo;
  final HabitsRepository? _habitsRepo;
  final ItemsDao _dao;
  final OrganisationDao _org;
  final TasksDao _tasks;
  final RemindersDao _reminders;
  final HabitsDao _habits;
  final VaultDao _vault;
  final InboxDao _inbox;
  final FocusSessionsDao _focus;
  final TagWriter _tagWriter;

  static Map<ItemType, List<String>> _byType(Iterable<ItemRef> refs) {
    final map = <ItemType, List<String>>{};
    for (final r in refs) {
      final ids = map.putIfAbsent(r.type, () => []);
      if (!ids.contains(r.id)) ids.add(r.id);
    }
    return map;
  }

  Future<void> _updateAll(
    List<ItemRef> refs,
    Map<String, Variable> columns,
  ) async {
    if (refs.isEmpty) return;
    await db.transaction(() async {
      final s = stamp();
      for (final e in _byType(refs).entries) {
        await _dao.updateItems(e.key, e.value, columns, s);
      }
    });
  }

  // ───────────────────────────── Lifecycle ────────────────────────────

  @override
  Future<void> archive(List<ItemRef> refs, {DateTime? at}) =>
      _updateAll(refs, {'archived_at': Variable<DateTime>(at ?? now())});

  @override
  Future<void> unarchive(List<ItemRef> refs) =>
      _updateAll(refs, {'archived_at': const Variable<DateTime>(null)});

  @override
  Future<void> moveToTrash(List<ItemRef> refs, {DateTime? at}) =>
      _updateAll(refs, {'deleted_at': Variable<DateTime>(at ?? now())});

  @override
  Future<void> restoreFromTrash(List<ItemRef> refs) =>
      _updateAll(refs, {'deleted_at': const Variable<DateTime>(null)});

  @override
  Future<void> setPinned(List<ItemRef> refs, bool pinned) =>
      _updateAll(refs, {'is_pinned': Variable<bool>(pinned)});

  @override
  Future<void> setFavorite(List<ItemRef> refs, bool favorite) =>
      _updateAll(refs, {'is_favorite': Variable<bool>(favorite)});

  @override
  Future<void> setColor(List<ItemRef> refs, String? colorHex) =>
      _updateAll(refs, {'color_hex': Variable<String>(colorHex)});

  @override
  Future<void> setFolder(List<ItemRef> refs, String? folderId) =>
      _updateAll(refs, {'folder_id': Variable<String>(folderId)});

  @override
  Future<void> setTags(ItemRef ref, List<String> names) =>
      db.transaction(() async {
        final s = stamp();
        if (await _tagWriter.replaceTags(ref.type, ref.id, names, s)) {
          await _dao.touch(ref.type, [ref.id], s);
        }
      });

  @override
  Future<void> addTags(List<ItemRef> refs, List<String> names) =>
      db.transaction(() async {
        final s = stamp();
        for (final ref in refs) {
          if (await _tagWriter.addTags(ref.type, ref.id, names, s)) {
            await _dao.touch(ref.type, [ref.id], s);
          }
        }
      });

  // ─────────────────────────── Delete forever ─────────────────────────

  Future<void> _deleteReminderRows(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    await _org.deleteItemTagsOf(ItemType.reminder, list);
    await _org.deleteAttachmentsOf(ItemType.reminder, list);
    await _inbox.clearItemRefs(ItemType.reminder.key, list);
    await _reminders.deleteReminders(list);
  }

  /// Reminders owned by items ([type], [ids]): linked rows + `reminder_id`.
  Future<Set<String>> _ownedReminders(ItemType type, List<String> ids) async {
    final owned = <String>{};
    for (final id in ids) {
      owned.addAll(
        (await _reminders.rowsLinkedTo(type.key, id)).map((r) => r.id),
      );
    }
    if (type == ItemType.task || type == ItemType.note) {
      final rows = await db
          .customSelect(
            'SELECT reminder_id FROM ${db.itemTableName(type)} WHERE id IN '
            '(${sqlPlaceholders(ids.length)}) AND reminder_id IS NOT NULL',
            variables: ids.map(Variable.withString).toList(),
          )
          .get();
      owned.addAll(rows.map((r) => r.read<String>('reminder_id')));
    }
    return owned;
  }

  @override
  Future<void> deleteForever(List<ItemRef> refs) async {
    if (refs.isEmpty) return;
    final paths = <String>{};
    await db.transaction(() async {
      final s = stamp();
      for (final e in _byType(refs).entries) {
        final type = e.key;
        final ids = e.value;
        final attachments = await _org.attachmentsOf(type, ids);
        paths.addAll(attachments.map((a) => a.localPath));
        await _org.deleteAttachmentsOf(type, ids);
        await _org.deleteItemTagsOf(type, ids);
        await _inbox.clearItemRefs(type.key, ids);
        switch (type) {
          case ItemType.note:
            final covers = await db
                .customSelect(
                  'SELECT cover_image_path FROM notes WHERE id IN '
                  '(${sqlPlaceholders(ids.length)}) AND cover_image_path IS NOT NULL',
                  variables: ids.map(Variable.withString).toList(),
                )
                .get();
            paths.addAll(covers.map((r) => r.read<String>('cover_image_path')));
            await _deleteReminderRows(await _ownedReminders(type, ids));
            await db.customUpdate(
              'UPDATE tasks SET linked_note_id = NULL, updated_at = ?, '
              'device_id = ?, sync_version = sync_version + 1 '
              'WHERE linked_note_id IN (${sqlPlaceholders(ids.length)})',
              variables: [
                Variable<DateTime>(s.now),
                Variable.withString(deviceId),
                ...ids.map(Variable.withString),
              ],
              updates: {db.tasks},
              updateKind: UpdateKind.update,
            );
          case ItemType.task:
            await _deleteReminderRows(await _ownedReminders(type, ids));
            await _tasks.deleteSubtasksOf(ids);
            await _focus.detachTasks(ids);
          case ItemType.reminder:
            for (final t in [ItemType.task, ItemType.note]) {
              await db.customUpdate(
                'UPDATE ${db.itemTableName(t)} SET reminder_id = NULL, '
                'updated_at = ?, device_id = ?, sync_version = sync_version + 1 '
                'WHERE reminder_id IN (${sqlPlaceholders(ids.length)})',
                variables: [
                  Variable<DateTime>(s.now),
                  Variable.withString(deviceId),
                  ...ids.map(Variable.withString),
                ],
                updates: {db.itemTable(t)},
                updateKind: UpdateKind.update,
              );
            }
          case ItemType.habit:
            await _deleteReminderRows(await _ownedReminders(type, ids));
            await _habits.deleteLogsOf(ids);
          case ItemType.vault:
            await _vault.deleteHistoryOf(ids);
        }
        await _dao.deleteRows(type, ids);
      }
    });
    for (final path in paths) {
      try {
        if (!await _org.isFileReferenced(path)) await _fileStore.delete(path);
      } catch (e) {
        AppLogger.w('Could not delete attachment file: $e');
      }
    }
  }

  // ──────────────────────────── Duplicate ─────────────────────────────

  @override
  Future<String> duplicate(ItemRef ref) => db.transaction(() async {
    final s = stamp();
    final table = db.itemTable(ref.type);
    final newIdValue = newId();
    final titleCol = ref.type == ItemType.habit ? 'name' : 'title';
    final overrides = <String, (String, List<Variable>)>{
      'id': ('?', [Variable.withString(newIdValue)]),
      'created_at': ('?', [Variable<DateTime>(s.now)]),
      'updated_at': ('?', [Variable<DateTime>(s.now)]),
      'archived_at': ('NULL', const []),
      'deleted_at': ('NULL', const []),
      'is_pinned': ('0', const []),
      'sync_version': ('1', const []),
      'last_synced_at': ('NULL', const []),
      'device_id': ('?', [Variable.withString(deviceId)]),
      'sort_order': ('sort_order + 0.5', const []),
      titleCol: (
        "CASE WHEN trim($titleCol) = '' THEN $titleCol "
            "ELSE $titleCol || ' (copy)' END",
        const [],
      ),
      if (ref.type == ItemType.note) 'reminder_id': ('NULL', const []),
      if (ref.type == ItemType.task) 'reminder_id': ('NULL', const []),
      if (ref.type == ItemType.task)
        'remind_offset_minutes': ('NULL', const []),
      if (ref.type == ItemType.reminder)
        'notification_id': (
          '?',
          [
            Variable.withInt(
              await _reminders.allocateNotificationId(newIdValue),
            ),
          ],
        ),
    };
    final cols = table.$columns.map((c) => c.name).toList();
    final exprs = <String>[];
    final vars = <Variable>[];
    for (final c in cols) {
      final o = overrides[c];
      if (o == null) {
        exprs.add(c);
      } else {
        exprs.add(o.$1);
        vars.addAll(o.$2);
      }
    }
    final inserted = await db.customUpdate(
      'INSERT INTO ${table.actualTableName} (${cols.join(', ')}) '
      'SELECT ${exprs.join(', ')} FROM ${table.actualTableName} WHERE id = ?',
      variables: [...vars, Variable.withString(ref.id)],
      updates: {table},
      updateKind: UpdateKind.insert,
    );
    if (inserted == 0) {
      throw StateError('Cannot duplicate missing item $ref');
    }
    await db.customUpdate(
      'INSERT INTO item_tags (item_id, item_type, tag_id) '
      'SELECT ?, item_type, tag_id FROM item_tags WHERE item_type = ? AND item_id = ?',
      variables: [
        Variable.withString(newIdValue),
        Variable.withString(ref.type.key),
        Variable.withString(ref.id),
      ],
      updates: {db.itemTags},
      updateKind: UpdateKind.insert,
    );
    for (final a in await _org.attachmentsOf(ref.type, [ref.id])) {
      await _org.insertAttachment(
        a
            .toCompanion(false)
            .copyWith(
              id: Value(newId()),
              itemId: Value(newIdValue),
              createdAt: Value(s.now),
            ),
      );
    }
    if (ref.type == ItemType.task) {
      for (final sub in await _tasks.subtasksOf(ref.id)) {
        await _tasks.insertSubtask(
          sub
              .toCompanion(false)
              .copyWith(
                id: Value(newId()),
                taskId: Value(newIdValue),
                createdAt: Value(s.now),
                updatedAt: Value(s.now),
              ),
        );
      }
    }
    return newIdValue;
  });

  // ───────────────────────────── Reading ──────────────────────────────

  static const _moduleOrder =
      "CASE i.item_type WHEN 'note' THEN 0 WHEN 'task' THEN 1 "
      "WHEN 'reminder' THEN 2 WHEN 'habit' THEN 3 ELSE 4 END";

  static List<ItemSummary> _mapAll(List<QueryRow> rows) =>
      List.unmodifiable(rows.map(ItemMappers.summary));

  Selectable<QueryRow> _one(ItemRef ref) => _dao.summaries(
    where: 'i.item_type = ? AND i.id = ?',
    variables: [Variable.withString(ref.type.key), Variable.withString(ref.id)],
  );

  @override
  Future<ItemSummary?> get(ItemRef ref) async {
    final row = await _one(ref).getSingleOrNull();
    return row == null ? null : ItemMappers.summary(row);
  }

  @override
  Stream<ItemSummary?> watch(ItemRef ref) => _one(ref)
      .watch()
      .map((rows) => rows.isEmpty ? null : ItemMappers.summary(rows.first))
      .distinct();

  @override
  Stream<List<ItemSummary>> watchArchived({ItemType? type, String? query}) {
    final where = ['i.archived_at IS NOT NULL', 'i.deleted_at IS NULL'];
    final vars = <Variable>[];
    if (type != null) {
      where.add('i.item_type = ?');
      vars.add(Variable.withString(type.key));
    }
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      where.add(r"i.title LIKE ? ESCAPE '\'");
      vars.add(Variable.withString(likeContains(q)));
    }
    return _dao
        .summaries(
          where: where.join(' AND '),
          variables: vars,
          orderBy: 'i.archived_at DESC, i.updated_at DESC',
        )
        .watch()
        .map(_mapAll);
  }

  @override
  Stream<List<ItemSummary>> watchTrash() => _dao
      .summaries(
        where: 'i.deleted_at IS NOT NULL',
        orderBy: 'i.deleted_at DESC, i.updated_at DESC',
      )
      .watch()
      .map(_mapAll);

  // Collections (Pinned, Favourites, by tag) only list *visible* items: a
  // reminder whose linked task / note is archived or trashed is hidden
  // (ItemsDao.visibleSql), exactly as in the reminders list.

  @override
  Stream<List<ItemSummary>> watchPinned() => _dao
      .summaries(
        where:
            '${activeSql('i')} AND ${ItemsDao.visibleSql} AND i.is_pinned = 1',
        orderBy: '$_moduleOrder, i.updated_at DESC',
      )
      .watch()
      .map(_mapAll);

  @override
  Stream<List<ItemSummary>> watchFavourites() => _dao
      .summaries(
        where:
            '${activeSql('i')} AND ${ItemsDao.visibleSql} AND i.is_favorite = 1',
        orderBy: '$_moduleOrder, i.updated_at DESC',
      )
      .watch()
      .map(_mapAll);

  @override
  Stream<List<ItemSummary>> watchByTag(String tagId) => _dao
      .summaries(
        where:
            '${activeSql('i')} AND ${ItemsDao.visibleSql} AND EXISTS ('
            'SELECT 1 FROM item_tags it '
            'WHERE it.item_type = i.item_type AND it.item_id = i.id '
            'AND it.tag_id = ?)',
        variables: [Variable.withString(tagId)],
        orderBy: '$_moduleOrder, i.updated_at DESC',
      )
      .watch()
      .map(_mapAll);

  @override
  Stream<LibraryCounts> watchLibraryCounts({DateTime? now}) {
    final at = now ?? clock.now();
    final day = DateUtilsX.dateOnly(at);
    final base = _dao
        .libraryCounts(dayStart: day, dayEnd: DateUtilsX.addDays(day, 1))
        .watchSingle();
    final reminders = _remindersRepo;
    final habits = _habitsRepo;
    return combineLatestList<LibraryCounts>(
      [
        base,
        reminders?.watchForDay(day) ??
            Stream.value(const <ReminderOccurrence>[]),
        reminders?.watchNext(at) ?? Stream<ReminderOccurrence?>.value(null),
        habits?.watchTodayHabits(day) ?? Stream.value(const <HabitDayStatus>[]),
      ],
      (v) {
        final r = v[0] as QueryRow;
        final today = v[1] as List<ReminderOccurrence>;
        final next = v[2] as ReminderOccurrence?;
        final statuses = v[3] as List<HabitDayStatus>;
        var bestStreak = 0;
        for (final s in statuses) {
          if (s.currentStreak > bestStreak) bestStreak = s.currentStreak;
        }
        return LibraryCounts(
          notesTotal: r.read<int>('notes_total'),
          notesPinned: r.read<int>('notes_pinned'),
          notesLastEditedAt: r.readNullable<DateTime>('notes_last_edited'),
          tasksTotal: r.read<int>('tasks_total'),
          tasksOpen: r.read<int>('tasks_open'),
          tasksDueToday: r.read<int>('tasks_due_today'),
          tasksOverdue: r.read<int>('tasks_overdue'),
          tasksDone: r.read<int>('tasks_done'),
          remindersTotal: r.read<int>('reminders_total'),
          remindersToday: today.length,
          remindersNextAt: next?.at,
          habitsTotal: r.read<int>('habits_total'),
          habitsDoneToday: statuses
              .where((s) => s.isScheduled && s.isDone)
              .length,
          habitsScheduledToday: statuses.where((s) => s.isScheduled).length,
          habitsBestStreak: bestStreak,
          vaultTotal: r.read<int>('vault_total'),
          vaultWeak: r.read<int>('vault_weak'),
          vaultBreached: r.read<int>('vault_breached'),
          pinned: r.read<int>('pinned'),
          favourites: r.read<int>('favourites'),
          tags: r.read<int>('tags'),
          folders: r.read<int>('folders'),
          archived: r.read<int>('archived'),
          trash: r.read<int>('trashed'),
        );
      },
    ).distinct();
  }

  @override
  Future<int> purgeExpired({
    Duration retention = const Duration(days: 30),
  }) async {
    final expired = await _dao.trashedBefore(now().subtract(retention));
    if (expired.isEmpty) return 0;
    await deleteForever([for (final (t, id) in expired) ItemRef(t, id)]);
    return expired.length;
  }

  @override
  Future<int> purgeBlankNotes({
    Duration olderThan = const Duration(hours: 1),
  }) async {
    final cutoff = now().subtract(olderThan);
    final rows = await db
        .customSelect(
          'SELECT n.id, n.content_delta FROM notes n '
          "WHERE trim(n.title) = '' AND trim(n.plain_text) = '' "
          "AND (n.checklist_json IS NULL OR trim(n.checklist_json) IN ('', '[]')) "
          'AND n.cover_image_path IS NULL AND n.reminder_id IS NULL '
          'AND n.last_synced_at IS NULL '
          'AND n.archived_at IS NULL AND n.deleted_at IS NULL '
          'AND n.is_pinned = 0 AND n.is_favorite = 0 AND n.is_locked = 0 '
          'AND n.created_at < ?1 AND n.updated_at < ?1 '
          "AND NOT EXISTS (SELECT 1 FROM attachments a WHERE a.item_type = 'note' "
          'AND a.item_id = n.id) '
          "AND NOT EXISTS (SELECT 1 FROM item_tags it WHERE it.item_type = 'note' "
          'AND it.item_id = n.id) '
          "AND NOT EXISTS (SELECT 1 FROM reminders r WHERE r.linked_item_type = 'note' "
          'AND r.linked_item_id = n.id) '
          'AND NOT EXISTS (SELECT 1 FROM tasks t WHERE t.linked_note_id = n.id)',
          variables: [Variable<DateTime>(cutoff)],
          readsFrom: {
            db.notes,
            db.attachments,
            db.itemTags,
            db.reminders,
            db.tasks,
          },
        )
        .get();
    final blank = [
      for (final r in rows)
        if (_isBlankDelta(r.read<String>('content_delta')))
          ItemRef(ItemType.note, r.read<String>('id')),
    ];
    if (blank.isEmpty) return 0;
    await deleteForever(blank);
    return blank.length;
  }

  /// True when a Delta holds only whitespace text (no embeds). Anything
  /// unreadable counts as content — never delete what we can't parse.
  static bool _isBlankDelta(String json) {
    if (json.trim().isEmpty) return true;
    try {
      final ops = jsonDecode(json);
      if (ops is! List) return false;
      for (final op in ops) {
        if (op is! Map) return false;
        final insert = op['insert'];
        if (insert is! String || insert.trim().isNotEmpty) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
