/// Sync on app open: DriveSync's `skipUnchanged` (uploads only when this
/// device's data differs from its newest Drive backup, still merges other
/// devices' newer backups) and OpenSync's rules (setting, account,
/// network / Wi-Fi only, min gap; offline is a silent skip).
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/account_store.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/open_sync.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

const _otherId = 'other-device-0001';
const _google = CloudAccount(provider: CloudProvider.google, email: 'a@b.co');

void main() {
  late FakeDriveStore store;
  late AppFiles files;
  late MemorySecureStore secure;
  late FakeNetwork net;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    store = FakeDriveStore();
    files = tempFiles(addTearDown);
    secure = MemorySecureStore({
      AccountStore.storageKey: AccountStore.encode(_google),
    });
    net = FakeNetwork();
  });

  Future<TestHarness> harness() async {
    final h = await TestHarness.create(
      now: syncNow,
      prefs: plaintextBackupPrefs(),
      overrides: [
        ...driveOverrides(drive: store, files: files, secure: secure, net: net),
        googleConfigProvider.overrideWithValue(const ConfiguredGoogle()),
      ],
    );
    addTearDown(h.dispose);
    store.now = h.clock.now;
    return h;
  }

  Iterable<DriveFile> mine() => store.files.values.where(
    (f) => f.properties['deviceId'] == TestHarness.deviceId,
  );

  group('DriveSync skipUnchanged', () {
    test('uploads once, then nothing while the data is unchanged', () async {
      final h = await harness();
      await seedSample(h, files);
      final sync = h.read(driveSyncProvider);

      final first = await sync.syncNow(skipUnchanged: true);
      expect(first.uploaded, isNotNull);
      expect(first.uploaded!.contentHash, isNotEmpty);

      h.clock.advance(const Duration(minutes: 5));
      final again = await sync.syncNow(skipUnchanged: true);
      expect(again.uploaded, isNull);
      expect(mine(), hasLength(1));
      expect(again.pruned, 0);
    });

    test("still merges another device's newer backup", () async {
      final h = await harness();
      final sync = h.read(driveSyncProvider);
      await sync.syncNow(skipUnchanged: true);

      final other = await TestHarness.create(now: h.clock.now());
      addTearDown(other.dispose);
      final otherFiles = tempFiles(addTearDown);
      await seedSample(other, otherFiles);
      final built = await BackupEngine(
        db: other.db,
        items: other.read(itemsRepositoryProvider),
        files: otherFiles,
        deviceId: _otherId,
        vault: const FakeVaultBridge(),
        clock: other.clock,
      ).build();
      await store.upload(
        DriveBackupFile.fileNameFor(built.manifest.createdAt, _otherId),
        built.bytes,
        properties: DriveBackupFile.propertiesFor(built.manifest),
      );

      h.clock.advance(const Duration(minutes: 5));
      final out = await sync.syncNow(skipUnchanged: true);
      expect(out.uploaded, isNull);
      expect(out.mergedBackups, 1);
      expect(mine(), hasLength(1));

      // The merged items are now this device's data too: the next open
      // uploads them once.
      h.clock.advance(const Duration(minutes: 5));
      final next = await sync.syncNow(skipUnchanged: true);
      expect(next.uploaded, isNotNull);
      expect(mine(), hasLength(2));
    });

    test('a local edit uploads again', () async {
      final h = await harness();
      final sync = h.read(driveSyncProvider);
      await sync.syncNow(skipUnchanged: true);

      h.clock.advance(const Duration(minutes: 5));
      await h.read(notesRepositoryProvider).createEmpty(title: 'New idea');
      final out = await sync.syncNow(skipUnchanged: true);
      expect(out.uploaded, isNotNull);
      expect(mine(), hasLength(2));
    });

    test('a new profile picture or setting uploads again', () async {
      final h = await harness();
      final sync = h.read(driveSyncProvider);
      await sync.syncNow(skipUnchanged: true);

      h.clock.advance(const Duration(minutes: 5));
      await files.write(AppFiles.profilePhotoPath, [1, 2, 3]);
      final photo = await sync.syncNow(skipUnchanged: true);
      expect(photo.uploaded, isNotNull);
      final archive = await sync.download(photo.uploaded!.fileId);
      expect(archive.profilePhoto, [1, 2, 3]);

      h.clock.advance(const Duration(minutes: 5));
      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(quietHours: true));
      final setting = await sync.syncNow(skipUnchanged: true);
      expect(setting.uploaded, isNotNull);
      expect(mine(), hasLength(3));
    });

    test('turning encryption on uploads again (same data)', () async {
      final h = await harness();
      final sync = h.read(driveSyncProvider);
      await sync.syncNow(skipUnchanged: true);

      await BackupKeyStore(secure).enable(
        '2468',
        params: BackupKdfParams.generate(memoryKiB: 256, iterations: 1),
      );
      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(encryptBackups: true));
      h.clock.advance(const Duration(minutes: 5));
      final out = await sync.syncNow(skipUnchanged: true);
      expect(out.uploaded?.isEncrypted, isTrue);
    });

    test(
      'a backup without a content hash (older app) is not trusted',
      () async {
        final h = await harness();
        final sync = h.read(driveSyncProvider);
        final first = await sync.syncNow(skipUnchanged: true);
        final f = store.files[first.uploaded!.fileId]!;
        store.files[f.id] = DriveFile(
          id: f.id,
          name: f.name,
          createdAt: f.createdAt,
          sizeBytes: f.sizeBytes,
          properties: {...f.properties}..remove('contentHash'),
        );

        h.clock.advance(const Duration(minutes: 5));
        final out = await sync.syncNow(skipUnchanged: true);
        expect(out.uploaded, isNotNull);
      },
    );

    test('without skipUnchanged every sync uploads (Sync now)', () async {
      final h = await harness();
      final sync = h.read(driveSyncProvider);
      await sync.syncNow();
      h.clock.advance(const Duration(minutes: 5));
      final out = await sync.syncNow();
      expect(out.uploaded, isNotNull);
      expect(mine(), hasLength(2));
    });
  });

  group('OpenSync', () {
    test('is stale with no sync yet or after the min gap', () {
      final now = DateTime(2026, 3, 5, 9);
      expect(OpenSync.isStale(now: now, lastSync: null), isTrue);
      expect(
        OpenSync.isStale(
          now: now,
          lastSync: now.subtract(const Duration(seconds: 30)),
        ),
        isFalse,
      );
      expect(
        OpenSync.isStale(now: now, lastSync: now.subtract(OpenSync.minGap)),
        isTrue,
      );
    });

    test(
      'syncs on open, not again right away, then without re-uploading',
      () async {
        final h = await harness();
        final open = OpenSync(h.container.read);

        final first = await open.runIfDue();
        expect(first?.uploaded, isNotNull);
        expect(h.read(syncStatusProvider).lastSyncAt, isNotNull);

        h.clock.advance(const Duration(seconds: 30));
        expect(await open.runIfDue(), isNull); // within the min gap

        h.clock.advance(OpenSync.minGap);
        final later = await open.runIfDue();
        expect(later, isNotNull);
        expect(later!.uploaded, isNull); // nothing changed
        expect(mine(), hasLength(1));
      },
    );

    test('off, offline, off Wi-Fi or signed out: skipped quietly', () async {
      final h = await harness();
      final open = OpenSync(h.container.read);
      final edit = h.read(settingsProvider.notifier);

      await edit.update((s) => s.copyWith(syncOnOpen: false));
      expect(await open.isDue(), isFalse);
      await edit.update((s) => s.copyWith(syncOnOpen: true));
      expect(await open.isDue(), isTrue);

      net.online = false;
      expect(await open.runIfDue(), isNull);
      // Offline at open is not a "Sync paused" error.
      expect(h.read(syncStatusProvider).phase, SyncPhase.idle);

      net
        ..online = true
        ..wifi = false;
      expect(await open.isDue(), isFalse); // "Wi-Fi only" is on by default
      await edit.update((s) => s.copyWith(backupWifiOnly: false));
      expect(await open.isDue(), isTrue);

      await h.read(cloudAccountControllerProvider).signOut();
      expect(await open.isDue(), isFalse);
      expect(store.files, isEmpty);
    });
  });
}
