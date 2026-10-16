/// ============================================================
/// FOLDERS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Folders are soft-deleted (tombstone for sync) and their items move to
/// "no folder" (stamped so the change syncs).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/items_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/folders_repository.dart';
import 'package:focusflow/core/items/item_type.dart';

class FoldersRepositoryImpl extends RepositoryBase
    implements FoldersRepository {
  FoldersRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _org = OrganisationDao(db),
       _items = ItemsDao(db);

  final OrganisationDao _org;
  final ItemsDao _items;

  @override
  Stream<List<Folder>> watchFolders(ItemType module) => _org
      .watchFolders(module)
      .map(
        (rows) => List<Folder>.unmodifiable(
          rows.map((r) => ItemMappers.folder(r.$1, r.$2)),
        ),
      );

  @override
  Future<Folder?> getFolder(String id) async {
    final row = await _org.folderById(id);
    if (row == null || row.deletedAt != null) return null;
    final module = ItemType.fromKey(row.module);
    if (module == null) return ItemMappers.folder(row);
    final withCount = (await _org.getFolders(
      module,
    )).where((r) => r.$1.id == id).firstOrNull;
    return ItemMappers.folder(row, withCount?.$2 ?? 0);
  }

  @override
  Future<String> create(
    ItemType module,
    String name, {
    String? colorHex,
    String? iconKey,
  }) => db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Folder name is empty');
    }
    final existing = await _org.folderByName(module, trimmed);
    if (existing != null) return existing.id;
    final id = newId();
    final at = now();
    await _org.insertFolder(
      FoldersCompanion.insert(
        id: id,
        module: module.key,
        name: trimmed,
        colorHex: Value(colorHex),
        iconKey: Value(iconKey),
        sortOrder: Value(((await _org.maxFolderSortOrder(module)) ?? -1) + 1),
        createdAt: at,
        updatedAt: at,
      ),
    );
    return id;
  });

  @override
  Future<void> rename(String folderId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Folder name is empty');
    }
    return _org.updateFolder(
      folderId,
      FoldersCompanion(name: Value(trimmed), updatedAt: Value(now())),
    );
  }

  @override
  Future<void> recolor(String folderId, String? colorHex) => _org.updateFolder(
    folderId,
    FoldersCompanion(colorHex: Value(colorHex), updatedAt: Value(now())),
  );

  @override
  Future<void> setIcon(String folderId, String? iconKey) => _org.updateFolder(
    folderId,
    FoldersCompanion(iconKey: Value(iconKey), updatedAt: Value(now())),
  );

  @override
  Future<void> reorder(ItemType module, List<String> orderedIds) =>
      db.transaction(() async {
        final at = now();
        for (var i = 0; i < orderedIds.length; i++) {
          await _org.updateFolder(
            orderedIds[i],
            FoldersCompanion(
              sortOrder: Value(i.toDouble()),
              updatedAt: Value(at),
            ),
          );
        }
      });

  @override
  Future<void> delete(String folderId) => db.transaction(() async {
    final row = await _org.folderById(folderId);
    if (row == null) return;
    final s = stamp();
    await _org.updateFolder(
      folderId,
      FoldersCompanion(deletedAt: Value(s.now), updatedAt: Value(s.now)),
    );
    final module = ItemType.fromKey(row.module);
    if (module != null) await _items.clearFolder(module, folderId, s);
  });
}
