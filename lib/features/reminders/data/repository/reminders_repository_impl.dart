/// ============================================================
/// REMINDERS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Reads active reminders (plus their tags and linked titles) with one SQL
/// query, then applies the time-based scope in Dart through the pure
/// [ReminderSchedule] — repeating reminders must be expanded into
/// occurrences, which SQL can't do. Reminder counts are small (hundreds),
/// so this stays cheap.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/reminders_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/reminders/data/repository/linked_reminders.dart';
import 'package:focusflow/features/reminders/data/repository/reminder_mapper.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/data/repository/task_mapper.dart';

class RemindersRepositoryImpl extends RepositoryBase
    implements RemindersRepository {
  RemindersRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = RemindersDao(db),
       _org = OrganisationDao(db),
       _linked = LinkedReminders(db, newId),
       _tags = TagWriter(OrganisationDao(db), newId);

  final RemindersDao _dao;
  final OrganisationDao _org;
  final LinkedReminders _linked;
  final TagWriter _tags;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.reminders,
    db.tasks,
    db.notes,
    db.habits,
    db.vaultItems,
    db.itemTags,
    db.tags,
  };

  // ───────────────────────────── Reading ──────────────────────────────

  /// Active reminders matching the text / tag filters, mapped with tags.
  Future<List<Reminder>> _load({
    String text = '',
    String? tagId,
    String extraWhere = '',
    bool onlyVisibleLinks = true,
  }) async {
    final where = <String>[activeSql('r')];
    final vars = <Variable>[];
    final q = text.trim();
    if (q.isNotEmpty) {
      where.add(r"(r.title LIKE ? ESCAPE '\' OR r.note LIKE ? ESCAPE '\')");
      final like = likeContains(q);
      vars
        ..add(Variable.withString(like))
        ..add(Variable.withString(like));
    }
    if (tagId != null) {
      where.add(
        "EXISTS (SELECT 1 FROM item_tags it WHERE it.item_type = 'reminder' "
        'AND it.item_id = r.id AND it.tag_id = ?)',
      );
      vars.add(Variable.withString(tagId));
    }
    if (extraWhere.isNotEmpty) where.add(extraWhere);
    final rows = await _dao
        .queryReminders(
          where: where.join(' AND '),
          variables: vars,
          onlyVisibleLinks: onlyVisibleLinks,
        )
        .get();
    final tags = await _org.tagsByItem(
      ItemType.reminder,
      itemIds: rows.map((r) => r.row.id),
    );
    return [
      for (final r in rows)
        ReminderMapper.fromRow(
          r.row,
          linkedTitle: r.linkedTitle,
          tags: ItemMappers.tags(tags[r.row.id]),
        ),
    ];
  }

  static List<ReminderOccurrence> _sorted(List<ReminderOccurrence> list) =>
      list..sort((a, b) {
        final c = a.at.compareTo(b.at);
        return c != 0 ? c : a.reminder.title.compareTo(b.reminder.title);
      });

  List<ReminderOccurrence> _applyScope(
    List<Reminder> all,
    RemindersQuery query,
  ) {
    final now = query.now ?? clock.now();
    switch (query.scope) {
      case RemindersScope.today:
        final day = DateUtilsX.dateOnly(query.day ?? now);
        final end = DateUtilsX.addDays(day, 1);
        return _sorted([
          for (final r in all) ...ReminderSchedule.between(r, day, end),
        ]);
      case RemindersScope.upcoming:
        return _sorted([for (final r in all) ?ReminderSchedule.next(r, now)]);
      case RemindersScope.recurring:
        return _sorted([
          for (final r in all)
            if (r.isRecurring) ReminderSchedule.current(r, now),
        ]);
      case RemindersScope.location:
        return _sorted([
          for (final r in all)
            if (r.hasLocation) ReminderSchedule.current(r, now),
        ]);
      case RemindersScope.snoozed:
        return _sorted([
          for (final r in all)
            if (r.isSnoozed(now))
              ReminderOccurrence(reminder: r, at: r.snoozedUntil!),
        ]);
      case RemindersScope.missed:
        return _sorted([
          for (final r in all)
            if (r.isMissed(now))
              ReminderOccurrence(reminder: r, at: r.effectiveTriggerAt),
        ]);
      case RemindersScope.all:
        return _sorted([for (final r in all) ReminderSchedule.current(r, now)]);
    }
  }

  @override
  Stream<List<ReminderOccurrence>> watchReminders(RemindersQuery query) =>
      db.watchComputed(
        _tables,
        () async => _applyScope(
          await _load(text: query.text, tagId: query.tagId),
          query,
        ),
      );

  @override
  Stream<Reminder?> watchReminder(String id) =>
      db.watchComputed(_tables, () => getReminder(id));

  @override
  Future<Reminder?> getReminder(String id) async {
    final row = await _dao.reminderById(id).getSingleOrNull();
    if (row == null) return null;
    final tags = await _org.tagsOf(ItemType.reminder, id);
    return ReminderMapper.fromRow(
      row.row,
      linkedTitle: row.linkedTitle,
      tags: ItemMappers.tags(tags),
    );
  }

  @override
  Stream<ReminderOccurrence?> watchNext(DateTime now) =>
      db.watchComputed(_tables, () async {
        ReminderOccurrence? best;
        for (final r in await _load()) {
          final next = ReminderSchedule.next(r, now);
          if (next != null && (best == null || next.at.isBefore(best.at))) {
            best = next;
          }
        }
        return best;
      });

  @override
  Stream<List<ReminderOccurrence>> watchForDay(DateTime day) =>
      watchReminders(RemindersQuery(scope: RemindersScope.today, day: day));

  @override
  Stream<List<ReminderOccurrence>> watchInRange(DateTime from, DateTime to) =>
      db.watchComputed(
        _tables,
        () async => _sorted([
          for (final r in await _load())
            ...ReminderSchedule.between(r, from, to),
        ]),
      );

  @override
  Stream<List<Reminder>> watchSchedulable() => db.watchComputed(
    _tables,
    () => _load(
      extraWhere:
          'r.is_enabled = 1 AND NOT (r.completed_at IS NOT NULL AND '
          '(r.repeat_rule IS NULL OR r.repeat_rule = \'\'))',
    ),
  );

  // ───────────────────────────── Writing ──────────────────────────────

  @override
  Future<String> save(Reminder reminder) => db.transaction(() async {
    final s = stamp();
    final content = ReminderMapper.contentCompanion(reminder);
    var id = reminder.id;
    final existing = id.isEmpty ? null : await _dao.rowById(id);
    if (existing == null) {
      if (id.isEmpty) id = newId();
      await _dao.insertReminder(
        content.copyWith(
          id: Value(id),
          createdAt: Value(s.now),
          updatedAt: Value(s.now),
          notificationId: Value(
            reminder.notificationId > 0
                ? reminder.notificationId
                : await _dao.allocateNotificationId(id),
          ),
          sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
          syncVersion: const Value(1),
          deviceId: Value(deviceId),
        ),
      );
    } else {
      await _dao.updateReminder(id, content, s);
    }
    await _tags.replaceTags(
      ItemType.reminder,
      id,
      reminder.tags.map((t) => t.name),
      s,
    );
    // A note "Set reminder" points the note at its reminder.
    final link = reminder.linkedRef;
    if (link != null && link.type == ItemType.note) {
      await db.customUpdate(
        'UPDATE notes SET reminder_id = ?, updated_at = ?, device_id = ?, '
        'sync_version = sync_version + 1 WHERE id = ? AND reminder_id IS NULL',
        variables: [
          Variable.withString(id),
          Variable<DateTime>(s.now),
          Variable.withString(deviceId),
          Variable.withString(link.id),
        ],
        updates: {db.notes},
        updateKind: UpdateKind.update,
      );
    }
    return id;
  });

  Future<void> _update(String id, RemindersCompanion changes) =>
      _dao.updateReminder(id, changes, stamp());

  @override
  Future<void> setEnabled(String id, bool enabled) =>
      _update(id, RemindersCompanion(isEnabled: Value(enabled)));

  @override
  Future<void> snooze(String id, {int? minutes, DateTime? occurrence}) async {
    final row = await _dao.rowById(id);
    if (row == null) return;
    final m = minutes ?? row.snoozeMinutes;
    final now = this.now();
    final base = occurrence != null && occurrence.isAfter(now)
        ? occurrence
        : now;
    await snoozeUntil(
      id,
      base.add(Duration(minutes: m)),
      occurrence: occurrence,
    );
  }

  @override
  Future<void> snoozeUntil(String id, DateTime until, {DateTime? occurrence}) =>
      db.transaction(() async {
        final r = await getReminder(id);
        if (r == null) return;
        var changes = RemindersCompanion(snoozedUntil: Value(until));
        final later = laterOccurrence(r, occurrence);
        if (later != null) {
          // The snoozed occurrence becomes the pending one, so it fires at
          // [until] only — never also at its own rule time.
          final anchored = _anchorAt(r, later);
          changes = changes.copyWith(
            triggerAt: anchored.triggerAt,
            repeatRule: anchored.repeatRule,
          );
        }
        await _update(id, changes);
      });

  /// [occurrence] when it is a rule occurrence of repeating [r] *after* its
  /// pending one ([Reminder.triggerAt], e.g. a stale anchor nobody marked
  /// done); null for one-time reminders, the pending (or snoozed)
  /// occurrence, or anything that is not an occurrence of the rule.
  @visibleForTesting
  static DateTime? laterOccurrence(Reminder r, DateTime? occurrence) {
    final rule = r.recurrence;
    if (rule == null || occurrence == null) return null;
    if (!occurrence.isAfter(r.triggerAt)) return null;
    final snooze = r.snoozedUntil;
    if (snooze != null && snooze.isAtSameMomentAs(occurrence)) return null;
    final hits = rule.occurrencesBetween(
      r.triggerAt,
      occurrence,
      occurrence.add(const Duration(seconds: 1)),
    );
    return hits.any((t) => t.isAtSameMomentAs(occurrence)) ? occurrence : null;
  }

  /// Re-anchors repeating [r] at its later occurrence [at]: the ones in
  /// between are skipped (acting on an occurrence first catches the series
  /// up to it) and COUNT shrinks by the occurrences consumed.
  static ({Value<DateTime> triggerAt, Value<String?> repeatRule}) _anchorAt(
    Reminder r,
    DateTime at,
  ) {
    final rule = r.recurrence!;
    var newRule = rule;
    final count = rule.count;
    if (count != null) {
      final consumed = rule
          .occurrencesBetween(r.triggerAt, r.triggerAt, at)
          .length;
      newRule = rule.copyWith(
        count: count - consumed < 1 ? 1 : count - consumed,
      );
    }
    return (triggerAt: Value(at), repeatRule: Value(newRule.toRRule()));
  }

  @override
  Future<Reminder?> markDone(String id, {DateTime? occurrence}) =>
      db.transaction(() async {
        final before = await getReminder(id);
        if (before == null) return null;
        final now = this.now();
        final rule = before.recurrence;
        if (rule == null) {
          await _update(
            id,
            RemindersCompanion(
              completedAt: Value(now),
              snoozedUntil: const Value(null),
            ),
          );
          return before;
        }
        final anchor = before.triggerAt;
        final later = laterOccurrence(before, occurrence);
        final pending =
            occurrence == null ||
            occurrence.isAtSameMomentAs(before.effectiveTriggerAt) ||
            occurrence.isAtSameMomentAs(anchor);
        // An occurrence already behind the pending one (a done row): no-op.
        if (later == null && !pending) return null;
        // The occurrence being acknowledged: the tapped later one; else the
        // latest one already due, or the pending one when marking done early.
        var acknowledged = later ?? anchor;
        if (later == null && !anchor.isAfter(now)) {
          final windowStart = DateUtilsX.addDays(now, -400).isAfter(anchor)
              ? DateUtilsX.addDays(now, -400)
              : anchor;
          final past = rule.occurrencesBetween(
            anchor,
            windowStart,
            now.add(const Duration(seconds: 1)),
          );
          if (past.isNotEmpty) acknowledged = past.last;
        }
        final next = rule.nextAfter(anchor, acknowledged);
        if (next == null) {
          await _update(
            id,
            RemindersCompanion(
              repeatRule: const Value(null),
              triggerAt: Value(acknowledged),
              completedAt: Value(now),
              snoozedUntil: const Value(null),
            ),
          );
          return before;
        }
        var newRule = rule;
        final count = rule.count;
        if (count != null) {
          final consumed = rule.occurrencesBetween(anchor, anchor, next).length;
          newRule = rule.copyWith(
            count: count - consumed < 1 ? 1 : count - consumed,
          );
        }
        await _update(
          id,
          RemindersCompanion(
            triggerAt: Value(next),
            repeatRule: Value(newRule.toRRule()),
            completedAt: Value(acknowledged),
            snoozedUntil: const Value(null),
          ),
        );
        return before;
      });

  @override
  Future<void> markUndone(String id) =>
      _update(id, const RemindersCompanion(completedAt: Value(null)));

  @override
  Future<void> reschedule(String id, DateTime at) => _update(
    id,
    RemindersCompanion(
      triggerAt: Value(at),
      snoozedUntil: const Value(null),
      completedAt: const Value(null),
      isEnabled: const Value(true),
    ),
  );

  @override
  Future<void> markFired(String id, DateTime firedAt) =>
      _update(id, RemindersCompanion(lastFiredAt: Value(firedAt)));

  @override
  Future<int> resyncTaskReminders(
    WallClock target, {
    Iterable<WallClock> from = const [],
  }) => db.transaction(() async {
    final rows =
        await (db.select(db.tasks)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.archivedAt.isNull() &
                  t.completedAt.isNull() &
                  t.reminderId.isNotNull() &
                  t.remindOffsetMinutes.isNotNull() &
                  t.dueDate.isNotNull(),
            ))
            .get();
    var moved = 0;
    for (final row in rows) {
      final task = TaskMapper.fromRow((
        row: row,
        listName: null,
        linkedNoteTitle: null,
      ));
      final wall = task.reminderWallTime;
      final rid = task.reminderId;
      if (wall == null || rid == null) continue;
      final r = await _dao.rowById(rid);
      if (r == null ||
          LinkedReminders.isInactive(r) ||
          r.completedAt != null ||
          r.snoozedUntil != null ||
          (r.repeatRule?.isNotEmpty ?? false)) {
        continue;
      }
      final want = target(wall.day, wall.minutes);
      if (r.triggerAt.isAtSameMomentAs(want)) continue;
      // Only a reminder still at the task's own time (as computed in the
      // device zone or a previous planning zone) follows it; one the user
      // moved by hand stays where it is.
      final derived = [
        task.reminderAt!,
        for (final f in from) f(wall.day, wall.minutes),
      ];
      if (!derived.any(r.triggerAt.isAtSameMomentAs)) continue;
      await _update(rid, RemindersCompanion(triggerAt: Value(want)));
      moved++;
    }
    return moved;
  });

  // ───────────────────────── Linked reminders ─────────────────────────

  Future<String?> _itemReminderId(ItemRef link) async {
    if (!LinkedReminders.hasReminderColumn(link.type)) return null;
    final row = await db
        .customSelect(
          'SELECT reminder_id FROM ${db.itemTableName(link.type)} WHERE id = ?',
          variables: [Variable.withString(link.id)],
        )
        .getSingleOrNull();
    return row?.readNullable<String>('reminder_id');
  }

  @override
  Future<String> upsertLinkedReminder(
    ItemRef link, {
    required String title,
    required DateTime at,
    String? repeatRule,
  }) => db.transaction(
    () async => _linked.upsert(
      link,
      title: title,
      at: at,
      repeatRule: repeatRule,
      currentReminderId: await _itemReminderId(link),
      stamp: stamp(),
    ),
  );

  @override
  Future<void> removeLinkedReminder(ItemRef link) => db.transaction(
    () async => _linked.remove(
      link,
      reminderId: await _itemReminderId(link),
      stamp: stamp(),
    ),
  );

  @override
  Future<Reminder?> getLinkedReminder(ItemRef link) async {
    final row = await _linked.find(
      link,
      reminderId: await _itemReminderId(link),
    );
    return row == null ? null : getReminder(row.id);
  }
}
