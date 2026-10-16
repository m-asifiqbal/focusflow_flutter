/// ============================================================
/// TAGS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Tag membership has no sync columns of its own, so every change that
/// alters an item's tags (rename-merge, delete, merge) bumps the affected
/// items' `updatedAt` / `syncVersion`.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/items_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/items/tags_repository.dart';

class TagsRepositoryImpl extends RepositoryBase implements TagsRepository {
  TagsRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _org = OrganisationDao(db),
       _items = ItemsDao(db),
       _writer = TagWriter(OrganisationDao(db), newId);

  final OrganisationDao _org;
  final ItemsDao _items;
  final TagWriter _writer;

  @override
  Stream<List<Tag>> watchTags() => _org.watchTagsWithUsage().map(
    (rows) =>
        List<Tag>.unmodifiable(rows.map((r) => ItemMappers.tag(r.$1, r.$2))),
  );

  @override
  Stream<List<Tag>> watchTagsOf(ItemRef ref) => db.watchComputed({
    db.itemTags,
    db.tags,
  }, () async => ItemMappers.tags(await _org.tagsOf(ref.type, ref.id)));

  @override
  Future<String> findOrCreate(String name, {String? colorHex}) =>
      db.transaction(() async {
        final normalized = Tag.normalize(name);
        if (normalized.isEmpty) {
          throw ArgumentError.value(name, 'name', 'Tag name is empty');
        }
        final existed = await _org.tagByName(normalized);
        final id = (await _writer.ensureTags([normalized], stamp())).single;
        if (existed == null && colorHex != null) {
          await _org.updateTag(id, TagsCompanion(colorHex: Value(colorHex)));
        }
        return id;
      });

  /// Bumps the sync stamp of every item carrying one of [tagIds].
  Future<void> _touchItemsOf(Iterable<String> tagIds, WriteStamp s) async {
    final byType = <ItemType, Set<String>>{};
    for (final tagId in tagIds) {
      for (final link in await _org.itemTagsOfTag(tagId)) {
        final type = ItemType.fromKey(link.itemType);
        if (type != null) byType.putIfAbsent(type, () => {}).add(link.itemId);
      }
    }
    for (final e in byType.entries) {
      await _items.touch(e.key, e.value, s);
    }
  }

  @override
  Future<void> rename(String tagId, String newName) => db.transaction(() async {
    final normalized = Tag.normalize(newName);
    if (normalized.isEmpty) {
      throw ArgumentError.value(newName, 'newName', 'Tag name is empty');
    }
    final tag = await _org.tagById(tagId);
    if (tag == null || tag.name == normalized) return;
    final other = await _org.tagByName(normalized);
    if (other != null) {
      await _merge([tagId], other.id);
      return;
    }
    final s = stamp();
    await _org.updateTag(
      tagId,
      TagsCompanion(name: Value(normalized), updatedAt: Value(s.now)),
    );
    await _touchItemsOf([tagId], s);
  });

  @override
  Future<void> recolor(String tagId, String? colorHex) => _org.updateTag(
    tagId,
    TagsCompanion(colorHex: Value(colorHex), updatedAt: Value(now())),
  );

  @override
  Future<void> delete(String tagId) => db.transaction(() async {
    await _touchItemsOf([tagId], stamp());
    await _org.deleteItemTagsOfTag(tagId);
    await _org.deleteTag(tagId);
  });

  @override
  Future<void> merge(List<String> sourceIds, String targetId) =>
      db.transaction(() => _merge(sourceIds, targetId));

  Future<void> _merge(List<String> sourceIds, String targetId) async {
    final s = stamp();
    final sources = sourceIds.where((id) => id != targetId).toList();
    await _touchItemsOf(sources, s);
    for (final source in sources) {
      for (final link in await _org.itemTagsOfTag(source)) {
        final type = ItemType.fromKey(link.itemType);
        if (type != null) await _org.addItemTag(type, link.itemId, targetId);
      }
      await _org.deleteItemTagsOfTag(source);
      await _org.deleteTag(source);
    }
  }
}
