// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_records_dao.dart';

// ignore_for_file: type=lint
mixin _$BackupRecordsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BackupRecordsTable get backupRecords => attachedDatabase.backupRecords;
  BackupRecordsDaoManager get managers => BackupRecordsDaoManager(this);
}

class BackupRecordsDaoManager {
  final _$BackupRecordsDaoMixin _db;
  BackupRecordsDaoManager(this._db);
  $$BackupRecordsTableTableManager get backupRecords =>
      $$BackupRecordsTableTableManager(_db.attachedDatabase, _db.backupRecords);
}
