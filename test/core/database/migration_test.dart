/// Schema migration v1 → v2: `tombstones` + the hard-delete triggers.
///
/// There is no stored v1 snapshot, so the test builds one the way a v1
/// install looks on disk: a current database with everything v2 added
/// removed again (the tombstones table and its triggers) and
/// `user_version = 1`. Re-opening it with [AppDatabase] must run the
/// `from < 2` step, keep existing rows and leave working triggers.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:focusflow/core/database/sync_tombstones.dart';
import 'package:sqlite3/sqlite3.dart';

const _key =
    'b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1';

AppDatabase _open(File file) => AppDatabase(
  NativeDatabase(file, setup: (raw) => EncryptedDatabase.applyKey(raw, _key)),
);

/// Rewrites [file] into its v1 shape.
void _downgradeToV1(File file) {
  final raw = sqlite3.open(file.path);
  try {
    EncryptedDatabase.applyKey(raw, _key);
    final triggers = raw
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'tomb_%'",
        )
        .map((r) => r['name'] as String)
        .toList();
    for (final t in triggers) {
      raw.execute('DROP TRIGGER $t');
    }
    raw
      ..execute('DROP TABLE tombstones')
      ..execute('PRAGMA user_version = 1');
  } finally {
    raw.close();
  }
}

Future<Set<String>> _names(AppDatabase db, String type) async {
  final rows = await db
      .customSelect(
        'SELECT name FROM sqlite_master WHERE type = ?',
        variables: [Variable.withString(type)],
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ff_migration');
    file = File('${dir.path}/focusflow.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('v1 database upgrades to v2 with tombstones and triggers', () async {
    final now = DateTime(2026, 3, 1, 9);
    // 1. Create a database and put data in it, then turn it into v1.
    var db = _open(file);
    await db.into(db.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        createdAt: now,
        updatedAt: now,
        title: const Value('Kept across the upgrade'),
      ),
    );
    await db.into(db.tags).insert(
      TagsCompanion.insert(id: 't1', name: 'work', createdAt: now, updatedAt: now),
    );
    await db.close();
    _downgradeToV1(file);

    // Sanity: the file really is v1 now.
    final check = sqlite3.open(file.path);
    EncryptedDatabase.applyKey(check, _key);
    expect(check.select('PRAGMA user_version').first.values.first, 1);
    expect(
      check.select(
        "SELECT name FROM sqlite_master WHERE name = 'tombstones'",
      ),
      isEmpty,
    );
    check.close();

    // 2. Re-open with the current schema → onUpgrade(from: 1).
    db = _open(file);
    addTearDown(db.close);

    final tables = await _names(db, 'table');
    expect(tables, containsAll(['notes', 'tags', 'tombstones']));
    final triggers = await _names(db, 'trigger');
    for (final (table, _, _) in tombstoneSources) {
      expect(triggers, contains('tomb_${table}_ad'));
      expect(triggers, contains('tomb_${table}_ai'));
    }
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, db.schemaVersion);

    // 3. Existing rows survived and the FTS index still works.
    final notes = await db.select(db.notes).get();
    expect(notes.single.title, 'Kept across the upgrade');
    final hits = await db
        .customSelect(
          "SELECT rowid FROM notes_fts WHERE notes_fts MATCH 'upgrade'",
        )
        .get();
    expect(hits, hasLength(1));

    // 4. The new triggers record hard deletes and clear on re-insert.
    await (db.delete(db.notes)..where((n) => n.id.equals('n1'))).go();
    await (db.delete(db.tags)..where((t) => t.id.equals('t1'))).go();
    var tombs = await db.select(db.tombstones).get();
    expect(
      tombs.map((t) => '${t.entity}:${t.entityId}').toSet(),
      {'note:n1', 'tag:t1'},
    );
    await db.into(db.notes).insert(
      NotesCompanion.insert(id: 'n1', createdAt: now, updatedAt: now),
    );
    tombs = await db.select(db.tombstones).get();
    expect(tombs.map((t) => t.entity), ['tag']);
  });

  test('a fresh install creates the v2 schema directly', () async {
    final db = _open(file);
    addTearDown(db.close);
    expect(await _names(db, 'table'), contains('tombstones'));
    final now = DateTime(2026, 3, 1);
    await db.into(db.habitLogs).insert(
      HabitLogsCompanion.insert(
        id: 'l1',
        habitId: 'h1',
        date: '2026-03-01',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.delete(db.habitLogs).go();
    final tomb = await db.select(db.tombstones).getSingle();
    expect(tomb.entity, 'habit_log');
    expect(tomb.entityId, habitLogKey('h1', '2026-03-01'));
  });
}
