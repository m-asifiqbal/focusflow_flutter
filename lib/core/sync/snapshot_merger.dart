/// ============================================================
/// SNAPSHOT MERGER — Merge restore / sync: last-write-wins per item
/// ============================================================
///
/// Folds an incoming [DbSnapshot] (another device's backup, or an older
/// backup of this one) into the local database without losing local work:
///
/// * Items (notes, tasks, reminders, habits, vault items): the newer
///   `updated_at` wins (then `sync_version`, then `device_id` — see
///   [incomingWins]); the winning row is copied as-is, *keeping* its
///   `sync_version`. A local tombstone newer than the incoming row means
///   "deleted here later" → the row is skipped.
/// * Children follow their parent: when the incoming item wins, its
///   subtasks, item tags and attachment rows replace the local ones;
///   otherwise the local children stay.
/// * Habit logs: last-write-wins per (habit, day) — log ids differ between
///   devices. Medicine doses: last-write-wins per id (their ids are natural
///   keys, the same on every device). Vault password history and focus
///   sessions: union.
/// * Folders / tags: last-write-wins by `updated_at`; a tag with the same
///   name but another id is the same tag (ids are remapped).
/// * Incoming tombstones delete local rows that are not newer than the
///   deletion ("a newer re-creation beats an older tombstone") and are
///   kept so the deletion keeps travelling.
///
/// Everything runs in one transaction; FTS is rebuilt afterwards.
/// ============================================================
library;

import 'package:drift/drift.dart' show Variable;
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/sync_tombstones.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/sync/merge_report.dart';
import 'package:focusflow/core/sync/merge_support.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';

class SnapshotMerger {
  SnapshotMerger({required this.db, required this.io, required this.items});

  final AppDatabase db;
  final SnapshotIo io;

  /// Permanent deletes (children, files, pointers) for incoming tombstones.
  final ItemsRepository items;

  /// Merges [incoming] into the database. [mergeVault] false leaves vault
  /// rows alone (incoming vault ciphertext under a different vault key).
  Future<MergeReport> merge(
    DbSnapshot incoming, {
    bool mergeVault = true,
  }) async {
    late MergeReport report;
    await db.transaction(() async {
      report = await _MergeRun(this, incoming, mergeVault).run();
    });
    await io.rebuildSearchIndexSafely();
    io.notifyChanged();
    return report;
  }
}

class _MergeRun {
  _MergeRun(this.m, this.incoming, this.mergeVault) : t = RawTables(m.db, m.io);

  final SnapshotMerger m;
  final DbSnapshot incoming;
  final bool mergeVault;
  final RawTables t;

  var _report = const MergeReport();
  final Set<String> _files = {};

  /// `entity|id` → local tombstone row.
  late final Map<String, RawRow> _tombs;

  /// Incoming tag id → local tag id (same name, different id).
  final Map<String, String> _tagMap = {};

  /// Item type key → ids whose incoming version was applied.
  final Map<String, Set<String>> _winners = {};

  Future<MergeReport> run() async {
    _tombs = await t.load(
      'tombstones',
      keyOf: (r) => '${r['entity']}|${r['entity_id']}',
    );
    await _mergeFolders();
    await _mergeTags();
    for (final e in kItemTables.entries) {
      if (e.key == ItemType.vault.key && !mergeVault) {
        _report = _report.copyWith(vaultSkipped: incoming.rows(e.value).length);
        continue;
      }
      await _mergeItems(e.key, e.value);
    }
    await _mergeChildren();
    await _mergeHabitLogs();
    await _mergeMedicineDoses();
    await _mergeUnion(
      'vault_history',
      parentTable: 'vault_items',
      parentCol: 'item_id',
    );
    await _mergeFocusSessions();
    await _applyTombstones();
    return _report.copyWith(filesNeeded: _files);
  }

  /// A local tombstone at least as new as [updatedAt] → deleted here later.
  bool _deletedLater(String entity, String id, Object? updatedAt) {
    final tomb = _tombs['$entity|$id'];
    return tomb != null && rawTime(tomb['deleted_at']) >= rawTime(updatedAt);
  }

  // ───────────────────────── Folders / tags ─────────────────────────

  Future<void> _mergeFolders() async {
    final local = await t.load('folders');
    for (final row in incoming.rows('folders')) {
      final id = row['id'].toString();
      final mine = local[id];
      if (mine == null) {
        if (_deletedLater('folder', id, row['updated_at'])) continue;
        await t.insert('folders', row);
      } else if (!DbSnapshot.rowsEqual(mine, row) && incomingWins(row, mine)) {
        await t.update('folders', row, where: {'id': id});
      }
    }
  }

  Future<void> _mergeTags() async {
    final local = await t.load('tags');
    final byName = {for (final r in local.values) r['name'].toString(): r};
    for (final row in incoming.rows('tags')) {
      final id = row['id'].toString();
      final name = row['name'].toString();
      final mine = local[id];
      if (mine != null) {
        if (DbSnapshot.rowsEqual(mine, row) || !incomingWins(row, mine)) {
          continue;
        }
        final clash = byName[name];
        final renameOk = clash == null || clash['id'] == id;
        await t.update(
          'tags',
          row,
          where: {'id': id},
          only: renameOk ? const {} : const {'color_hex', 'updated_at'},
        );
        continue;
      }
      final same = byName[name];
      if (same != null) {
        _tagMap[id] = same['id'].toString();
        if (incomingWins(row, same)) {
          await t.update(
            'tags',
            row,
            where: {'id': same['id']},
            only: const {'color_hex', 'updated_at'},
          );
        }
        continue;
      }
      if (_deletedLater('tag', id, row['updated_at'])) continue;
      await t.insert('tags', row);
      byName[name] = row;
    }
  }

  // ───────────────────────────── Items ─────────────────────────────

  Future<void> _mergeItems(String type, String table) async {
    final local = await t.load(table);
    final winners = _winners.putIfAbsent(type, () => {});
    var r = _report;
    for (final row in incoming.rows(table)) {
      final id = row['id'].toString();
      final mine = local[id];
      if (mine == null) {
        if (_deletedLater(type, id, row['updated_at'])) {
          r = r.copyWith(skipped: r.skipped + 1);
          continue;
        }
        await t.insert(table, row);
        winners.add(id);
        r = r.copyWith(added: r.added + 1);
      } else if (DbSnapshot.rowsEqual(
        mine,
        row,
        ignore: const {'last_synced_at'},
      )) {
        continue;
      } else if (incomingWins(row, mine)) {
        await t.update(table, row, where: {'id': id});
        winners.add(id);
        r = r.copyWith(updated: r.updated + 1);
      } else {
        r = r.copyWith(keptLocal: r.keptLocal + 1);
      }
      if (winners.contains(id) && table == 'notes') {
        final cover = row['cover_image_path'];
        if (cover is String && cover.isNotEmpty) _files.add(cover);
      }
    }
    _report = r;
  }

  /// Subtasks, item tags and attachments of winning items replace the
  /// local ones.
  Future<void> _mergeChildren() async {
    final winningTasks = _winners[ItemType.task.key] ?? const {};
    for (final id in winningTasks) {
      await t.delete('subtasks', {'task_id': id});
    }
    for (final row in incoming.rows('subtasks')) {
      if (winningTasks.contains(row['task_id'])) {
        await t.insert('subtasks', row, orIgnore: true);
      }
    }

    bool wins(RawRow r) =>
        _winners[r['item_type']]?.contains(r['item_id']) ?? false;
    for (final e in _winners.entries) {
      for (final id in e.value) {
        await t.delete('item_tags', {'item_id': id, 'item_type': e.key});
        await t.delete('attachments', {'item_id': id, 'item_type': e.key});
      }
    }
    final tags = await t.load('tags');
    for (final row in incoming.rows('item_tags')) {
      if (!wins(row)) continue;
      final tagId = _tagMap[row['tag_id']] ?? row['tag_id'].toString();
      if (!tags.containsKey(tagId)) continue;
      await t.insert('item_tags', {...row, 'tag_id': tagId}, orIgnore: true);
    }
    for (final row in incoming.rows('attachments')) {
      if (!wins(row)) continue;
      await t.insert('attachments', row, orIgnore: true);
      final path = row['local_path'];
      if (path is String && path.isNotEmpty) _files.add(path);
    }
  }

  /// Last-write-wins per (habit, day); the local log id is kept.
  Future<void> _mergeHabitLogs() async {
    final habits = await t.load('habits');
    final local = await t.load(
      'habit_logs',
      keyOf: (r) => habitLogKey(r['habit_id'].toString(), r['date'].toString()),
    );
    for (final row in incoming.rows('habit_logs')) {
      final habitId = row['habit_id'].toString();
      if (!habits.containsKey(habitId)) continue;
      final key = habitLogKey(habitId, row['date'].toString());
      final mine = local[key];
      if (mine == null) {
        if (_deletedLater('habit_log', key, row['updated_at'])) continue;
        await t.insert('habit_logs', row, orIgnore: true);
      } else if (rawTime(row['updated_at']) > rawTime(mine['updated_at'])) {
        await t.update(
          'habit_logs',
          row,
          where: {'id': mine['id']},
          only: const {'count', 'skipped', 'note', 'updated_at'},
        );
      }
    }
  }

  /// Last-write-wins per dose id, for doses whose medicine exists locally.
  Future<void> _mergeMedicineDoses() async {
    final medicines = await t.load('medicines');
    final local = await t.load('medicine_doses');
    for (final row in incoming.rows('medicine_doses')) {
      if (!medicines.containsKey(row['medicine_id'].toString())) continue;
      final id = row['id'].toString();
      final mine = local[id];
      if (mine == null) {
        if (_deletedLater('medicine_dose', id, row['updated_at'])) continue;
        await t.insert('medicine_doses', row, orIgnore: true);
      } else if (rawTime(row['updated_at']) > rawTime(mine['updated_at'])) {
        await t.update(
          'medicine_doses',
          row,
          where: {'id': id},
          only: const {
            'status',
            'taken_at',
            'quantity',
            'snoozed_until',
            'updated_at',
          },
        );
      }
    }
  }

  /// Insert-only union by id for rows whose parent exists locally.
  Future<void> _mergeUnion(
    String table, {
    required String parentTable,
    required String parentCol,
  }) async {
    if (table == 'vault_history' && !mergeVault) return;
    final parents = await t.load(parentTable);
    final local = await t.load(table);
    for (final row in incoming.rows(table)) {
      if (local.containsKey(row['id'].toString())) continue;
      if (!parents.containsKey(row[parentCol].toString())) continue;
      await t.insert(table, row, orIgnore: true);
    }
  }

  Future<void> _mergeFocusSessions() async {
    final local = await t.load('focus_sessions');
    for (final row in incoming.rows('focus_sessions')) {
      final id = row['id'].toString();
      if (local.containsKey(id) || _tombs.containsKey('focus_session|$id')) {
        continue;
      }
      await t.insert('focus_sessions', row, orIgnore: true);
    }
  }

  // ─────────────────────────── Tombstones ───────────────────────────

  Future<void> _applyTombstones() async {
    final itemDeletes = <ItemType, List<String>>{};
    final keep = <RawRow>[];
    for (final tomb in incoming.rows('tombstones')) {
      final entity = tomb['entity'].toString();
      final id = tomb['entity_id'].toString();
      final at = rawTime(tomb['deleted_at']);
      final type = ItemType.fromKey(entity);
      if (type != null) {
        if (type == ItemType.vault && !mergeVault) continue;
        final row = await t.byId(kItemTables[entity]!, id);
        if (row != null) {
          if (rawTime(row['updated_at']) > at) continue; // re-created later
          (itemDeletes[type] ??= []).add(id);
        }
        keep.add(tomb);
        continue;
      }
      switch (entity) {
        case 'tag':
          final row = await t.byId('tags', id);
          if (row != null && rawTime(row['updated_at']) > at) continue;
          if (row != null) {
            await t.delete('item_tags', {'tag_id': id});
            await t.delete('tags', {'id': id});
          }
        case 'folder':
          final row = await t.byId('folders', id);
          if (row != null && rawTime(row['updated_at']) > at) continue;
          if (row != null) await t.delete('folders', {'id': id});
        case 'focus_session':
          await t.delete('focus_sessions', {'id': id});
        case 'medicine_dose':
          final row = await t.byId('medicine_doses', id);
          if (row != null && rawTime(row['updated_at']) > at) continue;
          if (row != null) await t.delete('medicine_doses', {'id': id});
        case 'habit_log':
          final sep = id.lastIndexOf('|');
          if (sep <= 0) continue;
          final where = {
            'habit_id': id.substring(0, sep),
            'date': id.substring(sep + 1),
          };
          final rows = await m.db
              .customSelect(
                'SELECT updated_at FROM habit_logs WHERE habit_id = ? AND date = ?',
                variables: [
                  for (final v in where.values) Variable.withString(v),
                ],
              )
              .get();
          if (rows.isNotEmpty && rawTime(rows.first.data['updated_at']) > at) {
            continue;
          }
          await t.delete('habit_logs', where);
        default:
          continue;
      }
      keep.add(tomb);
    }
    var deleted = 0;
    for (final e in itemDeletes.entries) {
      await m.items.deleteForever([
        for (final id in e.value) ItemRef(e.key, id),
      ]);
      deleted += e.value.length;
    }
    for (final tomb in keep) {
      await t.upsertTombstone(tomb);
    }
    _report = _report.copyWith(deleted: _report.deleted + deleted);
  }
}
