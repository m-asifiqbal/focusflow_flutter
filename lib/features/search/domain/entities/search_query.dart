/// ============================================================
/// SEARCH QUERY — what Global search (screen 06) asks the repository
/// ============================================================
///
/// [SearchQuery] = the typed text + the module chip + [SearchFilters] (date
/// range, tag, priority, Include archived) + the sort. Trashed items are
/// never searchable, so there is deliberately no "include deleted" flag.
/// Value types with `==` so Riverpod families can key on them.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// Result order of the "Sort:" toggle.
enum SearchSort {
  /// bm25 blended with recency and pinned boosts.
  relevance,

  /// Most recently edited first.
  recent;

  /// Toggle text in the active language (a getter: it follows a language
  /// switch).
  String get label => switch (this) {
    relevance => tr('Relevance'),
    recent => tr('Recent'),
  };
}

/// The optional filters under "SEARCH FILTERS".
@immutable
class SearchFilters {
  const SearchFilters({
    this.from,
    this.to,
    this.tagId,
    this.tagName,
    this.minPriority,
    this.includeArchived = false,
  });

  /// Edited on or after this instant (inclusive).
  final DateTime? from;

  /// Edited before this instant (exclusive).
  final DateTime? to;

  /// Only items carrying this tag.
  final String? tagId;

  /// Display name of [tagId] (chip label only; not part of the query).
  final String? tagName;

  /// Only tasks whose priority value is >= this (TaskPriority.index).
  /// Priority exists on tasks only, so setting it limits results to tasks.
  final int? minPriority;

  /// Also search archived items (trashed items are never searched).
  final bool includeArchived;

  static const none = SearchFilters();

  bool get hasDateRange => from != null || to != null;

  /// Any filter that narrows results (used for the "remove filters" hint).
  bool get isActive =>
      hasDateRange || tagId != null || minPriority != null || includeArchived;

  SearchFilters copyWith({
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? Function()? tagId,
    String? Function()? tagName,
    int? Function()? minPriority,
    bool? includeArchived,
  }) => SearchFilters(
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
    tagId: tagId == null ? this.tagId : tagId(),
    tagName: tagName == null ? this.tagName : tagName(),
    minPriority: minPriority == null ? this.minPriority : minPriority(),
    includeArchived: includeArchived ?? this.includeArchived,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.from == from &&
      other.to == to &&
      other.tagId == tagId &&
      other.tagName == tagName &&
      other.minPriority == minPriority &&
      other.includeArchived == includeArchived;

  @override
  int get hashCode =>
      Object.hash(from, to, tagId, tagName, minPriority, includeArchived);
}

/// One search request.
@immutable
class SearchQuery {
  const SearchQuery({
    required this.text,
    this.type,
    this.filters = SearchFilters.none,
    this.sort = SearchSort.relevance,
    this.limitPerModule = 50,
  });

  /// Raw user input; every term is prefix-matched (FTS5).
  final String text;

  /// Module chip; null = All. Counts are always returned for every module.
  final ItemType? type;
  final SearchFilters filters;
  final SearchSort sort;
  final int limitPerModule;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.type == type &&
      other.filters == filters &&
      other.sort == sort &&
      other.limitPerModule == limitPerModule;

  @override
  int get hashCode => Object.hash(text, type, filters, sort, limitPerModule);
}
