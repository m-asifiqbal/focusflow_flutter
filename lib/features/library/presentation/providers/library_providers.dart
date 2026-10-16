/// ============================================================
/// LIBRARY PROVIDERS — live data of the Library tab (screen 05) and its
/// mixed collections (Pinned, Favourites, Tags & Folders, by-tag lists)
/// ============================================================
///
/// What: thin StreamProviders over the items kernel, tags and folders
/// repositories. Why: every number / row on these screens is live — an
/// edit anywhere (pin a note, finish a task, lock the vault) updates the
/// hub without a refresh. No formatting here (see library_format.dart).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Counts per module + archive / trash / pinned / favourites. Day-relative
/// numbers ("7 due today") follow [todayProvider]: the stream restarts when
/// the day changes (the Library screen keeps the minute clock ticking), so
/// they never go stale after midnight. Minute changes don't rebuild it.
final libraryCountsProvider = StreamProvider.autoDispose<LibraryCounts>((ref) {
  final items = ref.watch(itemsRepositoryProvider);
  ref.watch(todayProvider);
  final now = ref.read(clockProvider).now();
  return _perListener(() => items.watchLibraryCounts(now: now));
});

/// Exposes [source] as a broadcast stream with one source subscription per
/// listener (the shape of drift's own query streams).
///
/// Why: Riverpod wraps single-subscription streams (the combined counts
/// stream is one) in `asBroadcastStream`, whose cancel callback runs in the
/// zone the provider was built in. In widget tests that is the fake-async
/// zone, so drift's stream-cleanup timer never fires during teardown and
/// `AppDatabase.close()` waits forever — hanging every test that shows the
/// Library tab (it sits under every `/library/...` page). Cancelling
/// directly, as here, behaves the same in the app.
Stream<T> _perListener<T>(Stream<T> Function() source) => Stream<T>.multi((c) {
  final sub = source().listen(c.add, onError: c.addError, onDone: c.close);
  c
    ..onPause = sub.pause
    ..onResume = sub.resume
    ..onCancel = sub.cancel;
}, isBroadcast: true);

/// Every tag with its usage count, most used first (the Tags cloud).
final libraryTagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsRepositoryProvider).watchTags(),
);

/// One tag by id (null when it was deleted / merged away).
final libraryTagProvider = Provider.autoDispose
    .family<AsyncValue<Tag?>, String>(
      (ref, tagId) => ref
          .watch(libraryTagsProvider)
          .whenData((tags) => tags.where((t) => t.id == tagId).firstOrNull),
    );

/// The modules that have folders (notes) or lists (tasks, vault).
const List<ItemType> libraryFolderModules = [
  ItemType.note,
  ItemType.task,
  ItemType.vault,
];

/// Folders / lists of one module, in their manual order.
final libraryFoldersProvider = StreamProvider.autoDispose
    .family<List<Folder>, ItemType>(
      (ref, module) =>
          ref.watch(foldersRepositoryProvider).watchFolders(module),
    );

/// Which mixed list a [LibraryCollectionScreen] shows.
enum LibraryCollection { pinned, favourites, tag }

/// Arguments of [libraryCollectionItemsProvider]: [tagId] is required for
/// [LibraryCollection.tag].
typedef LibraryCollectionArgs = ({LibraryCollection kind, String? tagId});

/// Active items of every module in the collection (module order, newest
/// edit first inside a module).
final libraryCollectionItemsProvider = StreamProvider.autoDispose
    .family<List<ItemSummary>, LibraryCollectionArgs>((ref, args) {
      final items = ref.watch(itemsRepositoryProvider);
      return switch (args.kind) {
        LibraryCollection.pinned => items.watchPinned(),
        LibraryCollection.favourites => items.watchFavourites(),
        LibraryCollection.tag => items.watchByTag(args.tagId!),
      };
    });
