/// ============================================================
/// DRIVE BACKUP FILE + DEVICES MANIFEST — what FocusFlow keeps in Drive
/// ============================================================
///
/// appDataFolder holds:
/// * `focusflow-<stamp>-<device>.ffbackup` — one per backup, with small
///   metadata in Drive `appProperties` ([DriveBackupFile]) so History and
///   the sign-in "Backup found" sheet never download a whole backup;
/// * `focusflow-devices.json` — the account's linked devices (screen 36)
///   and the shared backup KDF salt ([DriveManifest]), so every device
///   derives the same backup key from the same PIN and can merge the
///   others' encrypted backups.
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/drive_store.dart';

/// A backup in Drive, read from its appProperties.
@immutable
class DriveBackupFile {
  const DriveBackupFile({
    required this.fileId,
    required this.name,
    required this.createdAt,
    required this.deviceId,
    this.deviceName = '',
    this.platform = '',
    this.itemCount = 0,
    this.sizeBytes = 0,
    this.isAuto = false,
    this.isEncrypted = false,
    this.kdfSalt,
  });

  static const String kindKey = 'ffKind';
  static const String kindBackup = 'backup';
  static const String extension = '.ffbackup';

  final String fileId;
  final String name;
  final DateTime createdAt;
  final String deviceId;
  final String deviceName;
  final String platform;
  final int itemCount;
  final int sizeBytes;
  final bool isAuto;
  final bool isEncrypted;

  /// Base64 salt of the backup key (to tell whether our key opens it).
  final String? kdfSalt;

  /// appProperties written with a backup (values ≤ 100 bytes each).
  static Map<String, String> propertiesFor(BackupManifest m) => {
    kindKey: kindBackup,
    'deviceId': m.deviceId,
    'deviceName': _cap(m.deviceName),
    'platform': _cap(m.platform),
    'createdAt': m.createdAt.toUtc().toIso8601String(),
    'itemCount': '${m.itemCount}',
    'isAuto': '${m.isAuto}',
    'encrypted': '${m.isEncrypted}',
    if (m.encryption != null) 'kdfSalt': base64Encode(m.encryption!.salt),
  };

  /// Null for files that are not FocusFlow backups.
  static DriveBackupFile? fromFile(DriveFile f) {
    final p = f.properties;
    if (p[kindKey] != kindBackup && !f.name.endsWith(extension)) return null;
    return DriveBackupFile(
      fileId: f.id,
      name: f.name,
      createdAt:
          DateTime.tryParse(p['createdAt'] ?? '')?.toLocal() ?? f.createdAt,
      deviceId: p['deviceId'] ?? '',
      deviceName: p['deviceName'] ?? '',
      platform: p['platform'] ?? '',
      itemCount: int.tryParse(p['itemCount'] ?? '') ?? 0,
      sizeBytes: f.sizeBytes,
      isAuto: p['isAuto'] == 'true',
      isEncrypted: p['encrypted'] == 'true',
      kdfSalt: p['kdfSalt'],
    );
  }

  /// `focusflow-20260110-090000-1a2b3c4d.ffbackup`
  static String fileNameFor(DateTime createdAt, String deviceId) {
    final t = createdAt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    final dev = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
    return 'focusflow-$stamp-$dev$extension';
  }

  static String _cap(String s) => s.length > 60 ? s.substring(0, 60) : s;
}

/// `focusflow-devices.json`: linked devices + shared backup KDF params.
@immutable
class DriveManifest {
  const DriveManifest({
    this.devices = const [],
    this.encryption,
    this.updatedAt,
  });

  static const String fileName = 'focusflow-devices.json';
  static const String kindManifest = 'devices';

  final List<LinkedDevice> devices;

  /// KDF params (salt) every device uses for "Encrypt backups".
  final BackupKdfParams? encryption;
  final DateTime? updatedAt;

  static bool isManifest(DriveFile f) =>
      f.name == fileName ||
      f.properties[DriveBackupFile.kindKey] == kindManifest;

  DriveManifest copyWith({
    List<LinkedDevice>? devices,
    BackupKdfParams? encryption,
    DateTime? updatedAt,
  }) => DriveManifest(
    devices: devices ?? this.devices,
    encryption: encryption ?? this.encryption,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'formatVersion': 1,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
        'devices': [for (final d in devices) d.toJson()],
        'encryption': encryption?.toJson(),
      }),
    ),
  );

  /// Lenient: anything unreadable is an empty manifest.
  static DriveManifest decode(List<int> bytes) {
    try {
      final j = (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>();
      final enc = j['encryption'];
      return DriveManifest(
        devices: [
          for (final d in (j['devices'] as List? ?? const []))
            ?LinkedDevice.fromJson(d),
        ],
        encryption: enc is Map
            ? BackupKdfParams.fromJson(enc.cast<String, Object?>())
            : null,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      );
    } catch (_) {
      return const DriveManifest();
    }
  }
}
