/// BackupEngine — `.ffbackup` build / restore: the round trip
/// (backup → wipe → restore = identical database), encryption, damaged
/// files, Replace without spurious tombstones and vault-key handling.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/snapshot.dart';

import '../../helpers/test_container.dart';
import 'sync_fixtures.dart';

/// Cheap Argon2id parameters so the tests stay fast.
BackupKdfParams _fastParams() =>
    BackupKdfParams.generate(memoryKiB: 256, iterations: 1);

void main() {
  late TestHarness source;
  late TestHarness target;
  late AppFiles sourceFiles;
  late AppFiles targetFiles;

  // Two databases (source + target device) are open at once on purpose.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    source = await TestHarness.create(now: syncNow);
    target = await TestHarness.create(now: syncNow);
    sourceFiles = tempFiles(addTearDown);
    targetFiles = tempFiles(addTearDown);
  });

  tearDown(() async {
    await source.dispose();
    await target.dispose();
  });

  test('backup → wipe → restore yields an identical database', () async {
    final ids = await seedSample(source, sourceFiles);
    final engine = engineFor(source, sourceFiles);
    final built = await engine.build();
    final original = await engine.snapshot();

    // Every synced table carries data (so the round trip covers all).
    for (final e in original.counts.entries) {
      expect(e.value, greaterThan(0), reason: e.key);
    }
    final m = built.manifest;
    expect(m.counts, original.counts);
    expect(m.itemCount, 6); // note, task, habit, medicine, reminder, vault
    expect(m.isEncrypted, isFalse);
    expect(m.deviceId, TestHarness.deviceId);
    expect(m.schemaVersion, source.db.schemaVersion);
    expect(m.attachments, ['attachments/a1.txt', 'covers/c1.jpg']);
    expect(m.devices.single.deviceId, TestHarness.deviceId);

    // "Wipe": a fresh install on the target.
    final restore = engineFor(target, targetFiles);
    final archive = restore.inspect(built.bytes);
    final result = await restore.restore(archive, mode: RestoreMode.replace);

    final restored = await restore.snapshot();
    expect(restored.sameContentAs(original), isTrue);
    expect(restored.encode(), original.encode());
    expect(result.filesRestored, 2);
    expect(result.filesMissing, 0);
    expect(
      utf8.decode((await targetFiles.read('attachments/a1.txt'))!),
      'hello attachment',
    );
    expect(await targetFiles.read('covers/c1.jpg'), [1, 2, 3, 4]);

    // FTS was rebuilt, tombstones survived, no extra tombstones appeared.
    expect(await searchNotes(target.db, 'organic'), [ids.note]);
    final tombs = await target.db.select(target.db.tombstones).get();
    expect(tombs.map((t) => t.entity), ['note']);
  });

  test('Replace drops local-only rows without leaving tombstones', () async {
    await seedSample(source, sourceFiles);
    final built = await engineFor(source, sourceFiles).build();
    final backupTombs = (await engineFor(
      source,
      sourceFiles,
    ).snapshot()).rows('tombstones');

    final db = target.db;
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'local-only',
            createdAt: syncNow,
            updatedAt: syncNow,
            title: const Value('Only on the target'),
          ),
        );
    final engine = engineFor(target, targetFiles);
    await engine.restore(
      engine.inspect(built.bytes),
      mode: RestoreMode.replace,
    );

    expect(
      (await db.select(db.notes).get()).map((n) => n.id),
      isNot(contains('local-only')),
    );
    final tombs = (await engine.snapshot()).rows('tombstones');
    expect(tombs.length, backupTombs.length);
    expect(tombs.map((t) => t['entity_id']), isNot(contains('local-only')));
    expect(await searchNotes(db, 'target'), isEmpty);
  });

  group('encryption', () {
    test('encrypted round trip; db.json and files are not readable', () async {
      await seedSample(source, sourceFiles);
      final key = await BackupCipher.deriveKey('482910', _fastParams());
      final engine = engineFor(source, sourceFiles);
      final built = await engine.build(key: key);
      final original = await engine.snapshot();

      final archive = BackupArchive.decode(built.bytes);
      expect(archive.manifest.isEncrypted, isTrue);
      expect(archive.manifest.encryption, key.params);
      expect(
        utf8.decode(archive.dbJson, allowMalformed: true),
        isNot(contains('Design trends')),
      );
      expect(archive.files['covers/c1.jpg'], isNot([1, 2, 3, 4]));

      final restore = engineFor(target, targetFiles);
      final pinKey = await restore.keyFor(archive.manifest, '482910');
      await restore.restore(archive, mode: RestoreMode.replace, key: pinKey);
      expect((await restore.snapshot()).sameContentAs(original), isTrue);
      expect(await targetFiles.read('covers/c1.jpg'), [1, 2, 3, 4]);
    });

    test('a wrong or missing PIN fails before anything changes', () async {
      await seedSample(source, sourceFiles);
      final key = await BackupCipher.deriveKey('482910', _fastParams());
      final built = await engineFor(source, sourceFiles).build(key: key);

      final restore = engineFor(target, targetFiles);
      final before = await restore.snapshot();
      final archive = restore.inspect(built.bytes);
      final wrong = await restore.keyFor(archive.manifest, '000000');
      await expectLater(
        restore.restore(archive, mode: RestoreMode.replace, key: wrong),
        throwsA(isA<WrongBackupPin>()),
      );
      await expectLater(
        restore.restore(archive, mode: RestoreMode.merge),
        throwsA(isA<WrongBackupPin>()),
      );
      expect((await restore.snapshot()).sameContentAs(before), isTrue);
    });
  });

  test('a damaged db.json is rejected by the checksum', () async {
    await seedSample(source, sourceFiles);
    final built = await engineFor(source, sourceFiles).build();
    final archive = BackupArchive.decode(built.bytes);
    final bytes = Uint8List.fromList(archive.dbJson);
    bytes[bytes.length ~/ 2] ^= 0x01;
    final damaged = BackupArchive(
      manifest: archive.manifest,
      dbJson: bytes,
      files: archive.files,
    ).encode();

    final restore = engineFor(target, targetFiles);
    await expectLater(
      restore.restore(restore.inspect(damaged), mode: RestoreMode.merge),
      throwsFormatException,
    );
    expect(() => restore.inspect([1, 2, 3]), throwsFormatException);
  });

  test('Replace keeps this vault when the backup has another key', () async {
    await seedSample(source, sourceFiles);
    final built = await engineFor(
      source,
      sourceFiles,
      vault: const FakeVaultBridge(envelope: {'keyId': 'other-vault'}),
    ).build();
    expect(built.manifest.vaultKey, {'keyId': 'other-vault'});

    final db = target.db;
    await db
        .into(db.vaultItems)
        .insert(
          VaultItemsCompanion.insert(
            id: 'v-local',
            createdAt: syncNow,
            updatedAt: syncNow,
            title: const Value('Mine'),
            encryptedPayload: Uint8List.fromList([5]),
          ),
        );
    final engine = engineFor(
      target,
      targetFiles,
      vault: const FakeVaultBridge(accept: false),
    );
    final result = await engine.restore(
      engine.inspect(built.bytes),
      mode: RestoreMode.replace,
    );
    expect(result.vaultRestored, isFalse);
    expect(result.report.vaultSkipped, 1);
    expect((await db.select(db.vaultItems).get()).map((v) => v.id), [
      'v-local',
    ]);
    expect(await db.select(db.vaultHistory).get(), isEmpty);
    expect((await db.select(db.notes).get()), hasLength(1));
  });

  test('Merge restore brings files for the items it adds', () async {
    await seedSample(source, sourceFiles);
    final built = await engineFor(source, sourceFiles).build();
    final engine = engineFor(target, targetFiles);
    final result = await engine.restore(
      engine.inspect(built.bytes),
      mode: RestoreMode.merge,
    );
    expect(result.report.added, 6); // the seed's six items
    expect(result.report.conflicts, 0);
    expect(result.filesRestored, 2);
    expect(await targetFiles.exists('attachments/a1.txt'), isTrue);
  });
  test('files outside attachments/ and covers/ are never written', () async {
    final rows = {
      'attachments': [
        {
          'id': 'a-evil',
          'item_id': 'n1',
          'item_type': 'note',
          'file_name': 'x',
          'local_path': 'FocusFlow/backups/evil.ffbackup',
          'created_at': secs(syncNow),
        },
      ],
    };
    final plain = DbSnapshot(rows).encode();
    final evil = BackupArchive(
      manifest: BackupManifest(
        schemaVersion: 2,
        appVersion: '',
        createdAt: syncNow,
        deviceId: 'x',
        deviceName: 'x',
        platform: '',
        counts: const {},
        itemCount: 0,
        checksum: BackupArchive.sha256Hex(plain),
      ),
      dbJson: plain,
      files: {
        'FocusFlow/backups/evil.ffbackup': Uint8List.fromList([1]),
      },
    ).encode();
    final engine = engineFor(target, targetFiles);
    final result = await engine.restore(
      engine.inspect(evil),
      mode: RestoreMode.replace,
    );
    expect(result.filesRestored, 0);
    expect(
      await targetFiles.exists('FocusFlow/backups/evil.ffbackup'),
      isFalse,
    );
  });
}
