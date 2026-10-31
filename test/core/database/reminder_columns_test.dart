/// `reminders.auto_snooze_minutes` came after schema v3 without a version
/// bump: it is added on open (AppDatabase._ensureAddedColumns). A database
/// from before it must open, keep its reminders (at the 2-minute default)
/// and accept the new value.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:sqlite3/sqlite3.dart';

const _key = 'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';

AppDatabase _open(File file) => AppDatabase(
  NativeDatabase(file, setup: (raw) => EncryptedDatabase.applyKey(raw, _key)),
);

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ff_reminder_columns');
    file = File('${dir.path}/focusflow.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('an older database gains auto_snooze_minutes, rows at 2', () async {
    final now = DateTime(2026, 10, 31, 7);
    final seed = _open(file);
    await seed
        .into(seed.reminders)
        .insert(
          RemindersCompanion.insert(
            id: 'r1',
            createdAt: now,
            updatedAt: now,
            triggerAt: now,
            notificationId: 7,
            title: const Value('Wake up'),
          ),
        );
    await seed.close();

    // As on an install from before the column.
    final raw = sqlite3.open(file.path);
    EncryptedDatabase.applyKey(raw, _key);
    raw.execute('ALTER TABLE reminders DROP COLUMN auto_snooze_minutes');
    raw.close();

    final db = _open(file);
    addTearDown(db.close);
    final row = await db.select(db.reminders).getSingle();
    expect(row.title, 'Wake up');
    expect(row.autoSnoozeMinutes, 2);

    await (db.update(db.reminders)..where((r) => r.id.equals('r1'))).write(
      const RemindersCompanion(autoSnoozeMinutes: Value(0)),
    );
    expect((await db.select(db.reminders).getSingle()).autoSnoozeMinutes, 0);
  });

  test('opening twice does not add the column twice', () async {
    await _open(file).close();
    final db = _open(file);
    addTearDown(db.close);
    final cols = await db.customSelect('PRAGMA table_info(reminders)').get();
    expect(
      cols.where((c) => c.read<String>('name') == 'auto_snooze_minutes'),
      hasLength(1),
    );
  });
}
