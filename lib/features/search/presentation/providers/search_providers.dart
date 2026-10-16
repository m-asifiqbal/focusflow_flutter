/// ============================================================
/// SEARCH PROVIDERS — Global search (screen 06) state + live results
/// ============================================================
///
///   searchControllerProvider  — input text, debounced query (200 ms),
///                               module chip, filters, sort
///   searchResultsProvider     — live SearchResults for a SearchQuery
///   recentSearchesProvider    — history in the secure store (max 10),
///                               migrated once from plaintext settings
///   searchSuggestionsProvider — pinned items shown before typing
///   searchHabitStreakProvider — "12-day streak" meta for habit hits
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/search/data/datasource/recent_searches_store.dart';
import 'package:focusflow/features/search/data/repository/search_repository_impl.dart';
import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/search/domain/repository/search_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The search repository (read-only, so it needs only db + clock).
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Screen state of Global search.
@immutable
class SearchUiState {
  const SearchUiState({
    this.input = '',
    this.query = '',
    this.type,
    this.filters = SearchFilters.none,
    this.sort = SearchSort.relevance,
  });

  /// What is in the field right now.
  final String input;

  /// [input] after the 200 ms debounce — what is actually searched.
  final String query;

  /// Module chip (null = All).
  final ItemType? type;
  final SearchFilters filters;
  final SearchSort sort;

  bool get hasQuery => query.trim().isNotEmpty;

  SearchQuery get request =>
      SearchQuery(text: query.trim(), type: type, filters: filters, sort: sort);

  SearchUiState copyWith({
    String? input,
    String? query,
    ItemType? Function()? type,
    SearchFilters? filters,
    SearchSort? sort,
  }) => SearchUiState(
    input: input ?? this.input,
    query: query ?? this.query,
    type: type == null ? this.type : type(),
    filters: filters ?? this.filters,
    sort: sort ?? this.sort,
  );
}

/// Owns the debounce timer and every user choice on the screen.
class GlobalSearchController extends AutoDisposeNotifier<SearchUiState> {
  static const debounce = Duration(milliseconds: 200);
  Timer? _timer;

  @override
  SearchUiState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SearchUiState();
  }

  /// Field changed: update now, search after [debounce].
  void setInput(String text) {
    state = state.copyWith(input: text);
    _timer?.cancel();
    if (text.trim().isEmpty) {
      state = state.copyWith(query: '');
      return;
    }
    _timer = Timer(debounce, () => state = state.copyWith(query: text));
  }

  /// Search immediately (submit, recent-search pill, initial `?q=`).
  void searchNow(String text) {
    _timer?.cancel();
    state = state.copyWith(input: text, query: text);
  }

  void setType(ItemType? type) => state = state.copyWith(type: () => type);

  void setFilters(SearchFilters filters) =>
      state = state.copyWith(filters: filters);

  void toggleSort() => state = state.copyWith(
    sort: state.sort == SearchSort.relevance
        ? SearchSort.recent
        : SearchSort.relevance,
  );

  /// Stores the current query in the recent searches (on submit / open).
  Future<void> remember() async {
    final q = state.query.trim();
    if (q.isEmpty) return;
    await ref.read(recentSearchesProvider.notifier).add(q);
  }
}

final searchControllerProvider =
    AutoDisposeNotifierProvider<GlobalSearchController, SearchUiState>(
      GlobalSearchController.new,
    );

/// Live results for one request (re-runs when any module table changes).
final searchResultsProvider = StreamProvider.autoDispose
    .family<SearchResults, SearchQuery>(
      (ref, query) => ref.watch(searchRepositoryProvider).watch(query),
    );

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(ref.watch(secureStoreProvider)),
);

/// Recent searches, newest first (max 10), kept in the secure store.
///
/// One-time migration: older builds kept the terms in plaintext
/// `AppSettings.recentSearches`. On first load they are merged into the
/// secure store and — only once that write succeeded — cleared from
/// settings. If the secure store is unavailable the list still works for
/// the session (in memory) and the legacy copy is left for the next try.
class RecentSearchesController extends AsyncNotifier<List<String>> {
  RecentSearchesStore get _store => ref.read(recentSearchesStoreProvider);

  @override
  Future<List<String>> build() async {
    final stored = await _store.read();
    final legacy = ref.read(settingsProvider).recentSearches;
    if (legacy.isEmpty) return stored;
    final merged = RecentSearchesStore.merge(stored, legacy);
    if (await _store.write(merged)) await _clearLegacy();
    return merged;
  }

  /// Records [term] (moved to the front; blank terms are ignored).
  Future<void> add(String term) async {
    final current = await future;
    final next = RecentSearchesStore.push(current, term);
    if (_same(next, current)) return;
    state = AsyncData(next);
    await _store.write(next);
  }

  /// Forgets every term (secure store and any legacy plaintext copy).
  Future<void> clear() async {
    await future;
    state = const AsyncData([]);
    await _store.clear();
    await _clearLegacy();
  }

  Future<void> _clearLegacy() async {
    if (ref.read(settingsProvider).recentSearches.isEmpty) return;
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(recentSearches: const []));
  }

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );

/// Pinned items offered before anything is typed (prompt 06: "Initial
/// (recent + suggestions)"). Vault items are left out: opening one needs
/// an unlock, and its title shouldn't greet whoever holds the phone.
final searchSuggestionsProvider = StreamProvider.autoDispose<List<ItemSummary>>(
  (ref) => ref
      .watch(itemsRepositoryProvider)
      .watchPinned()
      .map(
        (items) => [
          for (final i in items)
            if (i.ref.type != ItemType.vault) i,
        ].take(maxSearchSuggestions).toList(),
      ),
);

/// Pinned suggestions shown at most.
const int maxSearchSuggestions = 5;

/// Current streak of a habit hit (meta line "12-day streak").
final searchHabitStreakProvider = StreamProvider.autoDispose
    .family<int, String>((ref, habitId) {
      final weekStart = ref.watch(
        settingsProvider.select((s) => s.weekStartsOn),
      );
      final clock = ref.watch(clockProvider);
      final calc = StreakCalculator(weekStartsOn: weekStart);
      return ref
          .watch(habitsRepositoryProvider)
          .watchHabitWithLogs(habitId)
          .map(
            (h) => h == null
                ? 0
                : calc.calculate(h.habit, h.logs, clock.now()).current,
          );
    });
