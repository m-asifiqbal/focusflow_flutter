/// ============================================================
/// ITEM MAPPERS — Drift rows ⇄ shared kernel entities
/// ============================================================
///
/// Also hosts [TagWriter], the single place that turns tag *names* typed by
/// the user into tag rows + item_tags links (used by ItemsRepository and by
/// every module repository's save()).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/utils/date_utils.dart';

abstract final class ItemMappers {
  static Tag tag(TagRow r, [int usage = 0]) =>
      Tag(id: r.id, name: r.name, colorHex: r.colorHex, usageCount: usage);

  static List<Tag> tags(Iterable<TagRow>? rows) =>
      rows == null ? const [] : List.unmodifiable(rows.map(tag));

  static Folder folder(FolderRow r, [int count = 0]) => Folder(
    id: r.id,
    module: ItemType.fromKey(r.module) ?? ItemType.note,
    name: r.name,
    colorHex: r.colorHex,
    iconKey: r.iconKey,
    sortOrder: r.sortOrder,
    itemCount: count,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  /// Maps a row of ItemsDao.summaries.
  static ItemSummary summary(QueryRow r) {
    final type = ItemType.fromKey(r.read<String>('item_type'))!;
    DateTime? scheduled = r.readNullable<DateTime>('scheduled_at');
    // Task due dates are floating days (DateUtilsX.toStoredDay); reminder
    // triggers are real instants.
    if (scheduled != null && type == ItemType.task) {
      scheduled = DateUtilsX.fromStoredDay(scheduled);
    }
    final minutes = r.readNullable<int>('scheduled_minutes');
    if (scheduled != null && minutes != null) {
      scheduled = DateUtilsX.atMinutes(scheduled, minutes);
    }
    return ItemSummary(
      ref: ItemRef(type, r.read<String>('id')),
      title: r.read<String>('title'),
      meta: (r.readNullable<String>('meta') ?? '').trim(),
      colorHex: r.readNullable<String>('color_hex'),
      isPinned: r.read<bool>('is_pinned'),
      isFavorite: r.read<bool>('is_favorite'),
      folderId: r.readNullable<String>('folder_id'),
      folderName: r.readNullable<String>('folder_name'),
      isLocked: r.read<bool>('is_locked'),
      isCompleted: r.read<bool>('is_completed'),
      scheduledAt: scheduled,
      createdAt: r.read<DateTime>('created_at'),
      updatedAt: r.read<DateTime>('updated_at'),
      archivedAt: r.readNullable<DateTime>('archived_at'),
      deletedAt: r.readNullable<DateTime>('deleted_at'),
    );
  }
}

/// Creates missing tags and rewrites item ↔ tag links.
class TagWriter {
  TagWriter(this._org, this._newId);

  final OrganisationDao _org;
  final IdGenerator _newId;

  /// Normalised, de-duplicated, non-empty names (input order kept).
  static List<String> normalizeAll(Iterable<String> names) {
    final seen = <String>{};
    return [
      for (final n in names.map(Tag.normalize))
        if (n.isNotEmpty && seen.add(n)) n,
    ];
  }

  /// Ids of the tags called [names], creating the missing ones.
  Future<List<String>> ensureTags(
    Iterable<String> names,
    WriteStamp stamp,
  ) async {
    final wanted = normalizeAll(names);
    if (wanted.isEmpty) return const [];
    final existing = {
      for (final t in await _org.tagsByNames(wanted)) t.name: t.id,
    };
    final ids = <String>[];
    for (final name in wanted) {
      var id = existing[name];
      if (id == null) {
        id = _newId();
        await _org.insertTag(
          TagsCompanion.insert(
            id: id,
            name: name,
            createdAt: stamp.now,
            updatedAt: stamp.now,
          ),
        );
      }
      ids.add(id);
    }
    return ids;
  }

  /// Replaces the tags of one item. Returns true when links changed.
  /// Call inside a transaction; the caller bumps the item's sync fields.
  Future<bool> replaceTags(
    ItemType type,
    String itemId,
    Iterable<String> names,
    WriteStamp stamp,
  ) async {
    final ids = (await ensureTags(names, stamp)).toSet();
    final current = {
      for (final r in await _org.itemTagsOf(type, itemId)) r.tagId,
    };
    var changed = false;
    for (final old in current.difference(ids)) {
      await _org.removeItemTag(type, itemId, old);
      changed = true;
    }
    for (final add in ids.difference(current)) {
      await _org.addItemTag(type, itemId, add);
      changed = true;
    }
    return changed;
  }

  /// Adds [names] to an item without removing its other tags.
  Future<bool> addTags(
    ItemType type,
    String itemId,
    Iterable<String> names,
    WriteStamp stamp,
  ) async {
    final ids = await ensureTags(names, stamp);
    final current = {
      for (final r in await _org.itemTagsOf(type, itemId)) r.tagId,
    };
    var changed = false;
    for (final id in ids) {
      if (current.add(id)) {
        await _org.addItemTag(type, itemId, id);
        changed = true;
      }
    }
    return changed;
  }
}
