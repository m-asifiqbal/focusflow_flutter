/// ============================================================
/// FOLDERS REPOSITORY (contract) — note folders, task lists, vault folders
/// ============================================================
///
/// Folders are scoped per module. Moving items between folders lives in
/// ItemsRepository.setFolder.
/// ============================================================
library;

import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';

abstract interface class FoldersRepository {
  /// Live folders / lists of [module] in manual order, with item counts.
  Stream<List<Folder>> watchFolders(ItemType module);

  Future<Folder?> getFolder(String id);

  /// Creates a folder at the end of the order — or returns the id of an
  /// existing folder of [module] with the same name (case-insensitive).
  Future<String> create(
    ItemType module,
    String name, {
    String? colorHex,
    String? iconKey,
  });

  Future<void> rename(String folderId, String name);
  Future<void> recolor(String folderId, String? colorHex);
  Future<void> setIcon(String folderId, String? iconKey);

  /// Persists the manual order of [module]'s folders ([orderedIds] = the
  /// new order, first = leftmost chip).
  Future<void> reorder(ItemType module, List<String> orderedIds);

  /// Deletes the folder; its items stay and get `folderId = null`.
  Future<void> delete(String folderId);
}
