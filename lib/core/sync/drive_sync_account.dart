/// ============================================================
/// DRIVE SYNC · ACCOUNT — restore decisions, browsing, devices, delete
/// ============================================================
///
/// The DriveSync operations besides "Sync now" (split out to keep
/// drive_sync.dart readable; re-exported by it, so callers just import
/// drive_sync.dart):
/// * Restore / Start fresh bookkeeping ([DriveSyncState]);
/// * listing / downloading / deleting backups, linked devices, usage;
/// * "Remove device" (keeps its backups unless asked) and "Delete account
///   & Drive data" (resumable, reports partial progress).
/// ============================================================
library;

import 'dart:typed_data';

import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/drive_sync.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';

extension DriveSyncAccount on DriveSync {
  // ─────────────────────── Restore / Start fresh ───────────────────────

  /// Sign-in found backups in Drive: hold merging until the user picks
  /// Restore or Start fresh.
  Future<void> holdMergeForDecision() => state.setDecisionPending(true);

  /// "Merge them automatically" (Backup & Sync banner): resume merging.
  Future<void> resumeMerging() => state.setDecisionPending(false);

  /// "Start fresh": every backup now in Drive from another device (which,
  /// after a reinstall, includes this user's own old ones) counts as
  /// handled, so none is merged automatically. A manual Restore still
  /// offers all of them. Returns how many devices were baselined.
  Future<int> startFresh() async {
    final store = await requireStore();
    final backups = (await store.list()).map(DriveBackupFile.fromFile).nonNulls;
    final merged = state.merged();
    var n = 0;
    for (final b in backups) {
      if (b.deviceId.isEmpty || b.deviceId == deviceId) continue;
      final cur = merged[b.deviceId];
      if (cur == null || b.createdAt.isAfter(cur)) {
        merged[b.deviceId] = b.createdAt;
        n++;
      }
    }
    await state.saveMerged(merged);
    await state.setDecisionPending(false);
    return n;
  }

  /// After a manual restore of [m]. Replace: the database is now exactly
  /// that backup, so earlier merges no longer apply — forget them (other
  /// devices' newest backups merge again) except the restored one.
  /// Merge: the restored backup counts as merged.
  Future<void> noteRestored(BackupManifest m, {required bool replace}) async {
    if (replace) await state.saveMerged({});
    if (m.deviceId.isNotEmpty && m.deviceId != deviceId) {
      await state.markHandled(m.deviceId, m.createdAt);
    }
    await state.setDecisionPending(false);
  }

  /// Forgets merge progress and the pending decision (sign-out / erase).
  Future<void> forgetSyncState() => state.clear();

  // ───────────────────────────── Browse ─────────────────────────────

  /// Every backup in Drive (all devices), newest first.
  Future<List<DriveBackupFile>> listBackups({bool interactive = false}) async {
    final store = await requireStore(interactive: interactive);
    return (await store.list()).map(DriveBackupFile.fromFile).nonNulls.toList();
  }

  /// Downloads a backup for preview / restore (see BackupEngine.inspect).
  Future<BackupArchive> download(String fileId) async {
    final store = await requireStore();
    return engine.inspectAsync(await store.download(fileId));
  }

  /// Raw bytes of a Drive backup ("Download" → save to device).
  Future<Uint8List> downloadBytes(String fileId) async =>
      (await requireStore()).download(fileId);

  Future<void> deleteBackup(String fileId) async {
    await (await requireStore()).delete(fileId);
  }

  /// The account's linked devices (screen 36), from the Drive manifest.
  Future<DriveManifest> manifest() async {
    final store = await requireStore();
    final file = (await store.list()).where(DriveManifest.isManifest);
    if (file.isEmpty) return const DriveManifest();
    return DriveManifest.decode(await store.download(file.first.id));
  }

  /// Unlinks [otherDeviceId] from the account's device list (it is linked
  /// again when it next syncs). Its Drive backups stay — they can still be
  /// restored — unless [deleteBackups] is true. Returns how many backups
  /// were deleted.
  Future<int> removeDevice(
    String otherDeviceId, {
    bool deleteBackups = false,
  }) async {
    final store = await requireStore();
    final files = await store.list();
    final mf = files.where(DriveManifest.isManifest).firstOrNull;
    if (mf != null) {
      final m = DriveManifest.decode(await store.download(mf.id));
      await store.overwrite(
        mf.id,
        m
            .copyWith(
              devices: m.devices
                  .where((d) => d.deviceId != otherDeviceId)
                  .toList(),
            )
            .encode(),
      );
    }
    if (!deleteBackups) return 0;
    var deleted = 0;
    for (final b in files.map(DriveBackupFile.fromFile).nonNulls) {
      if (b.deviceId != otherDeviceId) continue;
      await store.delete(b.fileId);
      deleted++;
    }
    return deleted;
  }

  /// Deletes everything FocusFlow stored in Drive ("Delete account &
  /// Drive data"). Local data is untouched. Returns how many files were
  /// deleted. Throws [DriveFailure] when Drive could not even be listed
  /// (nothing deleted) and [CloudDeleteIncomplete] when only some files
  /// went — calling it again finishes the job (idempotent).
  Future<int> deleteAllCloudData() async {
    final store = await requireStore();
    final files = await store.list();
    final deletedIds = <String>{};
    for (final f in files) {
      try {
        await store.delete(f.id);
        deletedIds.add(f.id);
      } on Object catch (e) {
        AppLogger.w('Drive delete failed (${e.runtimeType})');
      }
    }
    final history = await records
        .watchAll(location: BackupLocation.drive)
        .first;
    for (final r in history) {
      final id = r.driveFileId;
      if (id == null ||
          deletedIds.contains(id) ||
          deletedIds.length == files.length) {
        await records.delete(r.id);
      }
    }
    if (deletedIds.length < files.length) {
      throw CloudDeleteIncomplete(
        deleted: deletedIds.length,
        total: files.length,
      );
    }
    await state.clear();
    return files.length;
  }

  /// App-folder usage: bytes of every FocusFlow file in Drive and the
  /// account's storage limit (screen 34 "2.4 MB of 15 GB").
  Future<DriveUsage> usage() async {
    final store = await requireStore();
    final files = await store.list();
    int? limit;
    try {
      limit = await store.storageLimit();
    } on DriveFailure {
      limit = null; // Usage still shows without the total.
    }
    return DriveUsage(
      usedBytes: files.fold(0, (sum, f) => sum + f.sizeBytes),
      limitBytes: limit,
      backups: files.where((f) => DriveBackupFile.fromFile(f) != null).length,
    );
  }

  /// Uploads an already built backup (Import & Export "Save to Google
  /// Drive") and records it in History. Not pruned or merged.
  Future<DriveBackupFile> uploadBuilt(
    BuiltBackup built, {
    void Function(double progress)? onProgress,
  }) async {
    final store = await requireStore(interactive: true);
    final m = built.manifest;
    final file = await store.upload(
      DriveBackupFile.fileNameFor(m.createdAt, deviceId),
      built.bytes,
      properties: DriveBackupFile.propertiesFor(m),
      onProgress: onProgress,
    );
    await records.add(
      BackupRecord(
        id: '',
        location: BackupLocation.drive,
        createdAt: m.createdAt,
        sizeBytes: built.bytes.length,
        itemCount: m.itemCount,
        isEncrypted: m.isEncrypted,
        driveFileId: file.id,
      ),
    );
    return DriveBackupFile.fromFile(file) ??
        DriveBackupFile(
          fileId: file.id,
          name: file.name,
          createdAt: m.createdAt,
          deviceId: deviceId,
        );
  }

  /// The salt other devices use for encrypted backups (null = none yet).
  /// Pass it to BackupKeyStore.enable so this device's key matches.
  Future<BackupKdfParams?> sharedKdfParams() async =>
      (await manifest()).encryption;
}
