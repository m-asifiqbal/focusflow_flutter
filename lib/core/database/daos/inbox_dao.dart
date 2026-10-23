/// ============================================================
/// INBOX DAO — `inbox_entries` (Notification centre, screen 27)
/// ============================================================
///
/// Entries that point at an archived or trashed item are hidden from every
/// read stream (list + unread count): archived / deleted items must never
/// surface in notifications (CLAUDE.md rule 3). They are filtered with a
/// correlated `EXISTS` on the item's own table, so restoring the item makes
/// its entries reappear and the streams re-emit when the item changes.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/tables.dart';
import 'package:focusflow/core/items/item_type.dart';

part 'inbox_dao.g.dart';

@DriftAccessor(tables: [InboxEntries])
class InboxDao extends DatabaseAccessor<AppDatabase> with _$InboxDaoMixin {
  InboxDao(super.attachedDatabase);

  /// Not-dismissed entries (optionally of one [kind]), newest first.
  Stream<List<InboxRow>> watchEntries({String? kind}) {
    final q = select(inboxEntries)
      ..where((e) {
        Expression<bool> c = e.dismissedAt.isNull() & _itemVisible(e);
        if (kind != null) c = c & e.kind.equals(kind);
        return c;
      })
      ..orderBy([
        (e) => OrderingTerm.desc(e.createdAt),
        (e) => OrderingTerm.desc(e.rowId),
      ]);
    return q.watch();
  }

  Stream<int> watchUnreadCount() => inboxEntries
      .count(
        where: (e) =>
            e.readAt.isNull() & e.dismissedAt.isNull() & _itemVisible(e),
      )
      .watchSingle();

  /// False when [e] points at an item that is archived or in Recently
  /// Deleted. Entries without an item, or whose item is gone, stay visible.
  Expression<bool> _itemVisible($InboxEntriesTable e) {
    final db = attachedDatabase;
    Expression<bool> hiddenIn(
      ItemType type,
      ResultSetImplementation<HasResultSet, dynamic> table,
      Expression<String> id,
      Expression<DateTime> archivedAt,
      Expression<DateTime> deletedAt,
    ) =>
        e.itemType.equals(type.key) &
        existsQuery(
          selectOnly(table)
            ..addColumns([id])
            ..where(
              id.equalsExp(e.itemId) &
                  (archivedAt.isNotNull() | deletedAt.isNotNull()),
            ),
        );
    final hidden = [
      hiddenIn(
        ItemType.note,
        db.notes,
        db.notes.id,
        db.notes.archivedAt,
        db.notes.deletedAt,
      ),
      hiddenIn(
        ItemType.task,
        db.tasks,
        db.tasks.id,
        db.tasks.archivedAt,
        db.tasks.deletedAt,
      ),
      hiddenIn(
        ItemType.reminder,
        db.reminders,
        db.reminders.id,
        db.reminders.archivedAt,
        db.reminders.deletedAt,
      ),
      hiddenIn(
        ItemType.habit,
        db.habits,
        db.habits.id,
        db.habits.archivedAt,
        db.habits.deletedAt,
      ),
      hiddenIn(
        ItemType.medicine,
        db.medicines,
        db.medicines.id,
        db.medicines.archivedAt,
        db.medicines.deletedAt,
      ),
      hiddenIn(
        ItemType.vault,
        db.vaultItems,
        db.vaultItems.id,
        db.vaultItems.archivedAt,
        db.vaultItems.deletedAt,
      ),
    ];
    return Expression.or(hidden).not();
  }

  Future<InboxRow?> rowById(String id) =>
      (select(inboxEntries)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<void> insertEntry(InboxEntriesCompanion row) =>
      into(inboxEntries).insert(row);

  /// An entry with the same kind, title, item and creation time (a
  /// notification delivery recorded twice — e.g. by the app and the
  /// background action isolate at once), if any.
  Future<InboxRow?> findSame({
    required String kind,
    required String title,
    required String? itemType,
    required String? itemId,
    required DateTime createdAt,
  }) =>
      (select(inboxEntries)
            ..where(
              (e) =>
                  e.kind.equals(kind) &
                  e.title.equals(title) &
                  e.createdAt.equals(createdAt) &
                  (itemId == null
                      ? e.itemId.isNull()
                      : e.itemId.equals(itemId)) &
                  (itemType == null
                      ? e.itemType.isNull()
                      : e.itemType.equals(itemType)),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<int> updateEntry(String id, InboxEntriesCompanion changes) =>
      (update(inboxEntries)..where((e) => e.id.equals(id))).write(changes);

  /// Marks every unread, not-dismissed entry (optionally of [kind]) read.
  /// (Hidden entries of archived items are included on purpose: they are
  /// read when they reappear after a restore.)
  Future<int> markAllRead(DateTime at, {String? kind}) =>
      (update(inboxEntries)..where((e) {
            Expression<bool> c = e.readAt.isNull() & e.dismissedAt.isNull();
            if (kind != null) c = c & e.kind.equals(kind);
            return c;
          }))
          .write(InboxEntriesCompanion(readAt: Value(at)));

  /// Hard-deletes entries created before [cutoff].
  Future<int> deleteOlderThan(DateTime cutoff) => (delete(
    inboxEntries,
  )..where((e) => e.createdAt.isSmallerThanValue(cutoff))).go();

  /// Clears the item pointer of entries about a permanently deleted item.
  Future<int> clearItemRefs(String itemType, Iterable<String> itemIds) =>
      (update(
            inboxEntries,
          )..where((e) => e.itemType.equals(itemType) & e.itemId.isIn(itemIds)))
          .write(
            const InboxEntriesCompanion(
              itemId: Value(null),
              itemType: Value(null),
            ),
          );
}
