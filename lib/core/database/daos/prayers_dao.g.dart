// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayers_dao.dart';

// ignore_for_file: type=lint
mixin _$PrayersDaoMixin on DatabaseAccessor<AppDatabase> {
  $PrayersTable get prayers => attachedDatabase.prayers;
  $PrayerLogsTable get prayerLogs => attachedDatabase.prayerLogs;
  $ItemTagsTable get itemTags => attachedDatabase.itemTags;
  $TagsTable get tags => attachedDatabase.tags;
  PrayersDaoManager get managers => PrayersDaoManager(this);
}

class PrayersDaoManager {
  final _$PrayersDaoMixin _db;
  PrayersDaoManager(this._db);
  $$PrayersTableTableManager get prayers =>
      $$PrayersTableTableManager(_db.attachedDatabase, _db.prayers);
  $$PrayerLogsTableTableManager get prayerLogs =>
      $$PrayerLogsTableTableManager(_db.attachedDatabase, _db.prayerLogs);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db.attachedDatabase, _db.itemTags);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
}
