/// ============================================================
/// SEARCH HIT — one ranked result row + the per-module counts
/// ============================================================
///
/// A [SearchHit] carries only what the result row needs: title (for
/// highlighting), the folder, timestamps for the meta line and the module
/// extras (task due day/time, reminder trigger, habit category, vault kind).
/// Vault hits and locked notes never carry a snippet — titles only.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';

@immutable
class SearchHit {
  const SearchHit({
    required this.ref,
    required this.title,
    required this.relevance,
    required this.updatedAt,
    this.snippet = '',
    this.detail = '',
    this.folderName,
    this.isPinned = false,
    this.isLocked = false,
    this.isArchived = false,
    this.dueDay,
    this.dueMinutes,
    this.isCompleted = false,
    this.triggerAt,
  });

  final ItemRef ref;
  final String title;

  /// Higher = better (blended bm25 + title, recency and pinned boosts).
  final double relevance;
  final DateTime updatedAt;

  /// Matching body excerpt ('' for vault items and locked notes).
  final String snippet;

  /// Habit category / vault kind ("Login", "Card" …).
  final String detail;
  final String? folderName;
  final bool isPinned;

  /// Locked note or vault item: open behind a gate, never show content.
  final bool isLocked;
  final bool isArchived;

  /// Task due date as a local calendar day (decoded floating day).
  final DateTime? dueDay;

  /// Task due time, minutes after midnight.
  final int? dueMinutes;
  final bool isCompleted;

  /// Reminder's next fire time (snooze wins).
  final DateTime? triggerAt;

  ItemType get type => ref.type;

  @override
  bool operator ==(Object other) =>
      other is SearchHit &&
      other.ref == ref &&
      other.title == title &&
      other.relevance == relevance &&
      other.updatedAt == updatedAt &&
      other.snippet == snippet &&
      other.detail == detail &&
      other.folderName == folderName &&
      other.isPinned == isPinned &&
      other.isLocked == isLocked &&
      other.isArchived == isArchived &&
      other.dueDay == dueDay &&
      other.dueMinutes == dueMinutes &&
      other.isCompleted == isCompleted &&
      other.triggerAt == triggerAt;

  @override
  int get hashCode => Object.hash(
    ref,
    title,
    relevance,
    updatedAt,
    snippet,
    detail,
    folderName,
    isPinned,
    isLocked,
    isArchived,
    dueDay,
    dueMinutes,
    isCompleted,
    triggerAt,
  );
}

/// Ranked hits of the selected module chip + match counts of every module.
@immutable
class SearchResults {
  const SearchResults({required this.hits, required this.counts});

  static const empty = SearchResults(hits: [], counts: {});

  final List<SearchHit> hits;

  /// Matches per module (ignores the module chip, honours the filters).
  final Map<ItemType, int> counts;

  int countOf(ItemType type) => counts[type] ?? 0;

  /// The "All" chip.
  int get total => counts.values.fold(0, (a, b) => a + b);

  static const _hitsEq = ListEquality<SearchHit>();
  static const _countsEq = MapEquality<ItemType, int>();

  @override
  bool operator ==(Object other) =>
      other is SearchResults &&
      _hitsEq.equals(other.hits, hits) &&
      _countsEq.equals(other.counts, counts);

  @override
  int get hashCode => Object.hash(_hitsEq.hash(hits), _countsEq.hash(counts));
}
