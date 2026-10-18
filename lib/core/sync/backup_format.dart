/// ============================================================
/// BACKUP FORMAT — the `.ffbackup` file (a zip)
/// ============================================================
///
/// ```
/// manifest.json      always plaintext: versions, device, counts, checksum,
///                    encryption params, linked devices, vault key envelope
/// db.json            DbSnapshot JSON (sealed with AES-GCM when encrypted)
/// settings.json      optional: the app's settings (BackupSettings JSON,
///                    sealed too); the manifest's `hasSettings` says so
/// attachments/<path> files referenced by attachment rows / note covers
///                    (paths relative to app documents; sealed too)
/// ```
/// `checksum` is SHA-256 of the *plaintext* db.json, so corruption and a
/// wrong key are both detected before anything touches the database.
/// settings.json is additive (same `formatVersion`): an app that predates it
/// ignores the entry and restores the data alone.
/// ============================================================
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';

/// The backup was written by a newer app (database schema) than this one.
/// A [FormatException] so every existing "can't read this backup" path
/// shows its message; Drive sync tells it apart to retry after an update.
class BackupTooNew extends FormatException {
  const BackupTooNew() : super('Update FocusFlow to read this backup');
}

/// A device that has synced with this Google account (screen 36).
@immutable
class LinkedDevice {
  const LinkedDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    this.lastSyncAt,
  });

  final String deviceId;

  /// "Pixel 8 Pro", "iPhone 15".
  final String name;

  /// "Android 15", "iOS 18".
  final String platform;
  final DateTime? lastSyncAt;

  bool get isIos => platform.toLowerCase().startsWith('ios');

  LinkedDevice copyWith({DateTime? lastSyncAt}) => LinkedDevice(
    deviceId: deviceId,
    name: name,
    platform: platform,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'name': name,
    'platform': platform,
    'lastSyncAt': lastSyncAt?.toUtc().toIso8601String(),
  };

  static LinkedDevice? fromJson(Object? j) {
    if (j is! Map || j['deviceId'] is! String) return null;
    return LinkedDevice(
      deviceId: j['deviceId'] as String,
      name: (j['name'] as String?) ?? 'Device',
      platform: (j['platform'] as String?) ?? '',
      lastSyncAt: DateTime.tryParse(
        (j['lastSyncAt'] as String?) ?? '',
      )?.toLocal(),
    );
  }

  /// Union of two device lists, newest `lastSyncAt` per device first.
  static List<LinkedDevice> union(
    Iterable<LinkedDevice> a,
    Iterable<LinkedDevice> b,
  ) {
    final map = <String, LinkedDevice>{};
    for (final d in [...a, ...b]) {
      final cur = map[d.deviceId];
      final newer =
          cur == null ||
          (d.lastSyncAt ?? DateTime(0)).isAfter(cur.lastSyncAt ?? DateTime(0));
      if (newer) map[d.deviceId] = d;
    }
    return map.values.toList()..sort(
      (x, y) =>
          (y.lastSyncAt ?? DateTime(0)).compareTo(x.lastSyncAt ?? DateTime(0)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LinkedDevice &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      other.lastSyncAt == lastSyncAt;

  @override
  int get hashCode => Object.hash(deviceId, name, platform, lastSyncAt);
}

@immutable
class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.counts,
    required this.itemCount,
    required this.checksum,
    this.encryption,
    this.attachments = const [],
    this.devices = const [],
    this.vaultKey,
    this.isAuto = false,
    this.hasSettings = false,
    this.formatVersion = currentFormat,
  });

  static const int currentFormat = 1;
  static const String fileName = 'manifest.json';
  static const String dbFileName = 'db.json';
  static const String settingsFileName = 'settings.json';
  static const String attachmentsDir = 'attachments/';

  final int formatVersion;

  /// AppDatabase.schemaVersion of the device that wrote it.
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final String deviceId;
  final String deviceName;
  final String platform;

  /// Rows per table.
  final Map<String, int> counts;

  /// Items (not in Recently Deleted) — "113 items".
  final int itemCount;

  /// SHA-256 (hex) of the plaintext db.json.
  final String checksum;

  /// Null = not encrypted.
  final BackupKdfParams? encryption;

  /// Relative paths stored under `attachments/`.
  final List<String> attachments;

  /// Every device known to have synced with this account.
  final List<LinkedDevice> devices;

  /// Opaque vault key envelope (wrapped by the PIN — never a plain key);
  /// see VaultBackupBridge. Null when the device had no vault.
  final Map<String, Object?>? vaultKey;
  final bool isAuto;

  /// The archive carries `settings.json` (the app's configuration).
  final bool hasSettings;

  bool get isEncrypted => encryption != null;

  /// Notes/tasks/… per `ItemType.key` from [counts].
  int countOf(String table) => counts[table] ?? 0;

  /// Schema gate: a backup from a newer database schema than
  /// [currentSchema] is refused ([BackupTooNew]) — its rows may mean
  /// something this version can't know. Older schemas restore as-is:
  /// columns they lack take this schema's defaults (see SnapshotIo).
  void checkReadableBy(int currentSchema) {
    if (schemaVersion > currentSchema) throw const BackupTooNew();
  }

  Map<String, Object?> toJson() => {
    'format': 'ffbackup',
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'counts': counts,
    'itemCount': itemCount,
    'checksum': checksum,
    'encryption': encryption?.toJson(),
    'attachments': attachments,
    'devices': [for (final d in devices) d.toJson()],
    'vaultKey': vaultKey,
    'isAuto': isAuto,
    'hasSettings': hasSettings,
  };

  static BackupManifest fromJson(Map<String, Object?> j) {
    if (j['format'] != 'ffbackup') {
      throw const FormatException('Not a FocusFlow backup');
    }
    final format = _int(j['formatVersion']) ?? 1;
    if (format > currentFormat) throw const BackupTooNew();
    final enc = j['encryption'];
    try {
      return _fromJson(j, format, enc);
    } on FormatException {
      rethrow;
    } on Object {
      // Wrong JSON types (a hand-edited or foreign file): never a crash.
      throw const FormatException('The backup manifest is damaged');
    }
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static BackupManifest _fromJson(
    Map<String, Object?> j,
    int format,
    Object? enc,
  ) {
    return BackupManifest(
      formatVersion: format,
      schemaVersion: _int(j['schemaVersion']) ?? 1,
      appVersion: (j['appVersion'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((j['createdAt'] as String?) ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deviceId: (j['deviceId'] as String?) ?? '',
      deviceName: (j['deviceName'] as String?) ?? 'Device',
      platform: (j['platform'] as String?) ?? '',
      counts: {
        if (j['counts'] is Map)
          for (final e in (j['counts'] as Map).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      },
      itemCount: _int(j['itemCount']) ?? 0,
      checksum: (j['checksum'] as String?) ?? '',
      encryption: enc is Map
          ? BackupKdfParams.fromJson(enc.cast<String, Object?>())
          : null,
      attachments: [
        if (j['attachments'] is List)
          for (final a in j['attachments'] as List) a.toString(),
      ],
      devices: [
        if (j['devices'] is List)
          for (final d in j['devices'] as List) ?LinkedDevice.fromJson(d),
      ],
      vaultKey: j['vaultKey'] is Map
          ? (j['vaultKey'] as Map).cast<String, Object?>()
          : null,
      isAuto: j['isAuto'] == true,
      hasSettings: j['hasSettings'] == true,
    );
  }
}

/// The unpacked zip: manifest + (possibly sealed) payloads.
@immutable
class BackupArchive {
  const BackupArchive({
    required this.manifest,
    required this.dbJson,
    this.settings,
    this.files = const {},
  });

  final BackupManifest manifest;

  /// db.json bytes — sealed when [BackupManifest.isEncrypted].
  final Uint8List dbJson;

  /// settings.json bytes (sealed when encrypted); null = the backup carries
  /// no settings.
  final Uint8List? settings;

  /// Relative path → bytes (sealed when encrypted).
  final Map<String, Uint8List> files;

  static String sha256Hex(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();

  /// Zips the archive.
  Uint8List encode() {
    final zip = Archive()
      ..addFile(
        ArchiveFile.string(
          BackupManifest.fileName,
          const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
        ),
      )
      ..addFile(ArchiveFile.bytes(BackupManifest.dbFileName, dbJson));
    if (settings case final bytes?) {
      zip.addFile(ArchiveFile.bytes(BackupManifest.settingsFileName, bytes));
    }
    for (final e in files.entries) {
      zip.addFile(
        ArchiveFile.bytes('${BackupManifest.attachmentsDir}${e.key}', e.value),
      );
    }
    return ZipEncoder().encodeBytes(zip);
  }

  /// Unzips [bytes]. Throws [FormatException] when it isn't a backup.
  static BackupArchive decode(List<int> bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a FocusFlow backup (not a zip file)');
    }
    final manifestFile = zip.findFile(BackupManifest.fileName);
    final dbFile = zip.findFile(BackupManifest.dbFileName);
    if (manifestFile == null || dbFile == null) {
      throw const FormatException('Not a FocusFlow backup');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(manifestFile.content));
    } catch (_) {
      throw const FormatException('The backup manifest is damaged');
    }
    if (json is! Map) {
      throw const FormatException('The backup manifest is damaged');
    }
    final manifest = BackupManifest.fromJson(json.cast<String, Object?>());
    try {
      final files = <String, Uint8List>{};
      for (final f in zip.files) {
        if (!f.isFile || !f.name.startsWith(BackupManifest.attachmentsDir)) {
          continue;
        }
        final rel = f.name.substring(BackupManifest.attachmentsDir.length);
        if (rel.isEmpty || rel.contains('..')) continue;
        files[rel] = f.content;
      }
      return BackupArchive(
        manifest: manifest,
        dbJson: dbFile.content,
        settings: zip.findFile(BackupManifest.settingsFileName)?.content,
        files: files,
      );
    } on Object {
      // A truncated / corrupt zip entry fails while inflating.
      throw const FormatException('The backup file is damaged');
    }
  }
}
