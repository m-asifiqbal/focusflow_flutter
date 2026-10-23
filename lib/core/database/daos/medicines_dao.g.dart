// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicines_dao.dart';

// ignore_for_file: type=lint
mixin _$MedicinesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MedicinesTable get medicines => attachedDatabase.medicines;
  $MedicineDosesTable get medicineDoses => attachedDatabase.medicineDoses;
  $ItemTagsTable get itemTags => attachedDatabase.itemTags;
  $TagsTable get tags => attachedDatabase.tags;
  MedicinesDaoManager get managers => MedicinesDaoManager(this);
}

class MedicinesDaoManager {
  final _$MedicinesDaoMixin _db;
  MedicinesDaoManager(this._db);
  $$MedicinesTableTableManager get medicines =>
      $$MedicinesTableTableManager(_db.attachedDatabase, _db.medicines);
  $$MedicineDosesTableTableManager get medicineDoses =>
      $$MedicineDosesTableTableManager(_db.attachedDatabase, _db.medicineDoses);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db.attachedDatabase, _db.itemTags);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
}
