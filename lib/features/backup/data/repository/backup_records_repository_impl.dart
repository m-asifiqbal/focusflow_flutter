/// ============================================================
/// BACKUP RECORDS REPOSITORY (Drift implementation)
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/backup_records_dao.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/domain/repository/backup_records_repository.dart';

class BackupRecordsRepositoryImpl extends RepositoryBase
    implements BackupRecordsRepository {
  BackupRecordsRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = BackupRecordsDao(db);

  final BackupRecordsDao _dao;

  static BackupRecord _map(BackupRecordRow r) => BackupRecord(
    id: r.id,
    location: BackupLocation.fromName(r.location),
    createdAt: r.createdAt,
    sizeBytes: r.sizeBytes,
    itemCount: r.itemCount,
    isAuto: r.isAuto,
    isEncrypted: r.isEncrypted,
    driveFileId: r.driveFileId,
    localPath: r.localPath,
  );

  @override
  Future<String> add(BackupRecord record) async {
    final id = record.id.isEmpty ? newId() : record.id;
    await _dao.insertRecord(
      BackupRecordsCompanion.insert(
        id: id,
        location: record.location.name,
        createdAt: RepositoryBase.truncateToSeconds(record.createdAt),
        sizeBytes: Value(record.sizeBytes),
        itemCount: Value(record.itemCount),
        isAuto: Value(record.isAuto),
        isEncrypted: Value(record.isEncrypted),
        driveFileId: Value(record.driveFileId),
        localPath: Value(record.localPath),
      ),
    );
    return id;
  }

  @override
  Stream<List<BackupRecord>> watchAll({BackupLocation? location}) => _dao
      .recordsQuery(location: location?.name)
      .watch()
      .map((rows) => List<BackupRecord>.unmodifiable(rows.map(_map)));

  @override
  Stream<BackupRecord?> watchLatest({BackupLocation? location}) =>
      (_dao.recordsQuery(location: location?.name)..limit(1)).watch().map(
        (rows) => rows.isEmpty ? null : _map(rows.first),
      );

  @override
  Future<BackupRecord?> get(String id) async {
    final row = await _dao.rowById(id);
    return row == null ? null : _map(row);
  }

  @override
  Future<void> delete(String id) => _dao.deleteRecords([id]);

  @override
  Future<List<BackupRecord>> pruneTo(
    int keep, {
    required BackupLocation location,
  }) => db.transaction(() async {
    final rows = await _dao.recordsQuery(location: location.name).get();
    if (rows.length <= keep) return const <BackupRecord>[];
    final removed = rows.skip(keep < 0 ? 0 : keep).toList();
    await _dao.deleteRecords(removed.map((r) => r.id));
    return List<BackupRecord>.unmodifiable(removed.map(_map));
  });
}
