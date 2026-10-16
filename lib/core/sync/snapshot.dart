/// ============================================================
/// DB SNAPSHOT — every synced table as raw rows (`db.json` of a backup)
/// ============================================================
///
/// A snapshot is the database content a `.ffbackup` carries: for each
/// table in [kSnapshotTables] the raw SQLite values of every row (ints for
/// DateTimes/bools exactly as Drift stores them, strings, doubles, blobs).
/// Working on raw values instead of Drift data classes keeps backups
/// lossless (backup → wipe → restore is byte-identical) and independent of
/// generated code, and lets an older backup restore into a newer schema
/// (missing columns take their defaults).
///
/// Not included (device-local, never synced): `generator_history` (vault
/// generator scratch values), `inbox_entries` (this device's fired
/// notifications) and `backup_records` (this device's backup history).
///
/// JSON shape (`db.json`):
/// ```json
/// {"format":1,"tables":{"notes":{"columns":["id",…],"rows":[["n1",…]]}}}
/// ```
/// Blobs are written as `{"b64":"…"}` (vault ciphertext stays ciphertext).
/// ============================================================
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/sync/backup_format.dart';

/// Tables in a backup, in an order that satisfies parent → child.
const List<String> kSnapshotTables = [
  'folders',
  'tags',
  'notes',
  'tasks',
  'subtasks',
  'reminders',
  'habits',
  'habit_logs',
  'vault_items',
  'vault_history',
  'item_tags',
  'attachments',
  'focus_sessions',
  'tombstones',
];

/// Item tables (shared lifecycle columns) by `ItemType.key`.
const Map<String, String> kItemTables = {
  'note': 'notes',
  'task': 'tasks',
  'reminder': 'reminders',
  'habit': 'habits',
  'vault': 'vault_items',
};

/// A raw row: SQL column name → SQLite value.
typedef RawRow = Map<String, Object?>;

@immutable
class DbSnapshot {
  DbSnapshot(Map<String, List<RawRow>> tables)
    : tables = Map.unmodifiable({
        for (final t in kSnapshotTables)
          t: List<RawRow>.unmodifiable(tables[t] ?? const []),
      });

  /// Table name → rows (every table of [kSnapshotTables] is present).
  final Map<String, List<RawRow>> tables;

  static const int formatVersion = 1;

  List<RawRow> rows(String table) => tables[table] ?? const [];

  /// Rows per table ("notes": 48 …) — shown in restore previews.
  Map<String, int> get counts => {
    for (final e in tables.entries) e.key: e.value.length,
  };

  /// Items not in Recently Deleted, per `ItemType.key` (archived count).
  Map<String, int> get itemCounts => {
    for (final e in kItemTables.entries)
      e.key: rows(e.value).where((r) => r['deleted_at'] == null).length,
  };

  /// Total of [itemCounts] — "113 items".
  int get itemCount => itemCounts.values.fold(0, (a, b) => a + b);

  /// UTF-8 JSON (`db.json`).
  Uint8List encode() {
    final out = <String, Object?>{};
    for (final table in kSnapshotTables) {
      final rows = this.rows(table);
      final columns = <String>{for (final r in rows) ...r.keys}.toList();
      out[table] = {
        'columns': columns,
        'rows': [
          for (final r in rows) [for (final c in columns) _encodeValue(r[c])],
        ],
      };
    }
    return Uint8List.fromList(
      utf8.encode(jsonEncode({'format': formatVersion, 'tables': out})),
    );
  }

  /// Parses [encode]'s output. Throws [FormatException] on bad input.
  static DbSnapshot decode(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw FormatException('db.json is not valid JSON ($e)');
    }
    if (json is! Map || json['tables'] is! Map) {
      throw const FormatException('db.json has no tables');
    }
    final format = json['format'];
    if (format is num && format > formatVersion) throw const BackupTooNew();
    final tables = <String, List<RawRow>>{};
    for (final e in (json['tables'] as Map).entries) {
      final name = e.key.toString();
      if (!kSnapshotTables.contains(name)) continue;
      final t = e.value;
      if (t is! Map || t['columns'] is! List || t['rows'] is! List) {
        throw FormatException('db.json table "$name" is malformed');
      }
      final columns = (t['columns'] as List).map((c) => c.toString()).toList();
      tables[name] = [
        for (final r in t['rows'] as List)
          if (r is List && r.length == columns.length)
            {
              for (var i = 0; i < columns.length; i++)
                columns[i]: _decodeValue(r[i]),
            }
          else
            throw FormatException('db.json table "$name" has a bad row'),
      ];
    }
    return DbSnapshot(tables);
  }

  static Object? _encodeValue(Object? v) =>
      v is Uint8List ? {'b64': base64Encode(v)} : v;

  static Object? _decodeValue(Object? v) {
    if (v is Map && v['b64'] is String) {
      return base64Decode(v['b64'] as String);
    }
    return v;
  }

  /// Deep equality of two raw rows (blobs compared by content).
  static bool rowsEqual(RawRow a, RawRow b, {Set<String> ignore = const {}}) {
    final keys = {...a.keys, ...b.keys}..removeAll(ignore);
    for (final k in keys) {
      final x = a[k];
      final y = b[k];
      if (x is Uint8List && y is Uint8List) {
        if (!const ListEquality<int>().equals(x, y)) return false;
      } else if (x is num && y is num) {
        if (x != y) return false;
      } else if (x != y) {
        return false;
      }
    }
    return true;
  }

  /// Snapshot equality (same tables, same rows in any order) — used by the
  /// round-trip tests and to skip no-op restores.
  bool sameContentAs(DbSnapshot other) {
    for (final table in kSnapshotTables) {
      final a = _sorted(rows(table));
      final b = _sorted(other.rows(table));
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!rowsEqual(a[i], b[i])) return false;
      }
    }
    return true;
  }

  static List<RawRow> _sorted(List<RawRow> rows) =>
      [...rows]..sort((x, y) => _key(x).compareTo(_key(y)));

  static String _key(RawRow r) =>
      r['id']?.toString() ??
      [r['entity'], r['entity_id'], r['item_id'], r['tag_id']].join('|');
}
