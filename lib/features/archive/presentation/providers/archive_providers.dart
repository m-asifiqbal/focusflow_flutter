/// ============================================================
/// ARCHIVE PROVIDERS — live data of Archive (23) and Recently Deleted (24)
/// ============================================================
///
/// What: StreamProviders over the items kernel (`watchArchived`,
/// `watchTrash`), the Archive screen's filter (module chip + search) and
/// the archive-day streak of an archived habit ("34-day streak saved").
/// Why: both screens are live — archiving / deleting anywhere in the app
/// adds the row here at once, restoring removes it. Pure shaping lives in
/// `domain/archive_view.dart`; copy in `archive_format.dart`.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/archive/domain/archive_view.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Every archived (not deleted) item, newest archive first.
final archivedItemsProvider = StreamProvider.autoDispose<List<ItemSummary>>(
  (ref) => ref.watch(itemsRepositoryProvider).watchArchived(),
);

/// The Archive screen's module chip + search text.
class ArchiveFilterNotifier extends AutoDisposeNotifier<ArchiveFilter> {
  @override
  ArchiveFilter build() => const ArchiveFilter();

  /// Module chip (null = All).
  void setType(ItemType? type) => state = state.withType(type);

  void setQuery(String query) => state = state.withQuery(query);

  void setSort(ArchiveSort sort) => state = state.withSort(sort);
}

final archiveFilterProvider =
    NotifierProvider.autoDispose<ArchiveFilterNotifier, ArchiveFilter>(
      ArchiveFilterNotifier.new,
    );

/// Counts, matching rows and "This month" / "Earlier" groups for [filter].
final archiveProvider = Provider.autoDispose
    .family<AsyncValue<ArchiveView>, ArchiveFilter>((ref, filter) {
      final now = ref.watch(clockProvider).now();
      return ref
          .watch(archivedItemsProvider)
          .whenData((all) => ArchiveView.from(all, filter, now));
    });

/// Recently Deleted, newest deletion first.
final trashProvider = StreamProvider.autoDispose<List<ItemSummary>>(
  (ref) => ref.watch(itemsRepositoryProvider).watchTrash(),
);

/// The streak an archived habit had on the day it was archived (it is kept
/// for when the habit is restored). Null when the habit is gone.
final archivedHabitStreakProvider = StreamProvider.autoDispose
    .family<HabitStreak?, ({String id, DateTime archivedAt})>((ref, args) {
      final habits = ref.watch(habitsRepositoryProvider);
      final weekStart = ref.watch(
        settingsProvider.select((s) => s.weekStartsOn),
      );
      return _perListener(
        () => habits
            .watchHabitDetail(
              args.id,
              today: args.archivedAt,
              weekStartsOn: weekStart,
            )
            .map((d) => d?.stats.streak),
      );
    });

/// Exposes [source] as a broadcast stream with one source subscription per
/// listener. Why: Riverpod wraps single-subscription streams in
/// `asBroadcastStream`, whose cancel runs in the zone the provider was
/// built in; in widget tests that zone is fake-async, so drift's cleanup
/// timer never fires and closing the database hangs (see
/// library_providers.dart). Behaves the same in the app.
Stream<T> _perListener<T>(Stream<T> Function() source) => Stream<T>.multi((c) {
  final sub = source().listen(c.add, onError: c.addError, onDone: c.close);
  c
    ..onPause = sub.pause
    ..onResume = sub.resume
    ..onCancel = sub.cancel;
}, isBroadcast: true);
