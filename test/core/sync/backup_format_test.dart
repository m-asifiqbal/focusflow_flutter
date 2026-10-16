/// `.ffbackup` building blocks: manifest JSON, the zip container, the
/// db.json snapshot codec, Argon2id → AES-256-GCM sealing and LWW order.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/merge_support.dart';
import 'package:focusflow/core/sync/snapshot.dart';

BackupManifest _manifest({BackupKdfParams? encryption}) => BackupManifest(
  schemaVersion: 2,
  appVersion: '1.0.0+1',
  createdAt: DateTime.utc(2026, 1, 10, 9).toLocal(),
  deviceId: 'dev-a',
  deviceName: 'Pixel 8 Pro',
  platform: 'Android 15',
  counts: const {'notes': 3, 'tasks': 1},
  itemCount: 4,
  checksum: 'abc',
  encryption: encryption,
  attachments: const ['attachments/a.jpg'],
  devices: [
    LinkedDevice(
      deviceId: 'dev-a',
      name: 'Pixel 8 Pro',
      platform: 'Android 15',
      lastSyncAt: DateTime.utc(2026, 1, 10).toLocal(),
    ),
  ],
  vaultKey: const {'keyId': 'k1'},
);

void main() {
  group('manifest', () {
    test('JSON round trip', () {
      final params = BackupKdfParams.generate(memoryKiB: 256, iterations: 1);
      final m = _manifest(encryption: params);
      final back = BackupManifest.fromJson(
        (jsonDecode(jsonEncode(m.toJson())) as Map).cast<String, Object?>(),
      );
      expect(back.toJson(), m.toJson());
      expect(back.encryption, params);
      expect(back.isEncrypted, isTrue);
      expect(back.devices.single, m.devices.single);
    });

    test('rejects other files and newer formats', () {
      expect(
        () => BackupManifest.fromJson({'format': 'zip'}),
        throwsFormatException,
      );
      expect(
        () => BackupManifest.fromJson({
          'format': 'ffbackup',
          'formatVersion': 99,
        }),
        throwsFormatException,
      );
    });

    test('linked devices union keeps the newest sync per device', () {
      LinkedDevice d(String id, int day) => LinkedDevice(
        deviceId: id,
        name: id,
        platform: 'iOS 18',
        lastSyncAt: DateTime(2026, 1, day),
      );
      final u = LinkedDevice.union([d('a', 1), d('b', 5)], [d('a', 7)]);
      expect(u.map((x) => (x.deviceId, x.lastSyncAt!.day)), [
        ('a', 7),
        ('b', 5),
      ]);
      expect(u.first.isIos, isTrue);
    });
  });

  group('archive', () {
    test('zip round trip keeps payloads and attachment paths', () {
      final archive = BackupArchive(
        manifest: _manifest(),
        dbJson: Uint8List.fromList(utf8.encode('{"tables":{}}')),
        files: {
          'attachments/a.jpg': Uint8List.fromList([1, 2, 3]),
        },
      );
      final back = BackupArchive.decode(archive.encode());
      expect(back.manifest.toJson(), archive.manifest.toJson());
      expect(back.dbJson, archive.dbJson);
      expect(back.files['attachments/a.jpg'], [1, 2, 3]);
    });

    test('rejects non-zips, zips without a manifest and path escapes', () {
      expect(() => BackupArchive.decode([0, 1, 2, 3]), throwsFormatException);
      final noManifest = ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.string('db.json', '{}')),
      );
      expect(() => BackupArchive.decode(noManifest), throwsFormatException);

      final evil = BackupArchive(
        manifest: _manifest(),
        dbJson: Uint8List(0),
        files: {
          '../../escape.txt': Uint8List.fromList([1]),
        },
      );
      expect(BackupArchive.decode(evil.encode()).files, isEmpty);
    });
  });

  test('db.json codec keeps ints, doubles, nulls and blobs', () {
    final s = DbSnapshot({
      'notes': [
        {'id': 'n1', 'updated_at': 1700000000, 'sort_order': 1.5, 'note': null},
      ],
      'vault_items': [
        {
          'id': 'v1',
          'encrypted_payload': Uint8List.fromList([0, 255, 7]),
        },
      ],
    });
    final back = DbSnapshot.decode(s.encode());
    expect(back.sameContentAs(s), isTrue);
    expect(
      back.rows('vault_items').single['encrypted_payload'],
      isA<Uint8List>(),
    );
    expect(back.rows('notes').single['sort_order'], 1.5);
    expect(back.rows('tags'), isEmpty);
    expect(back.itemCounts['note'], 1);
    expect(() => DbSnapshot.decode(utf8.encode('nope')), throwsFormatException);
  });

  group('crypto', () {
    final params = BackupKdfParams.generate(memoryKiB: 256, iterations: 1);

    test('seal / open with the PIN-derived key', () async {
      final key = await BackupCipher.deriveKey('123456', params);
      expect(key.keyBytes, hasLength(32));
      final again = await BackupCipher.deriveKey('123456', params);
      expect(again.keyBytes, key.keyBytes);

      final plain = utf8.encode('secret notes');
      final sealed = await BackupCipher.seal(plain, key);
      expect(sealed.length, plain.length + 12 + 16);
      expect(await BackupCipher.open(sealed, key), plain);
      // Fresh nonce every time.
      expect(await BackupCipher.seal(plain, key), isNot(sealed));
    });

    test('wrong PIN or tampering → WrongBackupPin', () async {
      final key = await BackupCipher.deriveKey('123456', params);
      final wrong = await BackupCipher.deriveKey('654321', params);
      final sealed = await BackupCipher.seal([1, 2, 3], key);
      await expectLater(
        BackupCipher.open(sealed, wrong),
        throwsA(isA<WrongBackupPin>()),
      );
      sealed[sealed.length - 1] ^= 1;
      await expectLater(
        BackupCipher.open(sealed, key),
        throwsA(isA<WrongBackupPin>()),
      );
      await expectLater(
        BackupCipher.open([1, 2], key),
        throwsA(isA<WrongBackupPin>()),
      );
    });
  });

  test('last-write-wins is a total order', () {
    RawRow r(int at, int v, String dev) => {
      'updated_at': at,
      'sync_version': v,
      'device_id': dev,
    };
    expect(incomingWins(r(2, 0, 'a'), r(1, 9, 'z')), isTrue);
    expect(incomingWins(r(1, 2, 'a'), r(1, 1, 'z')), isTrue);
    expect(incomingWins(r(1, 1, 'b'), r(1, 1, 'a')), isTrue);
    expect(incomingWins(r(1, 1, 'a'), r(1, 1, 'b')), isFalse);
    expect(incomingWins(r(1, 1, 'a'), r(1, 1, 'a')), isFalse);
  });
}
