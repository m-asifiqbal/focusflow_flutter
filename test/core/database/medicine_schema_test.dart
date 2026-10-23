/// The medicine tables came after schema v3 without a version bump: they
/// are created on open (AppDatabase._ensureMedicineSchema). An install from
/// before them — at v3, or still at v1 (whose upgrade creates tombstone
/// triggers that now include the medicine tables) — must open, keep its
/// data and end up with the tables, their search index and their tombstone
/// triggers.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:sqlite3/sqlite3.dart';

const _key = 'c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2';

AppDatabase _open(File file) => AppDatabase(
  NativeDatabase(file, setup: (raw) => EncryptedDatabase.applyKey(raw, _key)),
);

/// Removes every medicine object, as on a device that never had them; for
/// [v1] also the v2 tombstones and v3 column, and sets `user_version`.
void _strip(File file, {bool v1 = false}) {
  final raw = sqlite3.open(file.path);
  try {
    EncryptedDatabase.applyKey(raw, _key);
    final drop = raw
        .select(
          "SELECT type, name FROM sqlite_master WHERE type = 'trigger' AND "
          "(name LIKE '%medicine%' ${v1 ? "OR name LIKE 'tomb_%'" : ''})",
        )
        .map((r) => r['name'] as String)
        .toList();
    for (final t in drop) {
      raw.execute('DROP TRIGGER $t');
    }
    raw
      ..execute('DROP TABLE medicines_fts')
      ..execute('DROP TABLE medicine_doses')
      ..execute('DROP TABLE medicines');
    if (v1) {
      raw
        ..execute('DROP TABLE tombstones')
        ..execute('ALTER TABLE notes DROP COLUMN lock_verifier')
        ..execute('PRAGMA user_version = 1');
    }
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

Future<void> _expectMedicineSchema(AppDatabase db) async {
  expect(
    await _names(db, 'table'),
    containsAll(['medicines', 'medicine_doses', 'medicines_fts']),
  );
  expect(
    await _names(db, 'trigger'),
    containsAll([
      'tomb_medicines_ad',
      'tomb_medicine_doses_ai',
      'medicines_fts_ai',
    ]),
  );
  // Usable: insert, search, and a hard delete leaves a tombstone.
  final now = DateTime(2026, 10, 23);
  await db
      .into(db.medicines)
      .insert(
        MedicinesCompanion.insert(
          id: 'm1',
          createdAt: now,
          updatedAt: now,
          startDate: '2026-10-23',
          name: const Value('Metformin'),
        ),
      );
  final hits = await db
      .customSelect(
        "SELECT rowid FROM medicines_fts WHERE medicines_fts MATCH 'metf*'",
      )
      .get();
  expect(hits, hasLength(1));
  await (db.delete(db.medicines)..where((m) => m.id.equals('m1'))).go();
  final tombs = await db.select(db.tombstones).get();
  expect(
    tombs.map((t) => '${t.entity}:${t.entityId}'),
    contains('medicine:m1'),
  );
}

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ff_medicine_schema');
    file = File('${dir.path}/focusflow.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> seedNote() async {
    final db = _open(file);
    final now = DateTime(2026, 3, 1);
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            createdAt: now,
            updatedAt: now,
            title: const Value('Kept'),
          ),
        );
    await db.close();
  }

  test('a v3 database without medicines gains them on open', () async {
    await seedNote();
    _strip(file);
    final db = _open(file);
    addTearDown(db.close);
    expect((await db.select(db.notes).getSingle()).title, 'Kept');
    await _expectMedicineSchema(db);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 3);
  });

  test('a v1 database upgrades with the medicine tables in place', () async {
    await seedNote();
    _strip(file, v1: true);
    final db = _open(file);
    addTearDown(db.close);
    expect((await db.select(db.notes).getSingle()).title, 'Kept');
    await _expectMedicineSchema(db);
  });

  test('re-opening an up-to-date database changes nothing', () async {
    var db = _open(file);
    final before = await _names(db, 'trigger');
    await db.close();
    db = _open(file);
    addTearDown(db.close);
    expect(await _names(db, 'trigger'), before);
  });
}
