/// ============================================================
/// ITEMS DAO — module-agnostic lifecycle + cross-module summaries
/// ============================================================
///
/// Works on any of the five item tables through [ItemType]:
///   • [updateItems]  — stamped UPDATE of shared columns (archive, trash,
///                      pin, favourite, colour, folder …) for many ids.
///   • [deleteRows]   — hard DELETE (used by deleteForever / purge).
///   • [summaries]    — one UNION ALL over every module projecting the
///                      shared columns (Archive, Trash, Pinned, Favourites,
///                      by-tag lists).
///   • [libraryCounts] — every number the Library screen shows that can be
///                      answered by SQL alone.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';

part 'items_dao.g.dart';

@DriftAccessor(
  tables: [
    Notes,
    Tasks,
    Reminders,
    Habits,
    VaultItems,
    Folders,
    Tags,
    ItemTags,
  ],
)
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.attachedDatabase);

  /// Shared projection of every item table. Columns: item_type, id, title,
  /// meta, color_hex, is_pinned, is_favorite, folder_id, is_locked,
  /// created_at, updated_at, archived_at, deleted_at, scheduled_at,
  /// scheduled_minutes, is_completed, sort_order, linked_item_type,
  /// linked_item_id (reminders only — see [visibleSql]).
  static const String unionSql =
      "SELECT 'note' AS item_type, x.id AS id, x.title AS title, "
      "CASE WHEN x.is_locked = 1 THEN '' ELSE substr(x.plain_text, 1, 200) END AS meta, "
      'x.color_hex AS color_hex, x.is_pinned AS is_pinned, x.is_favorite AS is_favorite, '
      'x.folder_id AS folder_id, x.is_locked AS is_locked, x.created_at AS created_at, '
      'x.updated_at AS updated_at, x.archived_at AS archived_at, x.deleted_at AS deleted_at, '
      'NULL AS scheduled_at, NULL AS scheduled_minutes, 0 AS is_completed, '
      'x.sort_order AS sort_order, NULL AS linked_item_type, '
      'NULL AS linked_item_id FROM notes x '
      'UNION ALL '
      "SELECT 'task', x.id, x.title, x.notes, x.color_hex, x.is_pinned, x.is_favorite, "
      'x.folder_id, 0, x.created_at, x.updated_at, x.archived_at, x.deleted_at, '
      'x.due_date, x.due_time_minutes, '
      'CASE WHEN x.completed_at IS NULL THEN 0 ELSE 1 END, x.sort_order, '
      'NULL, NULL FROM tasks x '
      'UNION ALL '
      "SELECT 'reminder', x.id, x.title, x.note, x.color_hex, x.is_pinned, x.is_favorite, "
      'x.folder_id, 0, x.created_at, x.updated_at, x.archived_at, x.deleted_at, '
      'COALESCE(x.snoozed_until, x.trigger_at), NULL, '
      'CASE WHEN x.completed_at IS NOT NULL AND x.repeat_rule IS NULL THEN 1 ELSE 0 END, '
      'x.sort_order, x.linked_item_type, x.linked_item_id FROM reminders x '
      'UNION ALL '
      "SELECT 'habit', x.id, x.name, x.category, x.color_hex, x.is_pinned, x.is_favorite, "
      'x.folder_id, 0, x.created_at, x.updated_at, x.archived_at, x.deleted_at, '
      'NULL, NULL, 0, x.sort_order, NULL, NULL FROM habits x '
      'UNION ALL '
      "SELECT 'vault', x.id, x.title, CASE x.item_type WHEN 1 THEN 'Card' "
      "WHEN 2 THEN 'Wi-Fi' WHEN 3 THEN 'Secure note' ELSE 'Login' END, "
      'x.color_hex, x.is_pinned, x.is_favorite, x.folder_id, 1, x.created_at, '
      'x.updated_at, x.archived_at, x.deleted_at, NULL, NULL, 0, x.sort_order, '
      'NULL, NULL FROM vault_items x';

  /// Condition over a [unionSql] row aliased `i`: false for a reminder whose
  /// linked task / note is archived, trashed or gone (such reminders are
  /// hidden from every list, collection and count).
  static final String visibleSql =
      "(i.item_type <> 'reminder' OR ${reminderLinkVisibleSql('i')})";

  Set<ResultSetImplementation<dynamic, dynamic>> get _summaryTables => {
    ...attachedDatabase.allItemTables,
    folders,
    itemTags,
  };

  /// Cross-module rows (see [unionSql]) plus `folder_name`, filtered by
  /// [where] (SQL over the projected columns, alias `i`) with bound
  /// [variables], ordered by [orderBy].
  Selectable<QueryRow> summaries({
    required String where,
    List<Variable> variables = const [],
    String orderBy = 'i.updated_at DESC',
    int? limit,
  }) => customSelect(
    'SELECT i.*, f.name AS folder_name FROM ($unionSql) i '
    'LEFT JOIN folders f ON f.id = i.folder_id AND f.deleted_at IS NULL '
    'WHERE $where ORDER BY $orderBy${limit == null ? '' : ' LIMIT $limit'}',
    variables: variables,
    readsFrom: _summaryTables,
  );

  /// Stamped UPDATE of [columns] (SQL column name → bound value) on the
  /// rows [ids] of [type]'s table. Returns the number of rows changed.
  Future<int> updateItems(
    ItemType type,
    Iterable<String> ids,
    Map<String, Variable> columns,
    WriteStamp stamp,
  ) async {
    final idList = ids.toList();
    if (idList.isEmpty) return 0;
    final sets = [
      for (final c in columns.keys) '$c = ?',
      'updated_at = ?',
      'device_id = ?',
      'sync_version = sync_version + 1',
    ].join(', ');
    return customUpdate(
      'UPDATE ${attachedDatabase.itemTableName(type)} SET $sets '
      'WHERE id IN (${sqlPlaceholders(idList.length)})',
      variables: [
        ...columns.values,
        Variable<DateTime>(stamp.now),
        Variable.withString(stamp.deviceId),
        ...idList.map(Variable.withString),
      ],
      updates: {attachedDatabase.itemTable(type)},
      updateKind: UpdateKind.update,
    );
  }

  /// Stamped UPDATE of every item of [type] currently in [folderId] →
  /// `folder_id = NULL` (folder deleted).
  Future<int> clearFolder(ItemType type, String folderId, WriteStamp stamp) =>
      customUpdate(
        'UPDATE ${attachedDatabase.itemTableName(type)} SET folder_id = NULL, '
        'updated_at = ?, device_id = ?, sync_version = sync_version + 1 '
        'WHERE folder_id = ?',
        variables: [
          Variable<DateTime>(stamp.now),
          Variable.withString(stamp.deviceId),
          Variable.withString(folderId),
        ],
        updates: {attachedDatabase.itemTable(type)},
        updateKind: UpdateKind.update,
      );

  /// Bumps sync fields only (e.g. after the item's tags changed).
  Future<int> touch(ItemType type, Iterable<String> ids, WriteStamp stamp) =>
      updateItems(type, ids, const {}, stamp);

  /// Hard DELETE of rows [ids] from [type]'s table.
  Future<int> deleteRows(ItemType type, Iterable<String> ids) {
    final idList = ids.toList();
    if (idList.isEmpty) return Future.value(0);
    return customUpdate(
      'DELETE FROM ${attachedDatabase.itemTableName(type)} '
      'WHERE id IN (${sqlPlaceholders(idList.length)})',
      variables: idList.map(Variable.withString).toList(),
      updates: {attachedDatabase.itemTable(type)},
      updateKind: UpdateKind.delete,
    );
  }

  /// Ids of [type] that exist (any lifecycle state) among [ids].
  Future<List<String>> existingIds(ItemType type, Iterable<String> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return const [];
    final rows = await customSelect(
      'SELECT id FROM ${attachedDatabase.itemTableName(type)} '
      'WHERE id IN (${sqlPlaceholders(idList.length)})',
      variables: idList.map(Variable.withString).toList(),
      readsFrom: {attachedDatabase.itemTable(type)},
    ).get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  /// `(type, id)` of every trashed item deleted at or before [cutoff].
  Future<List<(ItemType, String)>> trashedBefore(DateTime cutoff) async {
    final rows = await customSelect(
      'SELECT item_type, id FROM ($unionSql) i '
      'WHERE i.deleted_at IS NOT NULL AND i.deleted_at <= ?',
      variables: [Variable<DateTime>(cutoff)],
      readsFrom: attachedDatabase.allItemTables,
    ).get();
    return [
      for (final r in rows)
        (ItemType.fromKey(r.read<String>('item_type'))!, r.read<String>('id')),
    ];
  }

  /// Library numbers answerable by SQL. [dayStart]/[dayEnd] bound "today".
  Selectable<QueryRow> libraryCounts({
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    // Reminders of an inactive linked item are hidden, so they never count
    // as active (total, pinned, favourites).
    String visible(String table) => table == 'reminders'
        ? ' AND ${reminderLinkVisibleSql('reminders')}'
        : '';
    String count(String table, [String extra = '']) =>
        '(SELECT COUNT(*) FROM $table WHERE ${activeSql()}${visible(table)}$extra)';
    final archived = AppDatabase.itemTables.values
        .map(
          (t) =>
              '(SELECT COUNT(*) FROM $t WHERE archived_at IS NOT NULL AND deleted_at IS NULL)',
        )
        .join(' + ');
    final trashed = AppDatabase.itemTables.values
        .map((t) => '(SELECT COUNT(*) FROM $t WHERE deleted_at IS NOT NULL)')
        .join(' + ');
    final pinned = AppDatabase.itemTables.values
        .map((t) => count(t, ' AND is_pinned = 1'))
        .join(' + ');
    final favs = AppDatabase.itemTables.values
        .map((t) => count(t, ' AND is_favorite = 1'))
        .join(' + ');
    return customSelect(
      'SELECT '
      '${count('notes')} AS notes_total, '
      "${count('notes', ' AND is_pinned = 1')} AS notes_pinned, "
      '(SELECT MAX(updated_at) FROM notes WHERE ${activeSql()}) AS notes_last_edited, '
      '${count('tasks')} AS tasks_total, '
      "${count('tasks', ' AND completed_at IS NULL')} AS tasks_open, "
      "${count('tasks', ' AND completed_at IS NULL AND due_date >= ?1 AND due_date < ?2')} AS tasks_due_today, "
      "${count('tasks', ' AND completed_at IS NULL AND due_date < ?1')} AS tasks_overdue, "
      "${count('tasks', ' AND completed_at IS NOT NULL')} AS tasks_done, "
      '${count('reminders')} AS reminders_total, '
      '${count('habits')} AS habits_total, '
      '${count('vault_items')} AS vault_total, '
      "${count('vault_items', ' AND password_strength IS NOT NULL AND password_strength <= 1')} AS vault_weak, "
      "${count('vault_items', ' AND breach_count > 0')} AS vault_breached, "
      '($pinned) AS pinned, ($favs) AS favourites, '
      '(SELECT COUNT(*) FROM tags) AS tags, '
      '(SELECT COUNT(*) FROM folders WHERE deleted_at IS NULL) AS folders, '
      '($archived) AS archived, ($trashed) AS trashed',
      // ?1/?2 only bound tasks.due_date — a floating day.
      variables: [
        Variable<DateTime>(DateUtilsX.toStoredDay(dayStart)),
        Variable<DateTime>(DateUtilsX.toStoredDay(dayEnd)),
      ],
      readsFrom: {...attachedDatabase.allItemTables, tags, folders},
    );
  }
}
