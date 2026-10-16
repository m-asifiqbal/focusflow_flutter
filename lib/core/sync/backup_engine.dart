/// ============================================================
/// BACKUP ENGINE — build, open and restore `.ffbackup` files
/// ============================================================
///
/// The one entry point the Backup & Sync / Import screens and the Drive
/// sync use (see backup_format.dart for the file layout):
///
/// * [BackupEngine.build] — snapshot of every synced table + the files
///   attachment rows and note covers point to, optionally sealed with a
///   [BackupKey] (Argon2id → AES-256-GCM). Vault rows are ciphertext
///   already and are exported as-is; the manifest carries the PIN-wrapped
///   vault key envelope so another device can use them.
/// * [BackupEngine.inspect] / [BackupEngine.openSnapshot] — preview counts
///   without touching the database; decrypt + verify the checksum.
/// * [BackupEngine.restore] — **Replace** (the database becomes exactly
///   the backup, without spurious tombstones) or **Merge** (last-write-wins
///   per item, see SnapshotMerger). Everything that can fail (wrong PIN,
///   damaged file) fails *before* the database changes.
///
/// Vault rows only travel when the vault bridge accepts the backup's key
/// envelope (same vault key, or no vault here yet). Otherwise Replace keeps
/// this device's vault and Merge leaves it alone.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/device_profile.dart';
import 'package:focusflow/core/sync/merge_report.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';
import 'package:focusflow/core/sync/snapshot_merger.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// How a restore treats the data already on this device.
enum RestoreMode {
  /// Keep local work; newer version of each item wins.
  merge,

  /// Make this device exactly the backup.
  replace,
}

/// A freshly built backup: zip bytes + the manifest written into it.
@immutable
class BuiltBackup {
  const BuiltBackup({required this.bytes, required this.manifest});

  final Uint8List bytes;
  final BackupManifest manifest;
}

/// What a restore did.
@immutable
class RestoreResult {
  const RestoreResult({
    required this.mode,
    required this.report,
    this.vaultRestored = true,
    this.filesRestored = 0,
    this.filesMissing = 0,
  });

  final RestoreMode mode;

  /// Merge: per-item outcome. Replace: `added` = items restored.
  final MergeReport report;

  /// False when the backup's vault rows were left out (another vault key).
  final bool vaultRestored;

  /// Attachment / cover files written to app documents.
  final int filesRestored;

  /// Referenced files the backup did not contain (or could not open).
  final int filesMissing;
}

class BackupEngine {
  BackupEngine({
    required this.db,
    required this.items,
    required this.files,
    required this.deviceId,
    required this.vault,
    Future<DeviceProfile> Function()? profile,
    this.clock = const Clock(),
  }) : _profile = profile ?? (() async => DeviceProfile.fallback);

  final AppDatabase db;
  final ItemsRepository items;
  final AppFiles files;
  final String deviceId;
  final VaultBackupBridge vault;
  final Clock clock;
  final Future<DeviceProfile> Function() _profile;

  SnapshotIo get _io => SnapshotIo(db, deviceId: deviceId);

  /// Reads the whole database (raw rows) — tests and the sync engine.
  Future<DbSnapshot> snapshot() => _io.read();

  // ─────────────────────────────── Build ───────────────────────────────

  /// Builds a `.ffbackup`. [key] null = not encrypted. [devices] are the
  /// devices already known for this account (this one is added/updated).
  ///
  /// [filter] narrows the snapshot (Import & Export: chosen modules, no
  /// trash); [includeFiles] false leaves attachments/covers out.
  Future<BuiltBackup> build({
    BackupKey? key,
    bool isAuto = false,
    List<LinkedDevice> devices = const [],
    DbSnapshot Function(DbSnapshot snapshot)? filter,
    bool includeFiles = true,
  }) async {
    final full = await _io.read();
    final snapshot = filter == null ? full : filter(full);
    final plain = snapshot.encode();
    final payloads = <String, Uint8List>{};
    final carried = includeFiles ? referencedFiles(snapshot) : <String>{};
    for (final path in carried) {
      final bytes = await files.read(path);
      if (bytes == null) continue;
      payloads[path] = key == null
          ? bytes
          : await BackupCipher.seal(bytes, key);
    }
    final profile = await _profile();
    final createdAt = clock.now();
    final self = LinkedDevice(
      deviceId: deviceId,
      name: profile.name,
      platform: profile.platform,
      lastSyncAt: createdAt,
    );
    final manifest = BackupManifest(
      schemaVersion: db.schemaVersion,
      appVersion: profile.appVersion,
      createdAt: createdAt,
      deviceId: deviceId,
      deviceName: profile.name,
      platform: profile.platform,
      counts: snapshot.counts,
      itemCount: snapshot.itemCount,
      checksum: BackupArchive.sha256Hex(plain),
      encryption: key?.params,
      attachments: payloads.keys.toList()..sort(),
      devices: LinkedDevice.union([self], devices),
      vaultKey: snapshot.rows('vault_items').isEmpty && filter != null
          ? null
          : await vault.exportKeyEnvelope(),
      isAuto: isAuto,
    );
    final archive = BackupArchive(
      manifest: manifest,
      dbJson: key == null ? plain : await BackupCipher.seal(plain, key),
      files: payloads,
    );
    return BuiltBackup(bytes: archive.encode(), manifest: manifest);
  }

  /// Folders (relative to app documents) that backups may carry files
  /// for. A restore never writes anywhere else, whatever a crafted
  /// backup's rows point to.
  static const List<String> fileDirs = ['attachments/', 'covers/'];

  /// Relative paths of every file the snapshot's rows point to (inside
  /// [fileDirs]).
  static Set<String> referencedFiles(DbSnapshot s) => {
    for (final r in s.rows('attachments'))
      if (r['local_path'] case final String p when _carried(p)) p,
    for (final r in s.rows('notes'))
      if (r['cover_image_path'] case final String p when _carried(p)) p,
  };

  static bool _carried(String path) =>
      !path.contains('..') && fileDirs.any(path.startsWith);

  // ─────────────────────────────── Open ───────────────────────────────

  /// Unzips [bytes] and reads the manifest (restore preview). Throws
  /// [FormatException] for anything that is not a FocusFlow backup, and
  /// [BackupTooNew] for a backup from a newer database schema.
  BackupArchive inspect(List<int> bytes) {
    final archive = BackupArchive.decode(bytes);
    archive.manifest.checkReadableBy(db.schemaVersion);
    return archive;
  }

  /// The key that opens [manifest]'s archive, derived from [pin]; null for
  /// an unencrypted backup.
  Future<BackupKey?> keyFor(BackupManifest manifest, String pin) async {
    final params = manifest.encryption;
    if (params == null) return null;
    return BackupCipher.deriveKey(pin, params);
  }

  /// Decrypts (when needed) and checksum-verifies db.json. Throws
  /// [WrongBackupPin] or [FormatException] ([BackupTooNew] included).
  Future<DbSnapshot> openSnapshot(
    BackupArchive archive, {
    BackupKey? key,
  }) async {
    archive.manifest.checkReadableBy(db.schemaVersion);
    var bytes = archive.dbJson;
    if (archive.manifest.isEncrypted) {
      if (key == null) throw const WrongBackupPin();
      bytes = await BackupCipher.open(bytes, key);
    }
    if (BackupArchive.sha256Hex(bytes) != archive.manifest.checksum) {
      throw const FormatException('The backup file is damaged');
    }
    return DbSnapshot.decode(bytes);
  }

  // ────────────────────────────── Restore ──────────────────────────────

  /// Restores [archive] (see the file header). Throws [WrongBackupPin] /
  /// [FormatException] before anything changes, and [RestoreFailed] when
  /// writing failed (the database transaction rolled back; the vault key
  /// may already have been swapped — see [RestoreFailed.vaultKeyChanged]).
  Future<RestoreResult> restore(
    BackupArchive archive, {
    required RestoreMode mode,
    BackupKey? key,
  }) async {
    final incoming = await openSnapshot(archive, key: key);
    final keyBefore = await _vaultKeyId();
    final bool vaultOk;
    final MergeReport report;
    final Set<String> wanted;
    try {
      vaultOk = await vault.acceptKeyEnvelope(archive.manifest.vaultKey);
      switch (mode) {
        case RestoreMode.replace:
          final target = vaultOk
              ? incoming
              : keepLocalVault(incoming, await _io.read());
          await _io.replaceAll(target);
          report = MergeReport(
            added: target.itemCount,
            vaultSkipped: vaultOk ? 0 : incoming.rows('vault_items').length,
          );
          wanted = referencedFiles(target);
        case RestoreMode.merge:
          report = await SnapshotMerger(
            db: db,
            io: _io,
            items: items,
          ).merge(incoming, mergeVault: vaultOk);
          wanted = report.filesNeeded;
      }
    } on Object catch (e) {
      final keyAfter = await _vaultKeyId();
      throw RestoreFailed(
        vaultKeyChanged: keyAfter != keyBefore,
        cause: e.runtimeType.toString(),
      );
    }
    var restored = 0;
    var missing = 0;
    for (final path in wanted.where(_carried)) {
      final sealed = archive.files[path];
      if (sealed == null) {
        if (!await files.exists(path)) missing++;
        continue;
      }
      try {
        final bytes = key == null || !archive.manifest.isEncrypted
            ? sealed
            : await BackupCipher.open(sealed, key);
        if (await files.write(path, bytes) != null) {
          restored++;
        } else {
          missing++;
        }
      } on Object {
        // The items are restored already; one unreadable file is reported
        // as missing instead of failing the whole restore.
        missing++;
      }
    }
    return RestoreResult(
      mode: mode,
      report: report,
      vaultRestored: vaultOk,
      filesRestored: restored,
      filesMissing: missing,
    );
  }

  /// The local vault's key id (null = no vault / unreadable).
  Future<Object?> _vaultKeyId() async {
    try {
      return (await vault.exportKeyEnvelope())?['keyId'];
    } on Object {
      return null;
    }
  }

  /// [incoming] with every vault row (items, history, their tags /
  /// attachments, vault folders, vault tombstones) taken from [local]
  /// instead — a Replace restore never swaps in vault ciphertext this
  /// device cannot open.
  @visibleForTesting
  static DbSnapshot keepLocalVault(DbSnapshot incoming, DbSnapshot local) {
    final vaultKey = ItemType.vault.key;
    bool isVault(String table, RawRow r) => switch (table) {
      'vault_items' || 'vault_history' => true,
      'item_tags' || 'attachments' => r['item_type'] == vaultKey,
      'tombstones' => r['entity'] == vaultKey,
      _ => false,
    };
    final tagIds = {for (final r in incoming.rows('tags')) r['id']};
    final folderIds = {for (final r in incoming.rows('folders')) r['id']};
    return DbSnapshot({
      for (final table in kSnapshotTables)
        table: [
          ...incoming.rows(table).where((r) => !isVault(table, r)),
          ...local
              .rows(table)
              .where(
                (r) =>
                    isVault(table, r) &&
                    (table != 'item_tags' || tagIds.contains(r['tag_id'])),
              ),
          if (table == 'folders')
            ...local
                .rows('folders')
                .where(
                  (r) =>
                      r['module'] == vaultKey && !folderIds.contains(r['id']),
                ),
        ],
    });
  }
}

/// Writing a restore failed. The database change was rolled back (Replace
/// and Merge each run in one transaction), so the items are as they were;
/// [vaultKeyChanged] says whether the backup's vault key had already been
/// adopted (an empty local vault now opens with the backup's PIN).
class RestoreFailed implements Exception {
  const RestoreFailed({required this.vaultKeyChanged, this.cause});

  final bool vaultKeyChanged;

  /// Error type for logs (never contents).
  final String? cause;

  @override
  String toString() =>
      'RestoreFailed(vaultKeyChanged: $vaultKeyChanged, cause: $cause)';
}

/// Files under the app documents directory.
final appFilesProvider = Provider<AppFiles>((ref) => AppFiles());

/// The backup engine over the app database.
final backupEngineProvider = Provider<BackupEngine>(
  (ref) => BackupEngine(
    db: ref.watch(databaseProvider),
    items: ref.watch(itemsRepositoryProvider),
    files: ref.watch(appFilesProvider),
    deviceId: ref.watch(deviceIdProvider),
    vault: ref.watch(vaultBridgeProvider),
    profile: () => ref.read(deviceProfileProvider.future),
    clock: ref.watch(clockProvider),
  ),
);
