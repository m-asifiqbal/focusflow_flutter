/// ============================================================
/// SEARCH REPOSITORY (Drift) — FTS5 search + ranking blend
/// ============================================================
///
/// Builds safe FTS5 prefix expressions with [FtsQuery], asks [SearchDao]
/// for one ranked row set per module and blends the raw ranking inputs:
///
///   relevance = bm25 normalised within its module (best hit = 1.0)
///             + 0.5 when every term starts a word of the title
///             + 0.3 × recency (half-life ≈ 10 days since last edit)
///             + 0.2 when pinned
///
/// bm25 magnitudes differ per FTS table (column weights, document stats),
/// so they're normalised per module before modules are merged. Privacy:
/// locked notes match on their title only; vault items are indexed by
/// title only and carry no snippet.
///
/// Live results: a query re-runs only after writes to the tables it reads
/// (a priority filter reads tasks only), and bursts of writes (sync, bulk
/// edits, typing in an editor) are debounced by [refreshDelay] so one burst
/// costs one search; results equal to the last emission are skipped.
/// ============================================================
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/fts_query.dart';
import 'package:focusflow/core/database/daos/search_dao.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/search/domain/repository/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({required this.db, required this.clock})
    : _dao = SearchDao(db);

  final AppDatabase db;
  final Clock clock;
  final SearchDao _dao;

  static const double titleBoost = 0.5;
  static const double recencyBoost = 0.3;
  static const double pinnedBoost = 0.2;

  /// Quiet time after the last write before a live query re-runs.
  static const Duration refreshDelay = Duration(milliseconds: 150);

  @override
  Stream<SearchResults> watch(SearchQuery query) {
    if (FtsQuery.terms(query.text).isEmpty) {
      return Stream.value(SearchResults.empty);
    }
    final tables = {
      // Priority exists on tasks only, so such a query reads tasks only.
      if (query.filters.minPriority != null) db.tasks else ...db.allItemTables,
      db.folders,
      db.itemTags,
      db.tags,
    };
    return _debouncedWatch(
      db.tableUpdates(TableUpdateQuery.onAllTables(tables)),
      () => search(query),
    );
  }

  /// Runs [compute] on listen, then once per burst of [triggers] (after
  /// [refreshDelay] of quiet). A trigger during a run queues one more run;
  /// values equal to the previous emission are dropped.
  static Stream<T> _debouncedWatch<T>(
    Stream<Object?> triggers,
    Future<T> Function() compute,
  ) {
    const eq = DeepCollectionEquality();
    StreamSubscription<Object?>? sub;
    Timer? timer;
    var cancelled = false;
    var running = false;
    var dirty = false;
    var hasLast = false;
    T? last;
    late final StreamController<T> controller;

    Future<void> run() async {
      if (running) {
        dirty = true;
        return;
      }
      running = true;
      try {
        do {
          dirty = false;
          try {
            final value = await compute();
            if (cancelled) return;
            if (hasLast && eq.equals(last, value)) continue;
            last = value;
            hasLast = true;
            controller.add(value);
          } catch (e, s) {
            if (!cancelled) controller.addError(e, s);
          }
        } while (dirty && !cancelled);
      } finally {
        running = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = triggers.listen((_) {
          timer?.cancel();
          timer = Timer(refreshDelay, run);
        });
        run();
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        cancelled = true;
        timer?.cancel();
        return sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<SearchResults> search(SearchQuery query) async {
    final terms = FtsQuery.terms(query.text);
    final match = FtsQuery.prefixMatch(terms);
    if (match == null) return SearchResults.empty;
    final titleMatch = FtsQuery.prefixMatch(terms, column: 'title');
    final f = query.filters;
    // Priority exists on tasks only: a priority filter means "tasks only".
    final modules = [
      for (final t in ItemType.values)
        if (f.minPriority == null || t == ItemType.task) t,
    ];

    final counts = <ItemType, int>{for (final t in ItemType.values) t: 0};
    final hits = <SearchHit>[];
    final now = clock.now();
    for (final type in modules) {
      final args = _Args(type, match, titleMatch, f);
      counts[type] = await _dao.count(
        type,
        match: args.match,
        titleOnlyMatch: args.titleOnly,
        includeArchived: f.includeArchived,
        tagIds: args.tagIds,
        from: f.from,
        to: f.to,
        minPriority: f.minPriority,
      );
      if (query.type != null && query.type != type) continue;
      if (counts[type] == 0) continue;
      final rows = await _dao.search(
        type,
        match: args.match,
        titleOnlyMatch: args.titleOnly,
        includeArchived: f.includeArchived,
        tagIds: args.tagIds,
        from: f.from,
        to: f.to,
        minPriority: f.minPriority,
        limit: query.limitPerModule,
      );
      hits.addAll(_toHits(type, rows, terms, now));
    }

    final order = switch (query.sort) {
      SearchSort.relevance => (SearchHit a, SearchHit b) {
        final c = b.relevance.compareTo(a.relevance);
        return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
      },
      SearchSort.recent => (SearchHit a, SearchHit b) {
        final c = b.updatedAt.compareTo(a.updatedAt);
        return c != 0 ? c : b.relevance.compareTo(a.relevance);
      },
    };
    hits.sort(order);
    return SearchResults(hits: hits, counts: counts);
  }

  List<SearchHit> _toHits(
    ItemType type,
    List<QueryRow> rows,
    List<String> terms,
    DateTime now,
  ) {
    if (rows.isEmpty) return const [];
    // bm25: lower (more negative) = better; rows arrive best first.
    final best = rows.map((r) => r.read<double>('score')).reduce(math.min);
    return [for (final r in rows) _toHit(type, r, terms, now, best)];
  }

  SearchHit _toHit(
    ItemType type,
    QueryRow r,
    List<String> terms,
    DateTime now,
    double best,
  ) {
    final title = r.read<String>('title');
    final score = r.read<double>('score');
    final updatedAt = r.read<DateTime>('updated_at');
    final pinned = r.read<bool>('is_pinned');
    final ageDays = math.max(0, now.difference(updatedAt).inHours) / 24;
    final relevance =
        (best < 0 ? score / best : 1.0) +
        (titleMatchesAll(title, terms) ? titleBoost : 0) +
        recencyBoost * math.exp(-ageDays / 14) +
        (pinned ? pinnedBoost : 0);
    final due = type == ItemType.task
        ? r.readNullable<DateTime>('due_date')
        : null;
    return SearchHit(
      ref: ItemRef(type, r.read<String>('id')),
      title: title,
      relevance: relevance,
      updatedAt: updatedAt,
      snippet: r.readNullable<String>('snippet') ?? '',
      detail: r.readNullable<String>('meta') ?? '',
      folderName: r.readNullable<String>('folder_name'),
      isPinned: pinned,
      isLocked: r.read<bool>('is_locked'),
      isArchived: r.readNullable<DateTime>('archived_at') != null,
      dueDay: due == null ? null : DateUtilsX.fromStoredDay(due),
      dueMinutes: type == ItemType.task
          ? r.readNullable<int>('due_minutes')
          : null,
      isCompleted:
          type == ItemType.task &&
          r.readNullable<DateTime>('completed_at') != null,
      triggerAt: type == ItemType.reminder
          ? r.readNullable<DateTime>('trigger_at')
          : null,
    );
  }

  /// True when every term starts a word of [title] (case-insensitive).
  static bool titleMatchesAll(String title, List<String> terms) {
    for (final t in terms) {
      final re = RegExp(
        '(^|[^\\p{L}\\p{N}])${RegExp.escape(t)}',
        caseSensitive: false,
        unicode: true,
      );
      if (!re.hasMatch(title)) return false;
    }
    return true;
  }
}

/// Per-module DAO arguments: habits index `name`/`category` and vault only
/// `title`, so the title-column restriction applies to notes only.
class _Args {
  _Args(ItemType type, this.match, String? title, SearchFilters f)
    : titleOnly = type == ItemType.note ? title : null,
      tagIds = f.tagId == null ? const [] : [f.tagId!];

  final String match;
  final String? titleOnly;
  final List<String> tagIds;
}
