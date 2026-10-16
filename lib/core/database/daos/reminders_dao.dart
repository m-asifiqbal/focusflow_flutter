/// ============================================================
/// REMINDERS DAO — row-level queries for `reminders`
/// ============================================================
///
/// Rows carry `linked_title` (title of the task / note / habit the
/// reminder belongs to). [linkedVisibleSql] hides reminders whose linked
/// item is archived, trashed or gone — "archived items never fire".
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';

part 'reminders_dao.g.dart';

/// A reminder row plus the linked item's title.
typedef ReminderListRow = ({ReminderRow row, String? linkedTitle});

@DriftAccessor(
  tables: [Reminders, Tasks, Notes, Habits, VaultItems, ItemTags, Tags],
)
class RemindersDao extends DatabaseAccessor<AppDatabase>
    with _$RemindersDaoMixin {
  RemindersDao(super.attachedDatabase);

  static const _select =
      'SELECT r.*, CASE r.linked_item_type '
      "WHEN 'task' THEN (SELECT title FROM tasks WHERE id = r.linked_item_id) "
      "WHEN 'note' THEN (SELECT title FROM notes WHERE id = r.linked_item_id) "
      "WHEN 'habit' THEN (SELECT name FROM habits WHERE id = r.linked_item_id) "
      "WHEN 'vault' THEN (SELECT title FROM vault_items WHERE id = r.linked_item_id) "
      'ELSE NULL END AS linked_title FROM reminders r';

  /// True when the reminder has no link or its linked item is active.
  static final String linkedVisibleSql =
      '(r.linked_item_id IS NULL OR r.linked_item_type IS NULL OR '
      "r.linked_item_type = 'reminder' OR "
      '${linkedItemActiveSql('r.linked_item_type', 'r.linked_item_id')})';

  Set<ResultSetImplementation<dynamic, dynamic>> get _readTables => {
    reminders,
    tasks,
    notes,
    habits,
    vaultItems,
    itemTags,
  };

  ReminderListRow _map(QueryRow r) => (
    row: reminders.map(r.data),
    linkedTitle: r.readNullable<String>('linked_title'),
  );

  /// Reminders matching [where] (SQL over alias `r`, bound [variables]).
  /// Set [onlyVisibleLinks] to hide reminders of inactive linked items.
  Selectable<ReminderListRow> queryReminders({
    required String where,
    List<Variable> variables = const [],
    bool onlyVisibleLinks = true,
    String orderBy = 'COALESCE(r.snoozed_until, r.trigger_at) ASC',
  }) => customSelect(
    '$_select WHERE $where'
    '${onlyVisibleLinks ? ' AND $linkedVisibleSql' : ''} ORDER BY $orderBy',
    variables: variables,
    readsFrom: _readTables,
  ).map(_map);

  Selectable<ReminderListRow> reminderById(String id) => customSelect(
    '$_select WHERE r.id = ?',
    variables: [Variable.withString(id)],
    readsFrom: _readTables,
  ).map(_map);

  Future<ReminderRow?> rowById(String id) =>
      (select(reminders)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Reminders linked to an item (any lifecycle state).
  Future<List<ReminderRow>> rowsLinkedTo(String itemType, String itemId) =>
      (select(reminders)..where(
            (r) =>
                r.linkedItemType.equals(itemType) &
                r.linkedItemId.equals(itemId),
          ))
          .get();

  Future<bool> notificationIdExists(int id) async => (await (select(
    reminders,
  )..where((r) => r.notificationId.equals(id))).get()).isNotEmpty;

  /// Notification id the engine reserves for the silent iOS badge request
  /// (LocalNotificationsGateway); never handed to a reminder.
  static const int reservedBadgeId = 0x7FFFFFF0;

  /// Stable positive 31-bit notification id derived from the reminder [id]
  /// (FNV-1a), probing upwards on the (rare) collision. Skips 0 and the
  /// reserved badge id.
  Future<int> allocateNotificationId(String id) async {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    var candidate = hash & 0x7FFFFFFF;
    if (candidate == 0) candidate = 1;
    while (candidate == reservedBadgeId ||
        await notificationIdExists(candidate)) {
      candidate = candidate >= 0x7FFFFFFF ? 1 : candidate + 1;
    }
    return candidate;
  }

  Future<void> insertReminder(RemindersCompanion row) =>
      into(reminders).insert(row);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updateReminder(
    String id,
    RemindersCompanion changes,
    WriteStamp stamp,
  ) => (update(
    reminders,
  )..where((r) => r.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<int> deleteReminders(Iterable<String> ids) =>
      (delete(reminders)..where((r) => r.id.isIn(ids))).go();

  Future<double?> maxSortOrder() {
    final max = reminders.sortOrder.max();
    return (selectOnly(
      reminders,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }
}
