/// ============================================================
/// BACKUP RECORDS REPOSITORY (contract) — local backup history
/// ============================================================
library;

import 'package:focusflow/features/backup/domain/entities/backup_record.dart';

abstract interface class BackupRecordsRepository {
  /// Stores (or updates, same id) a record. Empty id → new id. Returns it.
  Future<String> add(BackupRecord record);

  /// Newest first (optionally one [location]).
  Stream<List<BackupRecord>> watchAll({BackupLocation? location});

  /// Most recent backup (optionally one [location]); null when none.
  Stream<BackupRecord?> watchLatest({BackupLocation? location});

  Future<BackupRecord?> get(String id);
  Future<void> delete(String id);

  /// Keeps the newest [keep] records of [location]; returns the removed
  /// ones (so the caller can delete their files / Drive copies).
  Future<List<BackupRecord>> pruneTo(
    int keep, {
    required BackupLocation location,
  });
}
