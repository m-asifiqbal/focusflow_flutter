/// ============================================================
/// LOCAL DATA ERASER — "Erase local data" (screen 36)
/// ============================================================
///
/// Empties this device: every synced table (like a Replace restore with an
/// empty snapshot — no tombstones, so other devices keep their copies),
/// the device-local tables (inbox, generator history, backup records) and
/// the files under the app documents folder that belong to items or local
/// backups (attachments/, covers/, FocusFlow/, profile/).
///
/// Key material (vault PIN wrap, backup key) and settings are handled by
/// the caller (AccountActionsController) because they live with other
/// owners. The database file and its keychain key stay — the app keeps
/// running on an empty, still-encrypted database.
/// ============================================================
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class LocalDataEraser {
  LocalDataEraser({
    required this.db,
    required this.files,
    required this.deviceId,
  });

  final AppDatabase db;
  final AppFiles files;
  final String deviceId;

  /// Folders (relative to the documents root) that hold user data.
  static const List<String> dataFolders = [
    'attachments',
    'covers',
    'FocusFlow',
    'profile',
  ];

  /// Tables that are never part of a backup but still hold user data.
  static const List<String> deviceLocalTables = [
    'inbox_entries',
    'generator_history',
    'backup_records',
  ];

  /// Erases every item row and data file on this device.
  Future<void> eraseAll() async {
    await SnapshotIo(db, deviceId: deviceId).replaceAll(DbSnapshot(const {}));
    await db.transaction(() async {
      for (final t in deviceLocalTables) {
        await db.customStatement('DELETE FROM $t');
      }
    });
    db.notifyUpdates({
      for (final t in db.allTables)
        if (deviceLocalTables.contains(t.actualTableName))
          TableUpdate.onTable(t, kind: UpdateKind.delete),
    });
    final root = await files.root();
    for (final name in dataFolders) {
      final dir = Directory('${root.path}/$name');
      try {
        if (dir.existsSync()) await dir.delete(recursive: true);
      } on FileSystemException {
        // Best effort: a locked file must not stop the erase.
      }
    }
  }
}

final localDataEraserProvider = Provider<LocalDataEraser>(
  (ref) => LocalDataEraser(
    db: ref.watch(databaseProvider),
    files: ref.watch(appFilesProvider),
    deviceId: ref.watch(deviceIdProvider),
  ),
);
