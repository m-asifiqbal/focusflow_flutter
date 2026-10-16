/// ============================================================
/// TAGS REPOSITORY (contract)
/// ============================================================
///
/// Tags are global (shared by all modules). Item ↔ tag assignment lives in
/// ItemsRepository.setTags / addTags.
/// ============================================================
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';

abstract interface class TagsRepository {
  /// Every tag with its active-item usage count, most used first.
  Stream<List<Tag>> watchTags();

  /// Tags of one item, sorted by name.
  Stream<List<Tag>> watchTagsOf(ItemRef ref);

  /// Finds the tag named [name] (normalised, '#' optional) or creates it.
  /// Returns its id. Throws [ArgumentError] for a blank name.
  Future<String> findOrCreate(String name, {String? colorHex});

  /// Renames a tag. If another tag already has [newName], the two are
  /// merged into that one (items keep a single copy).
  Future<void> rename(String tagId, String newName);

  /// `RRGGBB` or null for the default colour.
  Future<void> recolor(String tagId, String? colorHex);

  /// Deletes the tag and removes it from every item (items are kept).
  Future<void> delete(String tagId);

  /// Moves every item of [sourceIds] onto [targetId] and deletes the
  /// sources.
  Future<void> merge(List<String> sourceIds, String targetId);
}
