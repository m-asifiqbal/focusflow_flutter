// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_dao.dart';

// ignore_for_file: type=lint
mixin _$VaultDaoMixin on DatabaseAccessor<AppDatabase> {
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  $VaultHistoryTable get vaultHistory => attachedDatabase.vaultHistory;
  $GeneratorHistoryTable get generatorHistory =>
      attachedDatabase.generatorHistory;
  $FoldersTable get folders => attachedDatabase.folders;
  $ItemTagsTable get itemTags => attachedDatabase.itemTags;
  $TagsTable get tags => attachedDatabase.tags;
  VaultDaoManager get managers => VaultDaoManager(this);
}

class VaultDaoManager {
  final _$VaultDaoMixin _db;
  VaultDaoManager(this._db);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
  $$VaultHistoryTableTableManager get vaultHistory =>
      $$VaultHistoryTableTableManager(_db.attachedDatabase, _db.vaultHistory);
  $$GeneratorHistoryTableTableManager get generatorHistory =>
      $$GeneratorHistoryTableTableManager(
        _db.attachedDatabase,
        _db.generatorHistory,
      );
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db.attachedDatabase, _db.folders);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db.attachedDatabase, _db.itemTags);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
}
