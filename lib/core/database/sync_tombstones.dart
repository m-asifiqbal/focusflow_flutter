/// ============================================================
/// SYNC TOMBSTONES — SQL triggers that remember hard deletes
/// ============================================================
///
/// Backup merge (core/sync) is last-write-wins per row. A row that was
/// deleted *for good* (permanent delete, the 30-day purge, clearing a habit
/// day, deleting a tag) would otherwise come back from any older backup.
/// Instead of asking every repository to remember that, the database does
/// it: for each synced table an AFTER DELETE trigger writes a
/// `tombstones` row and an AFTER INSERT trigger clears it again when the
/// same key reappears (undo, re-log, a restore that brings it back).
///
/// Time comes from SQLite (`strftime('%s','now')`, unix seconds like Drift
/// stores DateTimes) and `device_id` is '' — the next backup stamps it with
/// this device's id (see SnapshotIo).
///
/// Child rows that always travel with their parent item (subtasks,
/// item_tags, attachments, vault_history) are resolved through the parent
/// and need no tombstones.
/// ============================================================
library;

/// (table, tombstone entity, SQL expression of the key over `old.` / `new.`).
const List<(String, String, String)> tombstoneSources = [
  ('notes', 'note', '{r}.id'),
  ('tasks', 'task', '{r}.id'),
  ('reminders', 'reminder', '{r}.id'),
  ('habits', 'habit', '{r}.id'),
  ('vault_items', 'vault', '{r}.id'),
  ('tags', 'tag', '{r}.id'),
  ('folders', 'folder', '{r}.id'),
  ('focus_sessions', 'focus_session', '{r}.id'),
  // Habit logs merge per (habit, day): log ids differ between devices.
  ('habit_logs', 'habit_log', "{r}.habit_id || '|' || {r}.date"),
];

/// Tombstone key of a habit log (matches the trigger expression above).
String habitLogKey(String habitId, String date) => '$habitId|$date';

/// CREATE TRIGGER statements (idempotent: `IF NOT EXISTS`).
List<String> tombstoneTriggerStatements() {
  final out = <String>[];
  for (final (table, entity, keyExpr) in tombstoneSources) {
    final oldKey = keyExpr.replaceAll('{r}', 'old');
    final newKey = keyExpr.replaceAll('{r}', 'new');
    out
      ..add(
        'CREATE TRIGGER IF NOT EXISTS tomb_${table}_ad AFTER DELETE ON $table '
        'BEGIN '
        "DELETE FROM tombstones WHERE entity = '$entity' AND entity_id = $oldKey; "
        'INSERT INTO tombstones (entity, entity_id, deleted_at, device_id) '
        "VALUES ('$entity', $oldKey, CAST(strftime('%s','now') AS INTEGER), ''); "
        'END',
      )
      ..add(
        'CREATE TRIGGER IF NOT EXISTS tomb_${table}_ai AFTER INSERT ON $table '
        'BEGIN '
        "DELETE FROM tombstones WHERE entity = '$entity' AND entity_id = $newKey; "
        'END',
      );
  }
  return out;
}
