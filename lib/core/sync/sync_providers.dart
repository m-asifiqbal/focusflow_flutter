/// ============================================================
/// SYNC PROVIDERS — wiring for backups (local + Drive)
/// ============================================================
///
/// Screens 34/35/36 and the background job read these instead of building
/// the services themselves:
/// * [backupKeyStoreProvider] — "Encrypt backups" key (keychain), and
///   [backupKeyPolicyProvider] — which key (if any) seals a backup;
/// * [driveStoreFactoryProvider] — opens appDataFolder for the signed-in
///   Google account (null when signed out / not configured);
/// * [driveSyncProvider] — Sync now, Drive history, linked devices;
/// * [localBackupsProvider] — Documents/FocusFlow, Save to device.
/// Settings (Keep last N, Encrypt backups) are read at call time so a
/// change applies to the next backup without rebuilding anything.
/// ============================================================
library;

// Callers that only see DriveSync through these providers still get its
// extension operations (list/download/delete backups, devices, usage).
export 'package:focusflow/core/sync/drive_sync.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/drive_sync.dart';
import 'package:focusflow/core/sync/google_drive_store.dart';
import 'package:focusflow/core/sync/local_backups.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:http/http.dart' as http;

/// The stored backup encryption key ("Encrypt backups").
final backupKeyStoreProvider = Provider<BackupKeyStore>(
  (ref) => BackupKeyStore(ref.watch(secureStoreProvider)),
);

/// Which key seals the next backup (never silent plaintext; keychain
/// errors fail the backup) — see backup_key_policy.dart.
final backupKeyPolicyProvider = Provider<BackupKeyPolicy>(
  (ref) => BackupKeyPolicy(
    keys: ref.watch(backupKeyStoreProvider),
    secure: ref.watch(secureStoreProvider),
  ),
);

/// One HTTP client for Drive calls, closed with the container.
final driveHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Opens the Google account's Drive folder; null when there is no Google
/// account or Drive is not set up in this build. Tests override this with
/// an in-memory store.
final driveStoreFactoryProvider = Provider<DriveStoreFactory>((ref) {
  return ({bool interactive = false}) async {
    // Background isolates start with no account until the keychain read.
    await ref.read(cloudAccountProvider.notifier).loaded;
    final account = ref.read(cloudAccountProvider);
    final controller = ref.read(cloudAccountControllerProvider);
    if (account == null || !account.hasDrive) return null;
    if (!controller.googleAvailable || controller is! DriveTokenSource) {
      return null;
    }
    return GoogleDriveStore(
      controller as DriveTokenSource,
      httpClient: ref.read(driveHttpClientProvider),
      interactive: interactive,
    );
  };
});

final driveSyncProvider = Provider<DriveSync>(
  (ref) => DriveSync(
    engine: ref.watch(backupEngineProvider),
    openStore: ref.watch(driveStoreFactoryProvider),
    keys: ref.watch(backupKeyPolicyProvider),
    records: ref.watch(backupRecordsRepositoryProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    deviceId: ref.watch(deviceIdProvider),
    keepBackups: () => ref.read(settingsProvider).keepBackups,
    encryptBackups: () => ref.read(settingsProvider).encryptBackups,
    clock: ref.watch(clockProvider),
  ),
);

final localBackupsProvider = Provider<LocalBackups>(
  (ref) => LocalBackups(
    engine: ref.watch(backupEngineProvider),
    files: ref.watch(appFilesProvider),
    keys: ref.watch(backupKeyPolicyProvider),
    records: ref.watch(backupRecordsRepositoryProvider),
    keepBackups: () => ref.read(settingsProvider).keepBackups,
    encryptBackups: () => ref.read(settingsProvider).encryptBackups,
    clock: ref.watch(clockProvider),
  ),
);
