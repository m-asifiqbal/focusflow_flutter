/// ============================================================
/// STORAGE USAGE — how much space FocusFlow uses on this device
/// ============================================================
///
/// Shown on Settings (30, "Storage 48 MB") and Settings › Storage. Only the
/// [cacheBytes] bucket can be cleared from the app; everything else is user
/// data and is only ever removed by the user (Recently deleted, backups).
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class StorageUsage {
  const StorageUsage({
    this.databaseBytes = 0,
    this.attachmentsBytes = 0,
    this.backupsBytes = 0,
    this.cacheBytes = 0,
  });

  /// The encrypted SQLite file (+ its WAL / SHM side files).
  final int databaseBytes;

  /// Note images, covers and other attachments.
  final int attachmentsBytes;

  /// Local `.ffbackup` files kept on the device.
  final int backupsBytes;

  /// Temporary files (exports being shared, picked images…). Safe to clear.
  final int cacheBytes;

  int get totalBytes =>
      databaseBytes + attachmentsBytes + backupsBytes + cacheBytes;

  @override
  bool operator ==(Object other) =>
      other is StorageUsage &&
      other.databaseBytes == databaseBytes &&
      other.attachmentsBytes == attachmentsBytes &&
      other.backupsBytes == backupsBytes &&
      other.cacheBytes == cacheBytes;

  @override
  int get hashCode =>
      Object.hash(databaseBytes, attachmentsBytes, backupsBytes, cacheBytes);
}

/// "48 MB", "1.2 GB", "820 KB", "0 KB" (decimal units, like iOS / Android
/// storage screens).
String formatBytes(int bytes) {
  if (bytes < 1000) return bytes <= 0 ? '0 KB' : '1 KB';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final text = value >= 10 || unit == 0
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
