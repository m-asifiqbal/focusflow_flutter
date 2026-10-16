/// ============================================================
/// LINKED REMINDERS — reminders owned by a task / note
/// ============================================================
///
/// The task editor's "Remind me 15 min before" and the note editor's "Set
/// reminder" create a reminder linked to the item (`linked_item_*`) and
/// store its id on the item (`reminder_id`). This helper is shared by
/// RemindersRepositoryImpl (upsertLinkedReminder) and TasksRepositoryImpl
/// (which keeps the reminder in sync when a task is saved, completed,
/// rescheduled or repeats). Call its methods inside a transaction.
///
/// A reminder the user archived or trashed is never touched implicitly:
/// [find] skips it, [upsert] never clears `archivedAt`/`deletedAt`, and
/// [remove] leaves it in Archive / Recently Deleted (rule 3 — one
/// lifecycle). Undo of that archive/trash therefore still works.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/inbox_dao.dart';
import 'package:focusflow/core/database/daos/items_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/reminders_dao.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';

class LinkedReminders {
  LinkedReminders(AppDatabase db, this._newId)
    : _dao = RemindersDao(db),
      _items = ItemsDao(db),
      _org = OrganisationDao(db),
      _inbox = InboxDao(db);

  final RemindersDao _dao;
  final ItemsDao _items;
  final OrganisationDao _org;
  final InboxDao _inbox;
  final IdGenerator _newId;

  /// Item types whose table has a `reminder_id` column.
  static bool hasReminderColumn(ItemType t) =>
      t == ItemType.task || t == ItemType.note;

  /// Whether [row] is in Archive or Recently Deleted.
  static bool isInactive(ReminderRow row) =>
      row.archivedAt != null || row.deletedAt != null;

  /// The *active* reminder currently owned by [link]: the item's
  /// `reminder_id` if it points at an active row, else (when [adoptLinked])
  /// the first active reminder linked to it. Archived / trashed rows are
  /// never returned, so nothing here can pull them back into lists.
  Future<ReminderRow?> find(
    ItemRef link, {
    String? reminderId,
    bool adoptLinked = true,
  }) async {
    if (reminderId != null) {
      final row = await _dao.rowById(reminderId);
      if (row != null && !isInactive(row)) return row;
    }
    if (!adoptLinked) return null;
    final linked = await _dao.rowsLinkedTo(link.type.key, link.id);
    return linked.where((r) => !isInactive(r)).firstOrNull;
  }

  /// Creates or updates the reminder of [link] (enabled, not done, not
  /// snoozed) and stores its id on the item. Returns the reminder id.
  /// With [adoptLinked] false only [currentReminderId] is reused (a task's
  /// own "Remind me" must never take over a reminder the user linked to
  /// the task by hand).
  Future<String> upsert(
    ItemRef link, {
    required String title,
    required DateTime at,
    String? repeatRule,
    String? currentReminderId,
    bool adoptLinked = true,
    required WriteStamp stamp,
  }) async {
    final existing = await find(
      link,
      reminderId: currentReminderId,
      adoptLinked: adoptLinked,
    );
    String id;
    if (existing != null) {
      id = existing.id;
      await _dao.updateReminder(
        id,
        RemindersCompanion(
          title: Value(title),
          triggerAt: Value(at),
          repeatRule: Value(repeatRule),
          snoozedUntil: const Value(null),
          completedAt: const Value(null),
          isEnabled: const Value(true),
          linkedItemId: Value(link.id),
          linkedItemType: Value(link.type.key),
        ),
        stamp,
      );
    } else {
      id = _newId();
      await _dao.insertReminder(
        RemindersCompanion.insert(
          id: id,
          createdAt: stamp.now,
          updatedAt: stamp.now,
          triggerAt: at,
          title: Value(title),
          repeatRule: Value(repeatRule),
          linkedItemId: Value(link.id),
          linkedItemType: Value(link.type.key),
          notificationId: await _dao.allocateNotificationId(id),
          sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
          syncVersion: const Value(1),
          deviceId: Value(stamp.deviceId),
        ),
      );
    }
    if (hasReminderColumn(link.type) && currentReminderId != id) {
      await _items.updateItems(
        link.type,
        [link.id],
        {'reminder_id': Variable.withString(id)},
        stamp,
      );
    }
    return id;
  }

  /// Removes the reminder of [link] ([reminderId] or, when null, all
  /// reminders linked to it) and clears the item's `reminder_id`.
  ///
  /// Active reminders are deleted for good (they are the item's own
  /// setting, e.g. "Remind me" switched off). Reminders the user already
  /// archived or trashed stay where they are — only the link is cleared.
  Future<void> remove(
    ItemRef link, {
    String? reminderId,
    required WriteStamp stamp,
  }) async {
    final rows = reminderId != null
        ? [?await _dao.rowById(reminderId)]
        : await _dao.rowsLinkedTo(link.type.key, link.id);
    await deleteRows(rows.where((r) => !isInactive(r)).map((r) => r.id));
    if (hasReminderColumn(link.type) && reminderId != null) {
      await _items.updateItems(
        link.type,
        [link.id],
        {'reminder_id': const Variable<String>(null)},
        stamp,
      );
    }
  }

  /// Hard-deletes reminder rows together with their tag links, attachment
  /// rows and inbox references (same cleanup as ItemsRepository's
  /// deleteForever), so no orphans are left behind.
  Future<void> deleteRows(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    await _org.deleteItemTagsOf(ItemType.reminder, list);
    await _org.deleteAttachmentsOf(ItemType.reminder, list);
    await _inbox.clearItemRefs(ItemType.reminder.key, list);
    await _dao.deleteReminders(list);
  }

  /// Marks the reminder [reminderId] done / not done (task completed /
  /// reopened) without deleting it.
  Future<void> setDone(
    String reminderId, {
    required bool done,
    required WriteStamp stamp,
  }) => _dao.updateReminder(
    reminderId,
    RemindersCompanion(
      completedAt: Value(done ? stamp.now : null),
      snoozedUntil: const Value(null),
    ),
    stamp,
  );

  /// Moves reminder [reminderId] to another item (a repeating task's next
  /// occurrence) and reschedules it.
  Future<void> relink(
    String reminderId,
    ItemRef to, {
    required String title,
    required DateTime at,
    required WriteStamp stamp,
  }) => _dao.updateReminder(
    reminderId,
    RemindersCompanion(
      linkedItemId: Value(to.id),
      linkedItemType: Value(to.type.key),
      title: Value(title),
      triggerAt: Value(at),
      completedAt: const Value(null),
      snoozedUntil: const Value(null),
      isEnabled: const Value(true),
    ),
    stamp,
  );
}
