/// ============================================================
/// SEARCH REPOSITORY (contract) — global full-text search
/// ============================================================
///
/// FTS5 prefix matching across Notes, Tasks, Reminders, Habits and Vault
/// (vault: titles only). Trashed items are never returned; archived items
/// only with [SearchFilters.includeArchived]. Results are live: any write
/// to a module table re-runs the query.
/// ============================================================
library;

import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';

abstract interface class SearchRepository {
  /// Ranked hits for [query] + per-module counts. Emits
  /// [SearchResults.empty] when the text has no searchable term.
  Stream<SearchResults> watch(SearchQuery query);

  /// One-shot variant of [watch].
  Future<SearchResults> search(SearchQuery query);
}
