/// ============================================================
/// ORGANISATION DAO — folders / lists, tags, item_tags, attachments
/// ============================================================
///
/// Row-level queries for everything that organises items across modules.
/// Business rules (normalising tag names, merging, bumping the owning
/// item's sync fields) live in the repositories (core/items/data).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';
import 'package:focusflow/core/items/item_type.dart';

part 'organisation_dao.g.dart';

@DriftAccessor(tables: [Folders, Tags, ItemTags, Attachments, Notes])
class OrganisationDao extends DatabaseAccessor<AppDatabase>
    with _$OrganisationDaoMixin {
  OrganisationDao(super.attachedDatabase);

  // ───────────────────────────── Folders ─────────────────────────────

  Selectable<(FolderRow, int)> _foldersQuery(ItemType module) {
    final table = attachedDatabase.itemTableName(module);
    return customSelect(
      'SELECT f.*, (SELECT COUNT(*) FROM $table x WHERE x.folder_id = f.id '
      'AND ${activeSql('x')}) AS item_count '
      'FROM folders f WHERE f.module = ? AND f.deleted_at IS NULL '
      'ORDER BY f.sort_order, f.name COLLATE NOCASE',
      variables: [Variable.withString(module.key)],
      readsFrom: {folders, attachedDatabase.itemTable(module)},
    ).map((r) => (folders.map(r.data), r.read<int>('item_count')));
  }

  /// Live folders of [module] with their active item counts.
  Stream<List<(FolderRow, int)>> watchFolders(ItemType module) =>
      _foldersQuery(module).watch();

  Future<List<(FolderRow, int)>> getFolders(ItemType module) =>
      _foldersQuery(module).get();

  Future<FolderRow?> folderById(String id) =>
      (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// Case-insensitive lookup of a live folder by name within [module].
  Future<FolderRow?> folderByName(ItemType module, String name) => customSelect(
    'SELECT * FROM folders WHERE module = ? AND deleted_at IS NULL '
    'AND name = ? COLLATE NOCASE LIMIT 1',
    variables: [Variable.withString(module.key), Variable.withString(name)],
    readsFrom: {folders},
  ).map((r) => folders.map(r.data)).getSingleOrNull();

  /// Folder names by id (live folders of any module).
  Future<Map<String, String>> folderNames() async {
    final rows = await (select(
      folders,
    )..where((f) => f.deletedAt.isNull())).get();
    return {for (final f in rows) f.id: f.name};
  }

  Future<double?> maxFolderSortOrder(ItemType module) {
    final max = folders.sortOrder.max();
    return (selectOnly(folders)
          ..addColumns([max])
          ..where(folders.module.equals(module.key)))
        .map((r) => r.read(max))
        .getSingle();
  }

  Future<void> insertFolder(FoldersCompanion folder) =>
      into(folders).insert(folder);

  Future<int> updateFolder(String id, FoldersCompanion changes) =>
      (update(folders)..where((f) => f.id.equals(id))).write(changes);

  // ─────────────────────────────── Tags ───────────────────────────────

  Selectable<(TagRow, int)> _tagsQuery() => customSelect(
    'WITH active_items(item_type, id) AS ($activeItemsSql) '
    'SELECT t.*, (SELECT COUNT(*) FROM item_tags it JOIN active_items a '
    'ON a.item_type = it.item_type AND a.id = it.item_id '
    'WHERE it.tag_id = t.id) AS usage_count '
    'FROM tags t ORDER BY usage_count DESC, t.name',
    readsFrom: {tags, itemTags, ...attachedDatabase.allItemTables},
  ).map((r) => (tags.map(r.data), r.read<int>('usage_count')));

  /// All tags with the number of active items carrying each (most used
  /// first).
  Stream<List<(TagRow, int)>> watchTagsWithUsage() => _tagsQuery().watch();

  Future<List<(TagRow, int)>> getTagsWithUsage() => _tagsQuery().get();

  Future<TagRow?> tagById(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// [name] must already be normalised (see Tag.normalize).
  Future<TagRow?> tagByName(String name) =>
      (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<List<TagRow>> tagsByNames(Iterable<String> names) {
    final list = names.toList();
    if (list.isEmpty) return Future.value(const []);
    return (select(tags)..where((t) => t.name.isIn(list))).get();
  }

  Future<void> insertTag(TagsCompanion tag) => into(tags).insert(tag);

  Future<int> updateTag(String id, TagsCompanion changes) =>
      (update(tags)..where((t) => t.id.equals(id))).write(changes);

  Future<int> deleteTag(String id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  Future<int> countTags() => tags.count().getSingle();

  // ───────────────────────────── Item tags ────────────────────────────

  /// Tags of every item of [type] (or only of [itemIds]), keyed by item id,
  /// each list sorted by name.
  Future<Map<String, List<TagRow>>> tagsByItem(
    ItemType type, {
    Iterable<String>? itemIds,
  }) async {
    final ids = itemIds?.toList();
    if (ids != null && ids.isEmpty) return const {};
    final rows = await customSelect(
      'SELECT it.item_id AS owner_id, t.* FROM item_tags it '
      'JOIN tags t ON t.id = it.tag_id WHERE it.item_type = ?'
      '${ids == null ? '' : ' AND it.item_id IN (${sqlPlaceholders(ids.length)})'}'
      ' ORDER BY t.name',
      variables: [
        Variable.withString(type.key),
        if (ids != null) ...ids.map(Variable.withString),
      ],
      readsFrom: {itemTags, tags},
    ).get();
    final result = <String, List<TagRow>>{};
    for (final r in rows) {
      result
          .putIfAbsent(r.read<String>('owner_id'), () => [])
          .add(tags.map(r.data));
    }
    return result;
  }

  Future<List<TagRow>> tagsOf(ItemType type, String itemId) async =>
      (await tagsByItem(type, itemIds: [itemId]))[itemId] ?? const [];

  Future<List<ItemTagRow>> itemTagsOfTag(String tagId) =>
      (select(itemTags)..where((t) => t.tagId.equals(tagId))).get();

  Future<List<ItemTagRow>> itemTagsOf(ItemType type, String itemId) => (select(
    itemTags,
  )..where((t) => t.itemType.equals(type.key) & t.itemId.equals(itemId))).get();

  Future<void> addItemTag(ItemType type, String itemId, String tagId) =>
      into(itemTags).insert(
        ItemTagsCompanion.insert(
          itemId: itemId,
          itemType: type.key,
          tagId: tagId,
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<int> removeItemTag(ItemType type, String itemId, String tagId) =>
      (delete(itemTags)..where(
            (t) =>
                t.itemType.equals(type.key) &
                t.itemId.equals(itemId) &
                t.tagId.equals(tagId),
          ))
          .go();

  Future<int> deleteItemTagsOf(ItemType type, Iterable<String> itemIds) =>
      (delete(
            itemTags,
          )..where((t) => t.itemType.equals(type.key) & t.itemId.isIn(itemIds)))
          .go();

  Future<int> deleteItemTagsOfTag(String tagId) =>
      (delete(itemTags)..where((t) => t.tagId.equals(tagId))).go();

  // ──────────────────────────── Attachments ───────────────────────────

  Future<List<AttachmentRow>> attachmentsOf(
    ItemType type,
    Iterable<String> itemIds,
  ) => (select(
    attachments,
  )..where((a) => a.itemType.equals(type.key) & a.itemId.isIn(itemIds))).get();

  Stream<List<AttachmentRow>> watchAttachmentsOf(ItemType type, String id) =>
      (select(attachments)
            ..where((a) => a.itemType.equals(type.key) & a.itemId.equals(id))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  Future<void> insertAttachment(AttachmentsCompanion row) =>
      into(attachments).insert(row);

  Future<int> deleteAttachmentsOf(ItemType type, Iterable<String> itemIds) =>
      (delete(
            attachments,
          )..where((a) => a.itemType.equals(type.key) & a.itemId.isIn(itemIds)))
          .go();

  /// Whether any attachment row or note cover still points at [path]
  /// (duplicates share files; a file is only deleted when unreferenced).
  Future<bool> isFileReferenced(String path) async {
    final row = await customSelect(
      'SELECT (SELECT COUNT(*) FROM attachments WHERE local_path = ?1) + '
      '(SELECT COUNT(*) FROM notes WHERE cover_image_path = ?1) AS refs',
      variables: [Variable.withString(path)],
      readsFrom: {attachments, notes},
    ).getSingle();
    return row.read<int>('refs') > 0;
  }
}
