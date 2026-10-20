/// DriveSync resilience — one bad backup from another device never breaks
/// every sync (damaged → skipped for good, newer schema → "Update
/// FocusFlow", both as warnings while the rest still merges), "Start
/// fresh" baselines existing backups, the backup-key policy (no silent
/// plaintext, keychain errors fail), "Remove device" keeps backups by
/// default and "Delete account & Drive data" reports partial progress.
library;

import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

const _otherA = 'other-device-aaaa';
const _otherB = 'other-device-bbbb';

/// A Drive whose deletes of [failIds] fail.
class _FlakyDrive extends FakeDriveStore {
  final Set<String> failIds = {};

  @override
  Future<void> delete(String fileId) async {
    if (failIds.contains(fileId)) {
      throw const DriveFailure(DriveFailureKind.unknown, '500');
    }
    await super.delete(fileId);
  }
}

/// A keychain whose reads of [broken] fail like a locked keychain.
class _BrokenKeychain extends MemorySecureStore {
  _BrokenKeychain(this.broken);

  final String broken;

  @override
  Future<String?> read(String key) async {
    if (key == broken) throw StateError('keychain locked');
    return super.read(key);
  }
}

void main() {
  late _FlakyDrive store;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<TestHarness> harness({
    bool plaintext = true,
    MemorySecureStore? secure,
  }) async {
    final h = await TestHarness.create(
      now: syncNow,
      prefs: plaintext ? plaintextBackupPrefs() : const {},
      overrides: driveOverrides(
        drive: store,
        files: tempFiles(addTearDown),
        secure: secure ?? MemorySecureStore(),
        net: FakeNetwork(),
      ),
    );
    addTearDown(h.dispose);
    store.now = h.clock.now;
    return h;
  }

  setUp(() => store = _FlakyDrive());

  /// A real backup built on another device (its own database).
  Future<BuiltBackup> otherBackup(String deviceId, {BackupKey? key}) async {
    final other = await TestHarness.create(now: syncNow);
    addTearDown(other.dispose);
    final files = tempFiles(addTearDown);
    await seedSample(other, files);
    return BackupEngine(
      db: other.db,
      items: other.read(itemsRepositoryProvider),
      files: files,
      deviceId: deviceId,
      vault: const FakeVaultBridge(),
      clock: other.clock,
    ).build(key: key);
  }

  Future<DriveFile> put(
    String deviceId,
    Uint8List bytes,
    BackupManifest m, {
    String deviceName = 'Pixel 8',
  }) {
    final props = DriveBackupFile.propertiesFor(m)
      ..['deviceId'] = deviceId
      ..['deviceName'] = deviceName;
    return store.upload(
      DriveBackupFile.fileNameFor(m.createdAt, deviceId),
      bytes,
      properties: props,
    );
  }

  group('one bad backup never breaks sync', () {
    test('an undecodable backup is skipped with a warning; the others '
        'still merge, and it is not retried', () async {
      final h = await harness();
      final good = await otherBackup(_otherB);
      await put(_otherB, good.bytes, good.manifest, deviceName: 'iPad');
      await put(
        _otherA,
        Uint8List.fromList([1, 2, 3, 4]),
        good.manifest,
        deviceName: 'Old phone',
      );
      h.clock.advance(const Duration(minutes: 5));

      final sync = h.read(driveSyncProvider);
      final first = await sync.syncNow();
      expect(first.mergedBackups, 1);
      expect(first.warnings, ["Couldn't read the backup from Old phone"]);
      // Progress saved: both devices count as handled.
      expect(sync.state.merged().keys, containsAll([_otherA, _otherB]));

      h.clock.advance(const Duration(minutes: 5));
      final second = await sync.syncNow();
      expect(second.warnings, isEmpty);
      expect(second.mergedBackups, 0);
    });

    test(
      'a newer-schema backup asks for an update and is retried later',
      () async {
        final h = await harness();
        final built = await otherBackup(_otherA);
        final archive = BackupArchive.decode(built.bytes);
        final newer = BackupManifest.fromJson({
          ...built.manifest.toJson(),
          'schemaVersion': h.db.schemaVersion + 1,
        });
        final bytes = BackupArchive(
          manifest: newer,
          dbJson: archive.dbJson,
          files: archive.files,
        ).encode();
        await put(_otherA, bytes, newer);
        expect(
          () => h.read(backupEngineProvider).inspect(bytes),
          throwsA(isA<BackupTooNew>()),
        );

        final sync = h.read(driveSyncProvider);
        final out = await sync.syncNow();
        expect(out.mergedBackups, 0);
        expect(out.warnings, [
          'Update FocusFlow to read the backup from Pixel 8',
        ]);
        expect(sync.state.merged(), isNot(contains(_otherA)));
        h.clock.advance(const Duration(minutes: 5));
        expect((await sync.syncNow()).warnings, hasLength(1));
      },
    );

    test('older backups (lower schemaVersion) still restore', () async {
      final h = await harness();
      final built = await otherBackup(_otherA);
      final archive = BackupArchive.decode(built.bytes);
      final older = BackupArchive(
        manifest: BackupManifest.fromJson({
          ...built.manifest.toJson(),
          'schemaVersion': 1,
        }),
        dbJson: archive.dbJson,
        files: archive.files,
      );
      final engine = h.read(backupEngineProvider);
      final r = await engine.restore(older, mode: RestoreMode.merge);
      expect(r.report.added, greaterThan(0));
    });

    test('wrong JSON types in a manifest raise FormatException', () {
      expect(
        () => BackupManifest.fromJson({'format': 'ffbackup', 'deviceId': 42}),
        throwsA(isA<FormatException>()),
      );
    });

    test('a failing prune is a warning; the backup still counts', () async {
      final h = await harness();
      final sync = h.read(driveSyncProvider);
      final first = await sync.syncNow(merge: false);
      store.failIds.add(first.uploaded!.fileId);
      for (var i = 0; i < 10; i++) {
        h.clock.advance(const Duration(minutes: 1));
        await sync.syncNow(merge: false);
      }
      final out = await sync.syncNow(merge: false);
      expect(out.warnings, [
        "Old backups couldn't be removed; we'll try next time",
      ]);
    });
  });

  group('Restore / Start fresh', () {
    test('merging waits for the decision; Start fresh baselines existing '
        'backups but newer ones merge', () async {
      final h = await harness();
      final old = await otherBackup(_otherA);
      await put(_otherA, old.bytes, old.manifest);
      final sync = h.read(driveSyncProvider);

      await sync.holdMergeForDecision();
      final held = await sync.syncNow();
      expect(held.mergeDeferred, isTrue);
      expect(held.mergedBackups, 0);
      expect(store.backupNames, hasLength(2)); // ours was still uploaded

      expect(await sync.startFresh(), 1);
      expect(sync.state.decisionPending, isFalse);
      h.clock.advance(const Duration(minutes: 5));
      expect((await sync.syncNow()).mergedBackups, 0);
      // Still offered for a manual restore.
      expect(
        (await sync.listBackups()).where((b) => b.deviceId == _otherA),
        hasLength(1),
      );

      h.clock.advance(const Duration(hours: 1));
      store.now = h.clock.now;
      final newer = await otherBackup(_otherA);
      final m = BackupManifest.fromJson({
        ...newer.manifest.toJson(),
        'createdAt': h.clock.now().toUtc().toIso8601String(),
      });
      await put(_otherA, newer.bytes, m);
      h.clock.advance(const Duration(minutes: 5));
      expect((await sync.syncNow()).mergedBackups, 1);
    });

    test(
      'a Replace restore forgets earlier merges except the restored one',
      () async {
        final h = await harness();
        final sync = h.read(driveSyncProvider);
        await sync.state.saveMerged({_otherB: syncNow});
        await sync.holdMergeForDecision();
        final restored = await otherBackup(_otherA);
        await sync.noteRestored(restored.manifest, replace: true);
        expect(sync.state.merged().keys, [_otherA]);
        expect(sync.state.decisionPending, isFalse);
        await sync.forgetSyncState();
        expect(sync.state.merged(), isEmpty);
      },
    );
  });

  group('backup key policy', () {
    test('Encrypt backups on without a PIN uploads nothing', () async {
      final h = await harness(plaintext: false);
      await expectLater(
        h.read(driveSyncProvider).syncNow(),
        throwsA(isA<BackupPinRequired>()),
      );
      expect(store.files, isEmpty);
      await expectLater(
        h.read(localBackupsProvider).backupNow(),
        throwsA(isA<BackupPinRequired>()),
      );
    });

    test('a keychain read failure fails the backup instead of going '
        'plaintext', () async {
      final h = await harness(
        plaintext: false,
        secure: _BrokenKeychain(BackupKeyStore.storageKey),
      );
      await expectLater(
        h.read(driveSyncProvider).syncNow(),
        throwsA(isA<BackupKeyUnavailable>()),
      );
      expect(store.files, isEmpty);
      expect(
        await h.read(backupKeyPolicyProvider).state(),
        BackupKeyState.unreadable,
      );
    });

    test('a damaged stored key is "unreadable", never plaintext', () async {
      final secure = MemorySecureStore({BackupKeyStore.storageKey: 'junk'});
      final h = await harness(plaintext: false, secure: secure);
      await expectLater(
        h.read(localBackupsProvider).backupNow(),
        throwsA(isA<BackupKeyUnavailable>()),
      );
    });

    test('with a backup PIN the backup and its record are encrypted', () async {
      final secure = MemorySecureStore();
      final h = await harness(plaintext: false, secure: secure);
      await BackupKeyStore(secure).enable(
        '2468',
        params: BackupKdfParams.generate(memoryKiB: 256, iterations: 1),
      );
      final out = await h.read(driveSyncProvider).syncNow();
      expect(out.uploaded!.isEncrypted, isTrue);
      final rec = await h
          .read(backupRecordsRepositoryProvider)
          .watchLatest(location: BackupLocation.drive)
          .first;
      expect(rec?.isEncrypted, isTrue);
    });

    test('a .ffbackup export never claims encryption it lacks', () async {
      final secure = MemorySecureStore();
      final h = await harness(plaintext: false, secure: secure);
      final export = h.read(exportServiceProvider);
      await expectLater(
        export.build(const ExportOptions(modules: {ExportModule.notes})),
        throwsA(isA<BackupPinRequired>()),
      );
      await BackupKeyStore(secure).enable(
        '2468',
        params: BackupKdfParams.generate(memoryKiB: 256, iterations: 1),
      );
      final f = await export.build(
        const ExportOptions(modules: {ExportModule.notes}),
      );
      expect(f.isEncrypted, isTrue);
      expect(BackupArchive.decode(f.bytes).manifest.isEncrypted, isTrue);
    });

    test('encryption off: plaintext and labelled so', () async {
      final h = await harness();
      final r = await h.read(localBackupsProvider).backupNow();
      expect(r.isEncrypted, isFalse);
    });
  });

  group('devices and account deletion', () {
    test(
      'Remove device keeps its backups unless asked to delete them',
      () async {
        final h = await harness();
        final sync = h.read(driveSyncProvider);
        await sync.syncNow(merge: false);
        final b = await otherBackup(_otherA);
        await put(_otherA, b.bytes, b.manifest);
        expect(await sync.removeDevice(_otherA), 0);
        expect(
          (await sync.listBackups()).where((x) => x.deviceId == _otherA),
          hasLength(1),
        );
        expect(await sync.removeDevice(_otherA, deleteBackups: true), 1);
        expect(
          (await sync.listBackups()).where((x) => x.deviceId == _otherA),
          isEmpty,
        );
      },
    );

    test(
      'a partial Drive delete reports progress and a retry finishes',
      () async {
        final h = await harness();
        final sync = h.read(driveSyncProvider);
        final out = await sync.syncNow(merge: false);
        final b = await otherBackup(_otherA);
        final f = await put(_otherA, b.bytes, b.manifest);
        store.failIds.add(f.id);
        final total = store.files.length;

        await expectLater(
          sync.deleteAllCloudData(),
          throwsA(
            isA<CloudDeleteIncomplete>()
                .having((e) => e.deleted, 'deleted', total - 1)
                .having((e) => e.total, 'total', total),
          ),
        );
        // Our backup's history row went with its file.
        final history = await h
            .read(backupRecordsRepositoryProvider)
            .watchAll(location: BackupLocation.drive)
            .first;
        expect(
          history.where((r) => r.driveFileId == out.uploaded!.fileId),
          isEmpty,
        );

        store.failIds.clear();
        expect(await sync.deleteAllCloudData(), 1);
        expect(store.files, isEmpty);
      },
    );
  });

  test('SecureStore never replaces a database key it failed to read', () async {
    final broken = _BrokenKeychain(SecureStore.databaseKey);
    await expectLater(
      broken.getOrCreateDatabaseKey(),
      throwsA(isA<DatabaseKeyUnavailable>()),
    );
    expect(broken.values, isEmpty);
  });
}
