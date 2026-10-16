/// ============================================================
/// LOCAL BACKUPS — Documents/FocusFlow, "Save to device", auto local backup
/// ============================================================
///
/// "Back up to device now" writes a `.ffbackup` into the app documents
/// folder `FocusFlow/` (visible in the Files app on iOS), records it in
/// the backup history and keeps the newest "Keep last N". "Save to device"
/// / "Download" hands any backup to the system save dialog (file_picker:
/// SAF on Android, document picker on iOS). The auto local backup runs
/// daily/weekly from the background job and on launch when overdue.
/// Encryption follows BackupKeyPolicy: "Encrypt backups" on without a
/// backup PIN throws BackupPinRequired (Backup & Sync shows a banner)
/// instead of writing plaintext; a keychain error fails the backup.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/domain/repository/backup_records_repository.dart';

/// Shows the system "save as" dialog; false when the user cancelled.
typedef FileSaver = Future<bool> Function(String fileName, Uint8List bytes);

Future<bool> _pickerSave(String fileName, Uint8List bytes) async =>
    await FilePicker.saveFile(fileName: fileName, bytes: bytes) != null;

class LocalBackups {
  LocalBackups({
    required this.engine,
    required this.files,
    required this.keys,
    required this.records,
    required this.keepBackups,
    required this.encryptBackups,
    this.clock = const Clock(),
    FileSaver? saver,
  }) : _saver = saver ?? _pickerSave;

  final BackupEngine engine;
  final AppFiles files;
  /// Same key rule as Drive sync: never silently plaintext when
  /// "Encrypt backups" is on (throws BackupPinRequired / BackupKeyUnavailable).
  final BackupKeyPolicy keys;
  final BackupRecordsRepository records;
  final int Function() keepBackups;
  final bool Function() encryptBackups;
  final Clock clock;
  final FileSaver _saver;

  /// Folder under app documents ("Documents/FocusFlow").
  static const String folder = 'FocusFlow';

  /// Builds a backup into [folder] and records it. Old local backups past
  /// "Keep last N" are deleted (file + record). Throws BackupPinRequired /
  /// BackupKeyUnavailable before anything is written.
  Future<BackupRecord> backupNow({bool isAuto = false}) async {
    final key = await keys.forBackup(encrypt: encryptBackups());
    final built = await engine.build(key: key, isAuto: isAuto);
    final m = built.manifest;
    final name = DriveBackupFile.fileNameFor(m.createdAt, engine.deviceId);
    final path = '$folder/$name';
    if (await files.write(path, built.bytes) == null) {
      throw const FileSystemFailure('Could not write the backup file');
    }
    final record = BackupRecord(
      id: '',
      location: BackupLocation.local,
      createdAt: m.createdAt,
      sizeBytes: built.bytes.length,
      itemCount: m.itemCount,
      isAuto: isAuto,
      isEncrypted: m.isEncrypted,
      localPath: path,
    );
    final id = await records.add(record);
    final removed = await records.pruneTo(
      keepBackups().clamp(1, 100),
      location: BackupLocation.local,
    );
    for (final r in removed) {
      if (r.localPath case final String p) await files.delete(p);
    }
    return (await records.get(id)) ?? record;
  }

  /// Whether an auto local backup is due for [frequency] (none yet, or the
  /// newest local backup is older than a day / a week).
  Future<bool> isAutoDue(LocalBackupFrequency frequency) async {
    if (frequency == LocalBackupFrequency.off) return false;
    final latest = await records
        .watchLatest(location: BackupLocation.local)
        .first;
    if (latest == null) return true;
    final every = frequency == LocalBackupFrequency.daily
        ? const Duration(hours: 20)
        : const Duration(days: 6, hours: 20);
    return clock.now().difference(latest.createdAt) >= every;
  }

  /// Runs the auto local backup when due; returns it (null = not due).
  Future<BackupRecord?> runAutoIfDue(LocalBackupFrequency frequency) async {
    if (!await isAutoDue(frequency)) return null;
    return backupNow(isAuto: true);
  }

  /// The bytes of a local backup (null when the file is gone).
  Future<Uint8List?> read(BackupRecord r) async {
    final p = r.localPath;
    return p == null ? null : files.read(p);
  }

  /// Deletes a local backup's file and record.
  Future<void> delete(BackupRecord r) async {
    if (r.localPath case final String p) await files.delete(p);
    await records.delete(r.id);
  }

  /// "Save to device" for a local backup; false = cancelled / missing.
  Future<bool> saveToDevice(BackupRecord r) async {
    final bytes = await read(r);
    if (bytes == null) return false;
    return saveBytes(_fileName(r), bytes);
  }

  /// Hands [bytes] to the system save dialog (also used for Drive
  /// "Download" and Import & Export).
  Future<bool> saveBytes(String fileName, Uint8List bytes) =>
      _saver(fileName, bytes);

  static String _fileName(BackupRecord r) {
    final p = r.localPath ?? '';
    final slash = p.lastIndexOf('/');
    return slash < 0 ? p : p.substring(slash + 1);
  }
}

/// The backup could not be written to app storage.
class FileSystemFailure implements Exception {
  const FileSystemFailure(this.message);

  final String message;

  @override
  String toString() => 'FileSystemFailure: $message';
}
