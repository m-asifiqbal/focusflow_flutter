/// ============================================================
/// TAGS & FOLDERS CONTROLLER — writes behind Settings › Tags & folders
/// ============================================================
///
/// What: rename / recolour / merge / delete tags and create / rename /
/// recolour / delete module folders. The destructive ones (merge, delete)
/// snapshot what they change first and return an undo callback for the
/// 5 s Undo snackbar.
/// Why: keeps repository calls and the undo bookkeeping out of widgets.
/// Undo restores each affected item's exact tag set (`setTags`), so a
/// merge undo also removes the target tag from items that didn't have it.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Restores what a destructive action changed.
typedef UndoAction = Future<void> Function();

class TagsFoldersController {
  const TagsFoldersController(this._ref);

  final Ref _ref;

  // ── Tags ──
  Future<void> renameTag(Tag tag, String name) =>
      _ref.read(tagsRepositoryProvider).rename(tag.id, name);

  Future<void> recolorTag(Tag tag, String? hex) =>
      _ref.read(tagsRepositoryProvider).recolor(tag.id, hex);

  /// Moves every item of [source] onto [target] and deletes [source].
  Future<UndoAction> mergeTag(Tag source, Tag target) async {
    final snapshot = await _tagSnapshot(source.id);
    await _ref.read(tagsRepositoryProvider).merge([source.id], target.id);
    return () => _restoreTags(source, snapshot);
  }

  /// Deletes [tag] from every item (items are kept).
  Future<UndoAction> deleteTag(Tag tag) async {
    final snapshot = await _tagSnapshot(tag.id);
    await _ref.read(tagsRepositoryProvider).delete(tag.id);
    return () => _restoreTags(tag, snapshot);
  }

  /// Tag names of every item (active, archived, recently deleted) that
  /// carries [tagId].
  Future<Map<ItemRef, List<String>>> _tagSnapshot(String tagId) async {
    final items = _ref.read(itemsRepositoryProvider);
    final tags = _ref.read(tagsRepositoryProvider);
    final out = <ItemRef, List<String>>{};
    Future<void> add(ItemRef r) async {
      if (out.containsKey(r)) return;
      final of = await tags.watchTagsOf(r).first;
      if (of.any((t) => t.id == tagId)) out[r] = [for (final t in of) t.name];
    }

    for (final s in await items.watchByTag(tagId).first) {
      await add(s.ref);
    }
    for (final s in [
      ...await items.watchArchived().first,
      ...await items.watchTrash().first,
    ]) {
      await add(s.ref);
    }
    return out;
  }

  Future<void> _restoreTags(Tag tag, Map<ItemRef, List<String>> snap) async {
    await _ref
        .read(tagsRepositoryProvider)
        .findOrCreate(tag.name, colorHex: tag.colorHex);
    final items = _ref.read(itemsRepositoryProvider);
    for (final e in snap.entries) {
      await items.setTags(e.key, e.value);
    }
  }

  // ── Folders ──
  Future<String> createFolder(ItemType module, String name) =>
      _ref.read(foldersRepositoryProvider).create(module, name);

  Future<void> renameFolder(Folder f, String name) =>
      _ref.read(foldersRepositoryProvider).rename(f.id, name);

  Future<void> recolorFolder(Folder f, String? hex) =>
      _ref.read(foldersRepositoryProvider).recolor(f.id, hex);

  /// Deletes [folder]; its items stay (moved out of it). Undo re-creates
  /// the folder and moves every item back — active, archived and recently
  /// deleted alike (membership is snapshotted across all lifecycle states).
  Future<UndoAction> deleteFolder(Folder folder) async {
    final items = _ref.read(itemsRepositoryProvider);
    final refs = {
      ...await _folderItems(folder),
      for (final s in [
        ...await items.watchArchived().first,
        ...await items.watchTrash().first,
      ])
        if (s.folderId == folder.id) s.ref,
    }.toList();
    final folders = _ref.read(foldersRepositoryProvider);
    await folders.delete(folder.id);
    return () async {
      final id = await folders.create(
        folder.module,
        folder.name,
        colorHex: folder.colorHex,
        iconKey: folder.iconKey,
      );
      if (refs.isNotEmpty) {
        await _ref.read(itemsRepositoryProvider).setFolder(refs, id);
      }
    };
  }

  Future<List<ItemRef>> _folderItems(Folder f) async => switch (f.module) {
    ItemType.note => [
      for (final n
          in await _ref
              .read(notesRepositoryProvider)
              .watchNotes(NotesQuery(folderId: f.id))
              .first)
        ItemRef(ItemType.note, n.id),
    ],
    ItemType.task => [
      for (final t
          in await _ref
              .read(tasksRepositoryProvider)
              .watchTasks(TasksQuery(listId: f.id))
              .first)
        ItemRef(ItemType.task, t.id),
    ],
    ItemType.vault => [
      for (final v
          in await _ref
              .read(vaultRepositoryProvider)
              .watchItems(VaultQuery(folderId: f.id))
              .first)
        ItemRef(ItemType.vault, v.id),
    ],
    _ => const [],
  };
}

final tagsFoldersControllerProvider = Provider<TagsFoldersController>(
  TagsFoldersController.new,
);
