// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_dao.dart';

// ignore_for_file: type=lint
mixin _$InboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $InboxEntriesTable get inboxEntries => attachedDatabase.inboxEntries;
  InboxDaoManager get managers => InboxDaoManager(this);
}

class InboxDaoManager {
  final _$InboxDaoMixin _db;
  InboxDaoManager(this._db);
  $$InboxEntriesTableTableManager get inboxEntries =>
      $$InboxEntriesTableTableManager(_db.attachedDatabase, _db.inboxEntries);
}
