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
///
/// The app's settings travel too (`settings.json`, see BackupSettings): a
/// restore puts them back — Replace takes the backup's, Merge only fills in
/// what is still at its default — unless the caller opts out (Drive's
/// automatic merge of another device's backup never touches this device's
/// settings). A damaged settings entry only skips the settings. The profile
/// picture goes with the settings (full backups only): Replace puts the
/// backup's back, Merge only when this device has none.
///
/// [BuiltBackup.contentHash] / [BackupEngine.fingerprint] name everything a
/// full backup carries (data, settings, profile picture), so a sync can see
/// that Drive already holds exactly this device's current state.
/// ============================================================
library;

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/device_profile.dart';
import 'package:focusflow/core/sync/merge_report.dart';
import 'package:focusflow/core/sync/settings_bridge.dart';
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
  const BuiltBackup({
    required this.bytes,
    required this.manifest,
    this.contentHash = '',
  });

  final Uint8List bytes;
  final BackupManifest manifest;

  /// SHA-256 over the plaintext content (data checksum, settings, profile
  /// picture) — see [BackupEngine.contentHashOf].
  final String contentHash;
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
    this.settingsRestored = false,
    this.settingsFailed = false,
    this.photoRestored = false,
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

  /// The backup's settings were put in effect on this device.
  final bool settingsRestored;

  /// The backup has settings that could not be read or saved (damaged, or
  /// written by a newer app). The data itself is restored regardless.
  final bool settingsFailed;

  /// The backup's profile picture was put on this device.
  final bool photoRestored;
}

class BackupEngine {
  BackupEngine({
    required this.db,
    required this.items,
    required this.files,
    required this.deviceId,
    required this.vault,
    this.settings = const NoSettingsBackupBridge(),
    Future<DeviceProfile> Function()? profile,
    this.clock = const Clock(),
  }) : _profile = profile ?? (() async => DeviceProfile.fallback);

  final AppDatabase db;
  final ItemsRepository items;
  final AppFiles files;
  final String deviceId;
  final VaultBackupBridge vault;

  /// The app's configuration carried next to the data.
  final SettingsBackupBridge settings;
  final Clock clock;
  final Future<DeviceProfile> Function() _profile;

  SnapshotIo get _io => SnapshotIo(db, deviceId: deviceId);

  /// Reads the whole database (raw rows) — tests and the sync engine.
  Future<DbSnapshot> snapshot() => _io.read();

  /// The [BuiltBackup.contentHash] a full backup would have right now:
  /// data, settings and profile picture. The snapshot is read in rowid
  /// order and the settings JSON in a fixed key order, so an unchanged
  /// device always gives the same fingerprint (the sync on app open uses it
  /// to skip re-uploading identical backups). Runs the encoding off the UI
  /// isolate, like [build].
  Future<String> fingerprint() async {
    final snapshot = await _io.read();
    final data = await Isolate.run(
      () => BackupArchive.sha256Hex(snapshot.encode()),
    );
    return contentHashOf(
      data,
      await _exportSettings(),
      await _readProfilePhoto(),
    );
  }

  /// One hash for a backup's plaintext content: the data checksum plus the
  /// settings and profile picture bytes (each null = absent).
  static String contentHashOf(
    String dataChecksum,
    Uint8List? settings,
    Uint8List? photo,
  ) {
    String part(Uint8List? b) => b == null ? '-' : BackupArchive.sha256Hex(b);
    return BackupArchive.sha256Hex(
      utf8.encode('$dataChecksum|${part(settings)}|${part(photo)}'),
    );
  }

  /// The local profile picture; null when there is none (or unreadable —
  /// never a reason to fail a backup).
  Future<Uint8List?> _readProfilePhoto() async {
    try {
      return await files.read(AppFiles.profilePhotoPath);
    } on Object {
      return null;
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  /// Builds a `.ffbackup`. [key] null = not encrypted. [devices] are the
  /// devices already known for this account (this one is added/updated).
  ///
  /// [filter] narrows the snapshot (Import & Export: chosen modules, no
  /// trash); [includeFiles] false leaves attachments/covers out;
  /// [includeSettings] false leaves the app's settings out.
  Future<BuiltBackup> build({
    BackupKey? key,
    bool isAuto = false,
    List<LinkedDevice> devices = const [],
    DbSnapshot Function(DbSnapshot snapshot)? filter,
    bool includeFiles = true,
    bool includeSettings = true,
  }) async {
    final full = await _io.read();
    final snapshot = filter == null ? full : filter(full);
    final payloads = <String, Uint8List>{};
    final carried = includeFiles ? referencedFiles(snapshot) : <String>{};
    for (final path in carried) {
      final bytes = await files.read(path);
      if (bytes == null) continue;
      payloads[path] = bytes;
    }
    final configuration = includeSettings ? await _exportSettings() : null;
    // The profile picture travels with the settings, in full backups only:
    // an export of chosen modules is data, not this person's profile.
    final photo = includeSettings && filter == null
        ? await _readProfilePhoto()
        : null;
    final profile = await _profile();
    final createdAt = clock.now();
    final self = LinkedDevice(
      deviceId: deviceId,
      name: profile.name,
      platform: profile.platform,
      lastSyncAt: createdAt,
    );
    final head = _ManifestHead(
      schemaVersion: db.schemaVersion,
      appVersion: profile.appVersion,
      createdAt: createdAt,
      deviceId: deviceId,
      deviceName: profile.name,
      platform: profile.platform,
      encryption: key?.params,
      devices: LinkedDevice.union([self], devices),
      vaultKey: snapshot.rows('vault_items').isEmpty && filter != null
          ? null
          : await vault.exportKeyEnvelope(),
      isAuto: isAuto,
      hasSettings: configuration != null,
    );
    // Everything that grows with the data — the JSON, its checksum, the
    // sealing, the zip — runs on its own isolate (every argument is plain
    // data): an auto backup a few seconds after launch must not freeze the
    // first screens for as long as the database is big.
    final (bytes, manifest) = await Isolate.run(
      () => _assemble(head, snapshot, payloads, configuration, photo, key),
    );
    return BuiltBackup(
      bytes: bytes,
      manifest: manifest,
      contentHash: contentHashOf(manifest.checksum, configuration, photo),
    );
  }

  /// The isolate half of [build]: encodes the snapshot, describes it in the
  /// manifest (counts, checksum of the plaintext) and zips the archive.
  static Future<(Uint8List, BackupManifest)> _assemble(
    _ManifestHead head,
    DbSnapshot snapshot,
    Map<String, Uint8List> files,
    Uint8List? configuration,
    Uint8List? photo,
    BackupKey? key,
  ) async {
    final plain = snapshot.encode();
    final manifest = head.describe(snapshot, plain, files.keys);
    final bytes = await _pack(
      manifest,
      plain,
      configuration,
      photo,
      files,
      key,
    );
    return (bytes, manifest);
  }

  /// The settings as bytes for `settings.json`; null when there is nothing
  /// to carry. Never fails a backup: settings are a bonus, the data is the
  /// point.
  Future<Uint8List?> _exportSettings() async {
    try {
      final carried = await settings.export();
      if (carried == null) return null;
      return Uint8List.fromList(utf8.encode(jsonEncode(carried.toJson())));
    } on Object {
      return null;
    }
  }

  /// Seals (when [key] is set) and zips the archive. The only CPU-heavy part
  /// of [build]: AES-GCM runs in pure Dart and a backup with a few photos is
  /// tens of megabytes, so it runs on its own isolate (every argument is
  /// plain data) instead of freezing the UI.
  static Future<Uint8List> _pack(
    BackupManifest manifest,
    Uint8List plain,
    Uint8List? configuration,
    Uint8List? photo,
    Map<String, Uint8List> files,
    BackupKey? key,
  ) async {
    final sealed = <String, Uint8List>{
      for (final e in files.entries)
        e.key: key == null ? e.value : await BackupCipher.seal(e.value, key),
    };
    return BackupArchive(
      manifest: manifest,
      dbJson: key == null ? plain : await BackupCipher.seal(plain, key),
      settings: configuration == null || key == null
          ? configuration
          : await BackupCipher.seal(configuration, key),
      profilePhoto: photo == null || key == null
          ? photo
          : await BackupCipher.seal(photo, key),
      files: sealed,
    ).encode();
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

  /// The backup's settings, decrypted and parsed. `value` is null when the
  /// backup has none, or when they cannot be read — `failed` tells the two
  /// apart (damaged file, wrong layout, or written by a newer app).
  Future<({BackupSettings? value, bool failed})> _openSettings(
    BackupArchive archive,
    BackupKey? key,
  ) async {
    final sealed = archive.settings;
    if (sealed == null) return (value: null, failed: false);
    try {
      final bytes = archive.manifest.isEncrypted
          ? await BackupCipher.open(sealed, key!)
          : sealed;
      final parsed = BackupSettings.fromJson(jsonDecode(utf8.decode(bytes)));
      return (value: parsed, failed: parsed == null);
    } on Object {
      return (value: null, failed: true);
    }
  }

  /// Restores [archive] (see the file header). Throws [WrongBackupPin] /
  /// [FormatException] before anything changes, and [RestoreFailed] when
  /// writing failed (the database transaction rolled back; the vault key
  /// may already have been swapped — see [RestoreFailed.vaultKeyChanged]).
  ///
  /// [applySettings] false restores the data only (see the file header).
  Future<RestoreResult> restore(
    BackupArchive archive, {
    required RestoreMode mode,
    BackupKey? key,
    bool applySettings = true,
  }) async {
    final incoming = await openSnapshot(archive, key: key);
    // Opened up front like the snapshot, but a damaged settings entry only
    // skips the settings — it must never cost the user their data.
    final ({BackupSettings? value, bool failed}) backedUp = applySettings
        ? await _openSettings(archive, key)
        : (value: null, failed: false);
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
    var settingsRestored = false;
    var settingsFailed = backedUp.failed;
    if (backedUp.value case final configuration?) {
      try {
        await settings.apply(
          configuration,
          replace: mode == RestoreMode.replace,
        );
        settingsRestored = true;
      } on Object {
        // The data is back; only the settings are reported as not restored.
        settingsFailed = true;
      }
    }
    final photoRestored =
        applySettings &&
        await _restoreProfilePhoto(
          archive,
          key,
          replace: mode == RestoreMode.replace,
        );
    return RestoreResult(
      mode: mode,
      report: report,
      vaultRestored: vaultOk,
      filesRestored: restored,
      filesMissing: missing,
      settingsRestored: settingsRestored,
      settingsFailed: settingsFailed,
      photoRestored: photoRestored,
    );
  }

  /// Puts the backup's profile picture on this device: Replace always,
  /// Merge only when this device has none (a picture chosen here wins, like
  /// its settings). Never fails a restore — the data is back already.
  Future<bool> _restoreProfilePhoto(
    BackupArchive archive,
    BackupKey? key, {
    required bool replace,
  }) async {
    final sealed = archive.profilePhoto;
    if (sealed == null) return false;
    try {
      if (!replace && await files.exists(AppFiles.profilePhotoPath)) {
        return false;
      }
      final bytes = archive.manifest.isEncrypted
          ? await BackupCipher.open(sealed, key!)
          : sealed;
      return await files.write(AppFiles.profilePhotoPath, bytes) != null;
    } on Object {
      return false;
    }
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

/// The parts of a [BackupManifest] known before the snapshot is encoded
/// (plain data, so it can cross to the isolate that encodes it).
@immutable
class _ManifestHead {
  const _ManifestHead({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.encryption,
    required this.devices,
    required this.vaultKey,
    required this.isAuto,
    required this.hasSettings,
  });

  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final String deviceId;
  final String deviceName;
  final String platform;
  final BackupKdfParams? encryption;
  final List<LinkedDevice> devices;
  final Map<String, Object?>? vaultKey;
  final bool isAuto;
  final bool hasSettings;

  /// The manifest of [snapshot] encoded as [plain], carrying [files].
  BackupManifest describe(
    DbSnapshot snapshot,
    Uint8List plain,
    Iterable<String> files,
  ) => BackupManifest(
    schemaVersion: schemaVersion,
    appVersion: appVersion,
    createdAt: createdAt,
    deviceId: deviceId,
    deviceName: deviceName,
    platform: platform,
    counts: snapshot.counts,
    itemCount: snapshot.itemCount,
    checksum: BackupArchive.sha256Hex(plain),
    encryption: encryption,
    attachments: files.toList()..sort(),
    devices: devices,
    vaultKey: vaultKey,
    isAuto: isAuto,
    hasSettings: hasSettings,
  );
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
    settings: ref.watch(settingsBackupBridgeProvider),
    profile: () => ref.read(deviceProfileProvider.future),
    clock: ref.watch(clockProvider),
  ),
);
