/// DriveSync — Sync now against an in-memory appDataFolder: upload +
/// appProperties + devices manifest, "Keep last N" pruning, merging other
/// devices' newer backups exactly once, encrypted backups we cannot open,
/// and Drive error mapping.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/google_drive_store.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

const _otherId = 'other-device-0001';

void main() {
  late TestHarness h;
  late FakeDriveStore store;
  late AppFiles files;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    store = FakeDriveStore();
    files = tempFiles(addTearDown);
    h = await TestHarness.create(
      now: syncNow,
      overrides: driveOverrides(
        drive: store,
        files: files,
        secure: MemorySecureStore(),
        net: FakeNetwork(),
      ),
    );
    store.now = h.clock.now;
  });

  tearDown(() => h.dispose());

  /// A backup made on another device (its own database) uploaded to Drive.
  Future<void> uploadFromOtherDevice({BackupKey? key}) async {
    final other = await TestHarness.create(now: syncNow);
    addTearDown(other.dispose);
    final otherFiles = tempFiles(addTearDown);
    await seedSample(other, otherFiles);
    final engine = BackupEngine(
      db: other.db,
      items: other.read(itemsRepositoryProvider),
      files: otherFiles,
      deviceId: _otherId,
      vault: const FakeVaultBridge(),
      clock: other.clock,
    );
    final built = await engine.build(key: key);
    await store.upload(
      DriveBackupFile.fileNameFor(built.manifest.createdAt, _otherId),
      built.bytes,
      properties: DriveBackupFile.propertiesFor(built.manifest),
    );
  }

  test(
    'sync uploads a backup, a history record and the devices manifest',
    () async {
      final phases = <SyncPhase>[];
      final out = await h
          .read(driveSyncProvider)
          .syncNow(onProgress: (p, _) => phases.add(p));

      expect(store.backupNames, hasLength(1));
      final f = store.files[out.uploaded.fileId]!;
      expect(f.properties['deviceId'], TestHarness.deviceId);
      expect(f.properties[DriveBackupFile.kindKey], DriveBackupFile.kindBackup);
      expect(out.uploaded.isEncrypted, isFalse); // no backup key stored

      final manifest = await h.read(driveSyncProvider).manifest();
      expect(manifest.devices.map((d) => d.deviceId), [TestHarness.deviceId]);

      final latest = await h
          .read(backupRecordsRepositoryProvider)
          .watchLatest(location: BackupLocation.drive)
          .first;
      expect(latest?.driveFileId, out.uploaded.fileId);
      expect(phases.first, SyncPhase.preparing);
      expect(phases, contains(SyncPhase.uploading));
      expect(phases.last, SyncPhase.done);
    },
  );

  test('keeps only the last N backups of this device', () async {
    await uploadFromOtherDevice();
    await h
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(keepBackups: 2));
    final sync = h.read(driveSyncProvider);
    var pruned = 0;
    for (var i = 0; i < 4; i++) {
      h.clock.advance(const Duration(hours: 1));
      pruned += (await sync.syncNow(merge: false)).pruned;
    }
    expect(pruned, 2);
    final backups = await sync.listBackups();
    expect(
      backups.where((b) => b.deviceId == TestHarness.deviceId),
      hasLength(2),
    );
    // Other devices' backups are never pruned by us.
    expect(backups.where((b) => b.deviceId == _otherId), hasLength(1));
  });

  test("merges another device's newer backup once", () async {
    await uploadFromOtherDevice();
    final engine = h.read(backupEngineProvider);
    expect((await engine.snapshot()).counts['notes'], 0);

    h.clock.advance(const Duration(minutes: 5));
    final first = await h.read(driveSyncProvider).syncNow();
    expect(first.mergedBackups, 1);
    expect(first.report.added, greaterThan(0));
    expect((await engine.snapshot()).counts['notes'], greaterThan(0));

    h.clock.advance(const Duration(minutes: 5));
    final second = await h.read(driveSyncProvider).syncNow();
    expect(second.mergedBackups, 0);
  });

  test(
    'encrypted backups our key cannot open are left for a manual restore',
    () async {
      final key = await BackupCipher.deriveKey(
        '2468',
        BackupKdfParams.generate(memoryKiB: 256, iterations: 1),
      );
      await uploadFromOtherDevice(key: key);
      final out = await h.read(driveSyncProvider).syncNow();
      expect(out.needsPin, 1);
      expect(out.mergedBackups, 0);
    },
  );

  test('Drive failures surface as DriveFailure', () async {
    store.failWith = const DriveFailure(DriveFailureKind.quota);
    await expectLater(
      h.read(driveSyncProvider).syncNow(),
      throwsA(
        isA<DriveFailure>().having(
          (f) => f.kind,
          'kind',
          DriveFailureKind.quota,
        ),
      ),
    );
  });

  test('HTTP errors map to offline / sign in again / Drive full', () {
    DriveFailureKind kind(int status, [String message = 'x']) =>
        GoogleDriveStore.mapError(
          drive.DetailedApiRequestError(status, message),
        ).kind;
    expect(kind(401), DriveFailureKind.authExpired);
    expect(
      kind(403, "The user's Drive storage quota has been exceeded."),
      DriveFailureKind.quota,
    );
    expect(kind(500), DriveFailureKind.unknown);
  });
}
