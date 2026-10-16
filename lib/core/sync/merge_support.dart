/// ============================================================
/// MERGE SUPPORT — raw-row helpers shared by the snapshot merger
/// ============================================================
///
/// Last-write-wins ordering, table loading and generic INSERT / UPDATE of
/// raw rows (only columns this schema knows are written, so older backups
/// merge into newer schemas). Internal to core/sync.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';

/// Unix seconds of a raw DateTime value (Drift stores seconds).
int rawTime(Object? v) => v is num ? v.toInt() : 0;

/// True when [incoming] beats [local] under last-write-wins:
/// newer `updated_at`, then higher `sync_version`, then the larger
/// `device_id` — a total order, so two devices merging each other's
/// backups always converge on the same winner.
bool incomingWins(RawRow incoming, RawRow local) {
  final a = rawTime(incoming['updated_at']);
  final b = rawTime(local['updated_at']);
  if (a != b) return a > b;
  final va = rawTime(incoming['sync_version']);
  final vb = rawTime(local['sync_version']);
  if (va != vb) return va > vb;
  final da = incoming['device_id']?.toString() ?? '';
  final db = local['device_id']?.toString() ?? '';
  return da.compareTo(db) > 0;
}

/// Raw-row table access for one merge (column lists cached).
class RawTables {
  RawTables(this.db, this.io);

  final AppDatabase db;
  final SnapshotIo io;
  final Map<String, Set<String>> _columns = {};

  Future<Set<String>> columns(String table) async =>
      _columns[table] ??= (await io.columnsOf(table)).toSet();

  /// Every row of [table] keyed by [keyOf].
  Future<Map<String, RawRow>> load(
    String table, {
    String Function(RawRow r)? keyOf,
  }) async {
    final rows = await db.customSelect('SELECT * FROM $table').get();
    final key = keyOf ?? (r) => r['id'].toString();
    return {for (final r in rows) key(r.data): Map<String, Object?>.of(r.data)};
  }

  Future<RawRow?> byId(String table, String id) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM $table WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows.isEmpty ? null : Map<String, Object?>.of(rows.first.data);
  }

  Future<void> insert(String table, RawRow row, {bool orIgnore = false}) async {
    final known = await columns(table);
    final cols = row.keys.where(known.contains).toList();
    if (cols.isEmpty) return;
    await db.customStatement(
      'INSERT ${orIgnore ? 'OR IGNORE ' : ''}INTO $table (${cols.join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})',
      [for (final c in cols) row[c]],
    );
  }

  /// Overwrites the row identified by [where] (column → value) with
  /// [row]'s values (key columns untouched).
  Future<void> update(
    String table,
    RawRow row, {
    required Map<String, Object?> where,
    Set<String> only = const {},
  }) async {
    final known = await columns(table);
    final cols = row.keys
        .where(known.contains)
        .where((c) => !where.containsKey(c))
        .where((c) => only.isEmpty || only.contains(c))
        .toList();
    if (cols.isEmpty) return;
    await db.customStatement(
      'UPDATE $table SET ${cols.map((c) => '$c = ?').join(', ')} '
      'WHERE ${where.keys.map((c) => '$c = ?').join(' AND ')}',
      [for (final c in cols) row[c], ...where.values],
    );
  }

  Future<void> delete(
    String table,
    Map<String, Object?> where,
  ) => db.customStatement(
    'DELETE FROM $table WHERE ${where.keys.map((c) => '$c = ?').join(' AND ')}',
    where.values.toList(),
  );

  /// Records a deletion that arrived from another device, keeping the
  /// original time (the trigger stamped "now") and the latest one if the
  /// key was already tombstoned.
  Future<void> upsertTombstone(RawRow tomb) => db.customStatement(
    'INSERT INTO tombstones (entity, entity_id, deleted_at, device_id) '
    'VALUES (?, ?, ?, ?) ON CONFLICT(entity, entity_id) DO UPDATE SET '
    'deleted_at = excluded.deleted_at, device_id = excluded.device_id '
    'WHERE excluded.deleted_at > tombstones.deleted_at OR '
    "tombstones.device_id = ''",
    [
      tomb['entity'],
      tomb['entity_id'],
      tomb['deleted_at'],
      tomb['device_id'] ?? '',
    ],
  );
}
