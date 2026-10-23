/// ============================================================
/// BACKUP PROVIDERS — read models for screens 34 / 35 / restore
/// ============================================================
///
/// What: live backup history, Drive app-folder usage, library item count,
/// "has a backup key", restore candidates (Drive + local), the export
/// service / counts and the import writer.
/// Why: screens only watch these; services come from core/sync and the
/// repositories (never built in widgets).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/backup/data/export_counts_source.dart';
import 'package:focusflow/features/backup/data/export_service.dart';
import 'package:focusflow/features/backup/data/import_file_source.dart';
import 'package:focusflow/features/backup/data/import_writer.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// HISTORY rows (this device's Drive + local backups), newest first.
final backupHistoryProvider = StreamProvider.autoDispose<List<BackupRecord>>(
  (ref) => ref.watch(backupRecordsRepositoryProvider).watchAll(),
);

/// Items in the library ("· 113 items").
final backupItemCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(itemsRepositoryProvider)
      .watchLibraryCounts()
      .map(
        (LibraryCounts c) =>
            c.notesTotal +
            c.tasksTotal +
            c.remindersTotal +
            c.habitsTotal +
            c.vaultTotal,
      ),
);

/// App-folder usage; null when not connected. Refreshes after each sync.
final driveUsageProvider = FutureProvider.autoDispose<DriveUsage?>((ref) async {
  final account = ref.watch(cloudAccountProvider);
  ref.watch(syncStatusProvider.select((s) => s.lastSyncAt));
  ref.watch(backupHistoryProvider.select((h) => h.valueOrNull?.length));
  if (account == null || !account.hasDrive) return null;
  try {
    return await ref.read(driveSyncProvider).usage();
  } on DriveFailure {
    return null;
  }
});

/// What the keychain holds for "Encrypt backups" (present / absent /
/// unreadable) — drives the Encrypt row and the "set a backup PIN" banner.
final backupKeyStateProvider = FutureProvider.autoDispose<BackupKeyState>(
  (ref) => ref.watch(backupKeyPolicyProvider).state(),
);

/// Sign-in found Drive backups and the user hasn't chosen Restore or Start
/// fresh yet (merging waits; Backup & Sync shows a banner).
final mergeDecisionPendingProvider = Provider.autoDispose<bool>((ref) {
  ref.watch(syncStatusProvider.select((s) => s.phase));
  return ref.read(driveSyncProvider).state.decisionPending;
});

/// Whether a usable backup key exists (Encrypt backups row subtitle).
final backupKeyExistsProvider = FutureProvider.autoDispose<bool>(
  (ref) async =>
      await ref.watch(backupKeyStateProvider.future) == BackupKeyState.present,
);

/// Where a restore candidate lives.
enum RestoreSourceKind { drive, local }

/// One backup the restore picker offers.
class RestoreCandidate {
  const RestoreCandidate({
    required this.kind,
    required this.createdAt,
    required this.sizeBytes,
    required this.itemCount,
    required this.isEncrypted,
    this.isAuto = false,
    this.deviceName = '',
    this.driveFileId,
    this.record,
  });

  final RestoreSourceKind kind;
  final DateTime createdAt;
  final int sizeBytes;
  final int itemCount;
  final bool isEncrypted;
  final bool isAuto;
  final String deviceName;
  final String? driveFileId;
  final BackupRecord? record;
}

/// The restore picker's list: every Drive backup (all devices) and this
/// device's local backups. [driveError] is set when Drive could not be
/// listed (offline…) — local backups still show.
class RestoreCandidates {
  const RestoreCandidates(this.items, {this.driveError});

  final List<RestoreCandidate> items;
  final DriveFailure? driveError;
}

final restoreCandidatesProvider = FutureProvider.autoDispose<RestoreCandidates>(
  (ref) async {
    final account = ref.watch(cloudAccountProvider);
    final records = await ref
        .watch(backupRecordsRepositoryProvider)
        .watchAll(location: BackupLocation.local)
        .first;
    final items = <RestoreCandidate>[
      for (final r in records)
        RestoreCandidate(
          kind: RestoreSourceKind.local,
          createdAt: r.createdAt,
          sizeBytes: r.sizeBytes,
          itemCount: r.itemCount,
          isEncrypted: r.isEncrypted,
          isAuto: r.isAuto,
          record: r,
        ),
    ];
    DriveFailure? error;
    if (account != null && account.hasDrive) {
      try {
        final drive = await ref.read(driveSyncProvider).listBackups();
        items.addAll([
          for (final f in drive)
            RestoreCandidate(
              kind: RestoreSourceKind.drive,
              createdAt: f.createdAt,
              sizeBytes: f.sizeBytes,
              itemCount: f.itemCount,
              isEncrypted: f.isEncrypted,
              isAuto: f.isAuto,
              deviceName: f.deviceName,
              driveFileId: f.fileId,
            ),
        ]);
      } on DriveFailure catch (f) {
        error = f;
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return RestoreCandidates(items, driveError: error);
  },
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    engine: ref.watch(backupEngineProvider),
    keys: ref.watch(backupKeyPolicyProvider),
    encryptBackups: () => ref.read(settingsProvider).encryptBackups,
    drive: ref.watch(driveSyncProvider),
    local: ref.watch(localBackupsProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// INCLUDE counts, live.
final exportCountsProvider = StreamProvider.autoDispose<ExportCounts>(
  (ref) => ExportCountsSource(ref.watch(databaseProvider)).watch(),
);

final importFileSourceProvider = Provider<ImportFileSource>(
  (ref) => const PlatformImportFileSource(),
);

final importWriterProvider = Provider<ImportWriter>((ref) {
  final engine = ref.watch(backupEngineProvider);
  return ImportWriter(
    db: ref.watch(databaseProvider),
    snapshot: engine.snapshot,
    notes: ref.watch(notesRepositoryProvider),
    tasks: ref.watch(tasksRepositoryProvider),
    reminders: ref.watch(remindersRepositoryProvider),
    habits: ref.watch(habitsRepositoryProvider),
    medicines: ref.watch(medicinesRepositoryProvider),
    items: ref.watch(itemsRepositoryProvider),
    vault: ref.watch(vaultBridgeProvider),
    vaultLogin: (id, blob) async {
      // Only while the vault is unlocked (password import requires it);
      // anything unreadable is "unknown", never a duplicate.
      final key = ref.read(vaultSessionProvider).key;
      if (key == null || key.isDestroyed) return null;
      try {
        final p = await VaultPayloadCodec.open(key, blob, itemId: id);
        return (username: p.username, url: p.url);
      } on Object {
        return null;
      }
    },
    clock: ref.watch(clockProvider),
  );
});
