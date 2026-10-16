/// ============================================================
/// ITEMS REPOSITORY (contract) — lifecycle & collections for ANY item
/// ============================================================
///
/// The shared kernel used by Library, Archive, Recently Deleted, the item
/// actions sheet, multi-select bars and the daily purge job. Every method
/// takes [ItemRef]s, so callers never need to know the module.
///
/// Lifecycle (one rule for all modules):
///   Active ──archive──▶ Archive ──unarchive──▶ Active
///   Active/Archive ──moveToTrash──▶ Recently Deleted ──restoreFromTrash──▶
///   (back where it was) ──deleteForever / purgeExpired (30 days)──▶ gone
///
/// All writes stamp `updatedAt`, `syncVersion + 1`, `deviceId`.
/// ============================================================
library;

import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';

abstract interface class ItemsRepository {
  /// Moves items to the Archive (`archivedAt = now`, or [at] — the Undo of
  /// a restore puts the original archive date back).
  Future<void> archive(List<ItemRef> refs, {DateTime? at});

  /// Restores archived items to their lists (`archivedAt = null`).
  Future<void> unarchive(List<ItemRef> refs);

  /// Soft delete → Recently Deleted (`deletedAt = now`). Restorable for
  /// 30 days. Linked reminders of trashed tasks / notes stop firing. [at]
  /// (Undo of a restore) keeps the original deletion date, so undoing a
  /// recover never restarts the 30-day countdown.
  Future<void> moveToTrash(List<ItemRef> refs, {DateTime? at});

  /// Undo of [moveToTrash] (`deletedAt = null`; an item that was archived
  /// before returns to the Archive).
  Future<void> restoreFromTrash(List<ItemRef> refs);

  /// Permanent delete (no undo). Also removes the item's tag links,
  /// attachment rows + files (when no other row references them), task
  /// subtasks, habit logs, vault password history, the linked reminder of a
  /// task / note, and clears pointers to it (tasks' linked note, inbox).
  Future<void> deleteForever(List<ItemRef> refs);

  Future<void> setPinned(List<ItemRef> refs, bool pinned);
  Future<void> setFavorite(List<ItemRef> refs, bool favorite);

  /// `RRGGBB` or null for the module default.
  Future<void> setColor(List<ItemRef> refs, String? colorHex);

  /// Folder / task list (null = none). The folder must belong to the
  /// items' module.
  Future<void> setFolder(List<ItemRef> refs, String? folderId);

  /// Replaces the item's tags with [names] (with or without '#'); missing
  /// tags are created. Duplicates / blanks are ignored.
  Future<void> setTags(ItemRef ref, List<String> names);

  /// Adds [names] to every item in [refs] (multi-select "Tag").
  Future<void> addTags(List<ItemRef> refs, List<String> names);

  /// Copies the item (title + " (copy)", tags, subtasks, attachments rows;
  /// not pinned, no linked reminder, no habit history). Returns the new id.
  Future<String> duplicate(ItemRef ref);

  /// Summary of one item in any lifecycle state (null when gone).
  Future<ItemSummary?> get(ItemRef ref);
  Stream<ItemSummary?> watch(ItemRef ref);

  /// Archived (not deleted) items, newest archive first. [query] filters
  /// titles (case-insensitive substring).
  Stream<List<ItemSummary>> watchArchived({ItemType? type, String? query});

  /// Recently Deleted, newest deletion first.
  Stream<List<ItemSummary>> watchTrash();

  /// Active pinned items of every module (module order, then newest edit).
  Stream<List<ItemSummary>> watchPinned();

  /// Active favourite items of every module (module order, then newest).
  Stream<List<ItemSummary>> watchFavourites();

  /// Active items carrying [tagId] (module order, then newest edit).
  Stream<List<ItemSummary>> watchByTag(String tagId);

  /// Live numbers for the Library hub. Day-relative numbers use the day of
  /// [now] (default: the clock's now when the stream starts).
  Stream<LibraryCounts> watchLibraryCounts({DateTime? now});

  /// Permanently deletes trashed items whose `deletedAt` is at least
  /// [retention] old. Returns how many items were purged.
  Future<int> purgeExpired({Duration retention = const Duration(days: 30)});

  /// Hard-deletes abandoned blank notes: `/notes/new` inserts a row at once,
  /// so an app kill before the editor's discard leaves an "Untitled" note.
  /// Only notes that are active, untouched for [olderThan], never synced and
  /// carry nothing at all (no title, body, checklist, embeds, cover,
  /// attachments, tags, reminder, pin / favourite / lock, linked task) are
  /// removed. Returns how many were deleted.
  Future<int> purgeBlankNotes({Duration olderThan = const Duration(hours: 1)});
}
