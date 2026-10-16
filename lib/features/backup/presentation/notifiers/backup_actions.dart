/// ============================================================
/// BACKUP ACTIONS — the commands behind screen 34 and the restore flow
/// ============================================================
///
/// What: back up to the device now, open a backup for preview (Drive or
/// local), restore it (Merge / Replace, PIN when encrypted), download /
/// delete history rows, turn on backup encryption (or explicitly back up
/// without it), settle the Restore / Start fresh choice, disconnect.
/// Why: widgets only call these; every service comes from providers. After
/// a restore the notification plan is rebuilt (restored reminders/habits
/// get their alerts back, removed ones lose them).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

class BackupActions {
  BackupActions(this.ref);

  final Ref ref;

  /// "Back up to device now".
  Future<BackupRecord> backUpToDevice() =>
      ref.read(localBackupsProvider).backupNow();

  /// Downloads / reads a backup for the restore preview. Throws
  /// [DriveFailure] / [FormatException].
  Future<BackupArchive> open(RestoreCandidate c) async {
    final engine = ref.read(backupEngineProvider);
    if (c.driveFileId case final id?) {
      return ref.read(driveSyncProvider).download(id);
    }
    final bytes = await ref.read(localBackupsProvider).read(c.record!);
    if (bytes == null) {
      throw const FormatException('This backup file is no longer on device');
    }
    return engine.inspect(bytes);
  }

  /// Restores [archive]. Throws [WrongBackupPin] (wrong / missing PIN) or
  /// [FormatException] before anything is written.
  Future<RestoreResult> restore(
    BackupArchive archive, {
    required RestoreMode mode,
    String? pin,
  }) async {
    final engine = ref.read(backupEngineProvider);
    final key = pin == null ? null : await engine.keyFor(archive.manifest, pin);
    // Verify the PIN first (cheap) so a wrong one never starts a restore.
    if (archive.manifest.isEncrypted) {
      await engine.openSnapshot(archive, key: key);
    }
    final result = await engine.restore(archive, mode: mode, key: key);
    await _noteRestored(archive.manifest, mode);
    try {
      await ref.read(notificationEngineProvider).onResume();
    } on Object catch (e) {
      AppLogger.w('Re-plan after restore failed (${e.runtimeType})');
    }
    return result;
  }

  /// Sync bookkeeping after a restore: the restored backup counts as
  /// merged, a pending Restore / Start fresh choice is settled, and after
  /// Replace earlier merges and "Last sync" no longer describe this
  /// device's data (the next sync backs the restored state up again).
  Future<void> _noteRestored(BackupManifest m, RestoreMode mode) async {
    final replace = mode == RestoreMode.replace;
    try {
      await ref.read(driveSyncProvider).noteRestored(m, replace: replace);
      if (replace) {
        await ref.read(syncStatusProvider.notifier).forgetLastSync();
      }
      ref.invalidate(mergeDecisionPendingProvider);
    } on Object catch (e) {
      AppLogger.w('Sync state after restore not saved (${e.runtimeType})');
    }
  }

  /// "Download" a history row → system save dialog. False = cancelled.
  Future<bool> download(BackupRecord r) async {
    final local = ref.read(localBackupsProvider);
    if (r.location == BackupLocation.local) return local.saveToDevice(r);
    final id = r.driveFileId;
    if (id == null) return false;
    final bytes = await ref.read(driveSyncProvider).downloadBytes(id);
    return local.saveBytes(
      'FocusFlow-${r.createdAt.toIso8601String().substring(0, 10)}.ffbackup',
      bytes,
    );
  }

  /// Deletes a history row and its file (Drive or device).
  Future<void> delete(BackupRecord r) async {
    if (r.location == BackupLocation.local) {
      await ref.read(localBackupsProvider).delete(r);
      return;
    }
    if (r.driveFileId case final id?) {
      await ref.read(driveSyncProvider).deleteBackup(id);
    }
    await ref.read(backupRecordsRepositoryProvider).delete(r.id);
  }

  /// "Encrypt backups" on: derives the backup key from [pin] (sharing the
  /// salt other devices already use, so their backups stay readable).
  Future<void> enableEncryption(String pin) async {
    BackupKdfParams? params;
    final account = ref.read(cloudAccountProvider);
    if (account != null && account.hasDrive) {
      try {
        params = await ref.read(driveSyncProvider).sharedKdfParams();
      } on DriveFailure {
        params = null;
      }
    }
    await ref.read(backupKeyStoreProvider).enable(pin, params: params);
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(encryptBackups: true));
    ref.invalidate(backupKeyStateProvider);
  }

  Future<void> setEncrypt(bool on) async {
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(encryptBackups: on));
    ref.invalidate(backupKeyStateProvider);
  }

  /// The explicit "Back up without encryption" choice: turns "Encrypt
  /// backups" off so backups run (labelled "not encrypted").
  Future<void> backUpWithoutEncryption() => setEncrypt(false);

  /// "Start fresh": existing Drive backups from other devices are not
  /// merged automatically (a manual Restore still offers them).
  Future<void> startFresh() async {
    await ref.read(driveSyncProvider).startFresh();
    ref.invalidate(mergeDecisionPendingProvider);
  }

  /// "Merge them automatically": resume merging other devices' backups.
  Future<void> resumeMerging() async {
    await ref.read(driveSyncProvider).resumeMerging();
    ref.invalidate(mergeDecisionPendingProvider);
  }

  /// "Disconnect Google account" (local data stays).
  Future<void> disconnect() =>
      ref.read(cloudAccountControllerProvider).signOut();
}
