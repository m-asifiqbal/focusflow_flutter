/// EncryptedDatabase.quarantineIfUnreadable — a database that cannot be
/// opened with the stored key (the keystore was lost in a device restore) is
/// moved aside instead of crashing every launch; one that opens, or does not
/// exist, is left alone. The probe runs on its own isolate.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late File file;
  final goodKey = 'a' * 64;
  final otherKey = 'b' * 64;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ff_quarantine');
    file = File('${dir.path}/focusflow.db');
    final db = sqlite3.open(file.path);
    EncryptedDatabase.applyKey(db, goodKey);
    db.execute('CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (1);');
    db.close();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('a database that opens with the key stays where it is', () async {
    await EncryptedDatabase.quarantineIfUnreadable(file, goodKey);
    expect(names(), ['focusflow.db']);
  });

  test('a missing file is a no-op (first launch)', () async {
    file.deleteSync();
    await EncryptedDatabase.quarantineIfUnreadable(file, goodKey);
    expect(names(), isEmpty);
  });

  test('a database the key does not open is moved aside, kept', () async {
    await EncryptedDatabase.quarantineIfUnreadable(file, otherKey);
    final moved = names();
    expect(moved, hasLength(1));
    expect(moved.single, startsWith('focusflow.db.unreadable-'));
    expect(file.existsSync(), isFalse);
  });

  test('the moved file still holds the original bytes', () async {
    final before = file.readAsBytesSync();
    await EncryptedDatabase.quarantineIfUnreadable(file, otherKey);
    final moved = dir.listSync().whereType<File>().single;
    expect(moved.readAsBytesSync(), before);
  });
}
