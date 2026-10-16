/// ============================================================
/// SNAPSHOT IO — read the database into a [DbSnapshot] / replace it
/// ============================================================
///
/// The backup engine's only raw-SQL touch point with the item tables
/// (besides the merger): generic over [kSnapshotTables] so a schema change
/// needs no code here.
///
/// * [read] stamps this device's id onto tombstones the SQL triggers left
///   blank, then dumps every table (`SELECT *`, rowid order).
/// * [replaceAll] is a *Replace* restore: inside one transaction it empties
///   every synced table, drops the tombstones those deletes produced (a
///   wipe is not a user deletion — it must never propagate to other
///   devices), inserts the snapshot's rows and its own tombstones, then
///   rebuilds the FTS indexes.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/utils/app_logger.dart';

class SnapshotIo {
  SnapshotIo(this.db, {required this.deviceId});

  final AppDatabase db;
  final String deviceId;

  /// Every synced table as raw rows.
  Future<DbSnapshot> read() => db.transaction(() async {
    await db.customStatement(
      "UPDATE tombstones SET device_id = ? WHERE device_id = ''",
      [deviceId],
    );
    final tables = <String, List<RawRow>>{};
    for (final table in kSnapshotTables) {
      final rows = await db
          .customSelect('SELECT * FROM $table ORDER BY rowid')
          .get();
      tables[table] = [for (final r in rows) Map<String, Object?>.of(r.data)];
    }
    return DbSnapshot(tables);
  });

  /// Current column names of [table] (schema of this app version).
  Future<List<String>> columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  /// Replace restore — see the file header.
  Future<void> replaceAll(DbSnapshot snapshot) async {
    await db.transaction(() async {
      for (final table in kSnapshotTables.reversed) {
        await db.customStatement('DELETE FROM $table');
      }
      // The deletes above fired the tombstone triggers; a wipe is not a
      // deletion anyone made, so forget those before loading.
      await db.customStatement('DELETE FROM tombstones');
      for (final table in kSnapshotTables) {
        await insertRows(table, snapshot.rows(table));
      }
    });
    await rebuildSearchIndexSafely();
    _notifyAll();
  }

  /// Rebuilds the FTS indexes after a committed restore / merge. A failure
  /// here must not report the (already committed) restore as failed: the
  /// items are in place, only search may lag until the next rebuild.
  Future<void> rebuildSearchIndexSafely() async {
    try {
      await db.rebuildSearchIndex();
    } on Object catch (e) {
      AppLogger.w('Search index rebuild failed (${e.runtimeType})');
    }
  }

  /// Inserts raw [rows] into [table], keeping only columns this schema has.
  Future<void> insertRows(String table, List<RawRow> rows) async {
    if (rows.isEmpty) return;
    final known = (await columnsOf(table)).toSet();
    // Group by column set so one prepared statement serves many rows.
    final groups = <String, List<RawRow>>{};
    for (final r in rows) {
      final cols = r.keys.where(known.contains).toList();
      groups.putIfAbsent(cols.join(','), () => []).add(r);
    }
    await db.batch((b) {
      for (final e in groups.entries) {
        if (e.key.isEmpty) continue;
        final cols = e.key.split(',');
        final sql =
            'INSERT INTO $table (${cols.join(', ')}) '
            'VALUES (${List.filled(cols.length, '?').join(', ')})';
        for (final r in e.value) {
          b.customStatement(sql, [for (final c in cols) r[c]]);
        }
      }
    });
  }

  /// Tells Drift every synced table changed, so open streams re-query.
  void _notifyAll() {
    db.notifyUpdates({
      for (final t in db.allTables)
        if (kSnapshotTables.contains(t.actualTableName))
          TableUpdate.onTable(t, kind: UpdateKind.update),
    });
  }

  /// Notifies streams after a merge (same as [replaceAll]).
  void notifyChanged() => _notifyAll();
}
