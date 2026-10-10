import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';

void main() {
  late AppDatabase db;

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ff_db');
    db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/test.db'),
        setup: (raw) => EncryptedDatabase.applyKey(raw, 'a' * 64),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('cipher build is active and FTS5 triggers index notes', () async {
    final now = DateTime(2026, 1, 1);
    await db.into(db.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        createdAt: now,
        updatedAt: now,
        title: const Value('Mobile App Design Trends'),
        plainText: const Value('Minimalism and organic shapes'),
      ),
    );
    Future<List<String>> search(String q) async {
      final rows = await db.customSelect(
        'SELECT n.id FROM notes_fts f JOIN notes n ON n.rowid = f.rowid '
        'WHERE notes_fts MATCH ? ORDER BY bm25(notes_fts)',
        variables: [Variable.withString(q)],
      ).get();
      return rows.map((r) => r.read<String>('id')).toList();
    }

    expect(await search('desig*'), ['n1']);
    expect(await search('organic'), ['n1']);

    await (db.update(db.notes)..where((t) => t.id.equals('n1'))).write(
      const NotesCompanion(title: Value('Grocery list')),
    );
    expect(await search('desig*'), isEmpty);
    expect(await search('grocery'), ['n1']);

    await (db.delete(db.notes)..where((t) => t.id.equals('n1'))).go();
    expect(await search('grocery'), isEmpty);
  });

  test('file on disk is encrypted (no plaintext SQLite header)', () async {
    await db.customSelect('SELECT 1').get();
    await db.close();
    final header = File('${dir.path}/test.db').readAsBytesSync().take(15);
    expect(String.fromCharCodes(header), isNot('SQLite format 3'));
    db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/test.db'),
        setup: (raw) => EncryptedDatabase.applyKey(raw, 'a' * 64),
      ),
    );
  });
}
