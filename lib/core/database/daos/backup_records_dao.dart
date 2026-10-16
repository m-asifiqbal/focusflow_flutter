/// ============================================================
/// BACKUP RECORDS DAO — local history of backups (Drive + local files)
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/tables.dart';

part 'backup_records_dao.g.dart';

@DriftAccessor(tables: [BackupRecords])
class BackupRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$BackupRecordsDaoMixin {
  BackupRecordsDao(super.attachedDatabase);

  /// Newest first, optionally only one [location] (`drive` / `local`).
  SimpleSelectStatement<$BackupRecordsTable, BackupRecordRow> recordsQuery({
    String? location,
  }) {
    final q = select(backupRecords)
      ..orderBy([
        (b) => OrderingTerm.desc(b.createdAt),
        (b) => OrderingTerm.desc(b.rowId),
      ]);
    if (location != null) q.where((b) => b.location.equals(location));
    return q;
  }

  Future<BackupRecordRow?> rowById(String id) =>
      (select(backupRecords)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<void> insertRecord(BackupRecordsCompanion row) =>
      into(backupRecords).insertOnConflictUpdate(row);

  Future<int> deleteRecords(Iterable<String> ids) =>
      (delete(backupRecords)..where((b) => b.id.isIn(ids))).go();
}
