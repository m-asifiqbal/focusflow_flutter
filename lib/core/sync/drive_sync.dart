/// ============================================================
/// DRIVE SYNC — "Sync now", Drive history, linked devices
/// ============================================================
///
/// Sync now (screen 34, auto backup):
///   1. Preparing… pick the key (BackupKeyPolicy: "Encrypt backups" on
///      without a backup PIN → [BackupPinRequired], never silent
///      plaintext) and build a `.ffbackup`;
///   2. Uploading 40%… into appDataFolder + a local history record;
///   3. prune this device's Drive backups to "Keep last N";
///   4. update `focusflow-devices.json` (linked devices, shared KDF salt);
///   5. merge (last-write-wins per item) the newest backup of every *other*
///      device that is newer than the one handled last time.
/// Only steps 1–2 can fail the sync. After the upload every step is
/// isolated: a prune / manifest / merge problem becomes a
/// [SyncOutcome.warnings] line, so one unreadable backup from another
/// device (damaged, newer schema, wrong key) never fails every future
/// sync and never makes the scheduler upload + prune again and again.
/// Merge progress is saved after each backup.
/// Encrypted backups from another device merge only when our stored key
/// opens them (same PIN + shared salt); the rest are counted as
/// [SyncOutcome.needsPin] and left for a manual Restore. Nothing merges
/// while the sign-in "Restore / Start fresh" choice is outstanding
/// ([DriveSyncState.decisionPending]).
///
/// Drive errors before the upload surface as [DriveFailure] (offline /
/// sign in again / Drive full). Progress is reported through
/// [SyncProgress].
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/drive_sync_models.dart';
import 'package:focusflow/core/sync/drive_sync_state.dart';
import 'package:focusflow/core/sync/merge_report.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/domain/repository/backup_records_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:focusflow/core/sync/drive_sync_account.dart';
export 'package:focusflow/core/sync/drive_sync_models.dart';

/// Phase + progress callback (drives [SyncStatus]).
typedef SyncProgress = void Function(SyncPhase phase, double? progress);

class DriveSync {
  DriveSync({
    required this.engine,
    required this.openStore,
    required this.keys,
    required this.records,
    required this.prefs,
    required this.deviceId,
    required this.keepBackups,
    required this.encryptBackups,
    this.clock = const Clock(),
  }) : state = DriveSyncState(prefs);

  final BackupEngine engine;
  final DriveStoreFactory openStore;
  final BackupKeyPolicy keys;
  final BackupRecordsRepository records;
  final SharedPreferences prefs;
  final String deviceId;
  final int Function() keepBackups;
  final bool Function() encryptBackups;
  final Clock clock;

  /// Which other-device backups were handled; the Restore / Start fresh
  /// decision.
  final DriveSyncState state;

  /// Prefs key of the merged-backups map (see [DriveSyncState]).
  static const String mergedKey = DriveSyncState.mergedKey;

  /// The account's Drive folder; throws [DriveFailure] (not signed in).
  /// Public for DriveSync's extensions (drive_sync_account.dart).
  Future<DriveStore> requireStore({bool interactive = false}) async {
    final store = await openStore(interactive: interactive);
    if (store == null) {
      throw const DriveFailure(DriveFailureKind.notSignedIn);
    }
    return store;
  }

  // ───────────────────────────── Sync now ─────────────────────────────

  /// Backs up to Drive, prunes and (when [merge]) merges other devices'
  /// newer backups. Throws [DriveFailure], [BackupPinRequired] or
  /// [BackupKeyUnavailable] — only before / during the upload.
  Future<SyncOutcome> syncNow({
    bool isAuto = false,
    bool merge = true,
    bool interactive = false,
    SyncProgress? onProgress,
  }) async {
    void report(SyncPhase p, [double? v]) => onProgress?.call(p, v);
    report(SyncPhase.preparing);
    // Decided before Drive is touched: no key → no upload at all.
    final key = await keys.forBackup(encrypt: encryptBackups());
    final store = await requireStore(interactive: interactive);
    final files = await store.list();
    final manifestFile = files.where(DriveManifest.isManifest).firstOrNull;
    var manifest = manifestFile == null
        ? const DriveManifest()
        : DriveManifest.decode(await store.download(manifestFile.id));
    final backups = files.map(DriveBackupFile.fromFile).nonNulls.toList();

    final built = await engine.build(
      key: key,
      isAuto: isAuto,
      devices: manifest.devices,
    );

    report(SyncPhase.uploading, 0);
    final m = built.manifest;
    final file = await store.upload(
      DriveBackupFile.fileNameFor(m.createdAt, deviceId),
      built.bytes,
      properties: DriveBackupFile.propertiesFor(m),
      onProgress: (v) => report(SyncPhase.uploading, v),
    );
    final uploaded =
        DriveBackupFile.fromFile(file) ??
        DriveBackupFile(
          fileId: file.id,
          name: file.name,
          createdAt: m.createdAt,
          deviceId: deviceId,
        );
    final warnings = <String>[];
    try {
      await records.add(
        BackupRecord(
          id: '',
          location: BackupLocation.drive,
          createdAt: m.createdAt,
          sizeBytes: built.bytes.length,
          itemCount: m.itemCount,
          isAuto: isAuto,
          isEncrypted: m.isEncrypted,
          driveFileId: file.id,
        ),
      );
    } on Object catch (e) {
      AppLogger.w('Backup history record failed (${e.runtimeType})');
    }

    // ── From here on the backup is safe in Drive: nothing below fails
    // the sync (see the file header).
    final pruned = await _prune(store, uploaded, backups, warnings);

    // Linked devices + shared KDF salt.
    manifest = manifest.copyWith(
      devices: m.devices,
      encryption: manifest.encryption ?? key?.params,
      updatedAt: m.createdAt,
    );
    try {
      if (manifestFile == null) {
        await store.upload(
          DriveManifest.fileName,
          manifest.encode(),
          mimeType: 'application/json',
          properties: const {
            DriveBackupFile.kindKey: DriveManifest.kindManifest,
          },
        );
      } else {
        await store.overwrite(manifestFile.id, manifest.encode());
      }
    } on Object catch (e) {
      AppLogger.w('Devices manifest update failed (${e.runtimeType})');
      warnings.add("Linked devices couldn't be updated this time");
    }

    if (!merge || state.decisionPending) {
      report(SyncPhase.done, 1);
      return SyncOutcome(
        uploaded: uploaded,
        pruned: pruned,
        warnings: warnings,
        mergeDeferred: merge && state.decisionPending,
      );
    }
    return _mergeOthers(
      store,
      backups,
      key,
      uploaded,
      pruned,
      warnings,
      report,
    );
  }

  /// "Keep last N" for this device's Drive backups. Failures are warnings
  /// (retried on the next sync).
  Future<int> _prune(
    DriveStore store,
    DriveBackupFile uploaded,
    List<DriveBackupFile> backups,
    List<String> warnings,
  ) async {
    final keep = keepBackups().clamp(1, 100);
    final mine = [uploaded, ...backups.where((b) => b.deviceId == deviceId)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var pruned = 0;
    try {
      for (final old in mine.skip(keep)) {
        await store.delete(old.fileId);
        pruned++;
      }
      await records.pruneTo(keep, location: BackupLocation.drive);
    } on Object catch (e) {
      AppLogger.w('Pruning old backups failed (${e.runtimeType})');
      warnings.add("Old backups couldn't be removed; we'll try next time");
    }
    return pruned;
  }

  Future<SyncOutcome> _mergeOthers(
    DriveStore store,
    List<DriveBackupFile> backups,
    BackupKey? key,
    DriveBackupFile uploaded,
    int pruned,
    List<String> warnings,
    void Function(SyncPhase p, [double? v]) report,
  ) async {
    final merged = state.merged();
    final newestPerDevice = <String, DriveBackupFile>{};
    for (final b in backups) {
      if (b.deviceId.isEmpty || b.deviceId == deviceId) continue;
      final cur = newestPerDevice[b.deviceId];
      if (cur == null || b.createdAt.isAfter(cur.createdAt)) {
        newestPerDevice[b.deviceId] = b;
      }
    }
    final due = newestPerDevice.values.where((b) {
      final last = merged[b.deviceId];
      return last == null || b.createdAt.isAfter(last);
    }).toList();

    var total = const MergeReport();
    var count = 0;
    var needsPin = 0;
    for (final (i, b) in due.indexed) {
      report(SyncPhase.downloading, i / due.length);
      if (b.isEncrypted &&
          (key == null || b.kdfSalt != base64Encode(key.params.salt))) {
        needsPin++;
        continue;
      }
      final from = b.deviceName.isEmpty ? 'another device' : b.deviceName;
      try {
        final archive = engine.inspect(await store.download(b.fileId));
        report(SyncPhase.merging);
        final result = await engine.restore(
          archive,
          mode: RestoreMode.merge,
          key: archive.manifest.isEncrypted ? key : null,
          // Another device's backup brings its items, never its settings:
          // each phone keeps its own configuration.
          applySettings: false,
        );
        total = total + result.report;
        count++;
        await state.markHandled(b.deviceId, b.createdAt);
      } on WrongBackupPin {
        // Retried once this device has the right backup PIN.
        needsPin++;
      } on RestoreFailed {
        // Writing failed and was rolled back: try again next sync.
        warnings.add("Couldn't merge the backup from $from; we'll try again");
      } on BackupTooNew {
        // Retried after the app is updated.
        warnings.add('Update FocusFlow to read the backup from $from');
      } on DriveFailure catch (f) {
        // Offline / signed out mid-way: try again next sync.
        AppLogger.w('Merge download failed (${f.kind.name})');
        warnings.add("Couldn't check other devices' backups this time");
        break;
      } on Object catch (e) {
        // Damaged or otherwise unreadable: skip this version for good (its
        // device's next backup supersedes it) and keep going.
        AppLogger.w('Skipped an unreadable backup (${e.runtimeType})');
        warnings.add("Couldn't read the backup from $from");
        await state.markHandled(b.deviceId, b.createdAt);
      }
    }
    report(SyncPhase.done, 1);
    return SyncOutcome(
      uploaded: uploaded,
      pruned: pruned,
      mergedBackups: count,
      report: total,
      needsPin: needsPin,
      warnings: warnings,
    );
  }
}
