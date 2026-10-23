// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_dao.dart';

// ignore_for_file: type=lint
mixin _$SearchDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotesTable get notes => attachedDatabase.notes;
  $TasksTable get tasks => attachedDatabase.tasks;
  $RemindersTable get reminders => attachedDatabase.reminders;
  $HabitsTable get habits => attachedDatabase.habits;
  $MedicinesTable get medicines => attachedDatabase.medicines;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  $FoldersTable get folders => attachedDatabase.folders;
  $ItemTagsTable get itemTags => attachedDatabase.itemTags;
  $TagsTable get tags => attachedDatabase.tags;
  SearchDaoManager get managers => SearchDaoManager(this);
}

class SearchDaoManager {
  final _$SearchDaoMixin _db;
  SearchDaoManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db.attachedDatabase, _db.reminders);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db.attachedDatabase, _db.habits);
  $$MedicinesTableTableManager get medicines =>
      $$MedicinesTableTableManager(_db.attachedDatabase, _db.medicines);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db.attachedDatabase, _db.folders);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db.attachedDatabase, _db.itemTags);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
}
