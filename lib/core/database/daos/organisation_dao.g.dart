// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organisation_dao.dart';

// ignore_for_file: type=lint
mixin _$OrganisationDaoMixin on DatabaseAccessor<AppDatabase> {
  $FoldersTable get folders => attachedDatabase.folders;
  $TagsTable get tags => attachedDatabase.tags;
  $ItemTagsTable get itemTags => attachedDatabase.itemTags;
  $AttachmentsTable get attachments => attachedDatabase.attachments;
  $NotesTable get notes => attachedDatabase.notes;
  OrganisationDaoManager get managers => OrganisationDaoManager(this);
}

class OrganisationDaoManager {
  final _$OrganisationDaoMixin _db;
  OrganisationDaoManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db.attachedDatabase, _db.folders);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db.attachedDatabase, _db.itemTags);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db.attachedDatabase, _db.attachments);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
}
