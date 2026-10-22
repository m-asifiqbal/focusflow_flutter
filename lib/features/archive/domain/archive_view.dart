/// ============================================================
/// ARCHIVE VIEW — pure filtering / grouping of archived items (screen 23)
/// ============================================================
///
/// What: turns the live list of archived items (newest archive first, from
/// `ItemsRepository.watchArchived`) into what the Archive screen shows:
/// per-module chip counts over *all* archived items, the rows matching the
/// module chip + search text, grouped "This month" / "Earlier".
/// Why: kept out of widgets and providers so it is plain, testable Dart;
/// counts must not shrink while the user types a search.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// Order of the Archive rows (search field's filter button).
enum ArchiveSort {
  newest,
  oldest,
  title;

  /// Menu text in the active language (a getter: it follows a switch).
  String get label => switch (this) {
    newest => tr('Recently archived'),
    oldest => tr('Oldest first'),
    title => tr('Title A–Z'),
  };
}

/// Module chip (null = All), search text and sort of the Archive screen.
@immutable
class ArchiveFilter {
  const ArchiveFilter({
    this.type,
    this.query = '',
    this.sort = ArchiveSort.newest,
  });

  final ItemType? type;
  final String query;
  final ArchiveSort sort;

  ArchiveFilter withType(ItemType? type) =>
      ArchiveFilter(type: type, query: query, sort: sort);

  ArchiveFilter withQuery(String query) =>
      ArchiveFilter(type: type, query: query, sort: sort);

  ArchiveFilter withSort(ArchiveSort sort) =>
      ArchiveFilter(type: type, query: query, sort: sort);

  /// True when the item passes the chip and the (case-insensitive) title
  /// search.
  bool matches(ItemSummary s) {
    if (type != null && s.type != type) return false;
    final q = query.trim().toLowerCase();
    return q.isEmpty || s.displayTitle.toLowerCase().contains(q);
  }

  @override
  bool operator ==(Object other) =>
      other is ArchiveFilter &&
      other.type == type &&
      other.query == query &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(type, query, sort);
}

/// When an archived item was archived, relative to now.
enum ArchiveSection {
  thisMonth,
  earlier;

  /// Section title in the active language.
  String get label => switch (this) {
    thisMonth => tr('This month'),
    earlier => tr('Earlier'),
  };

  static ArchiveSection of(DateTime archivedAt, DateTime now) =>
      archivedAt.year == now.year && archivedAt.month == now.month
      ? thisMonth
      : earlier;
}

/// One titled card of rows.
@immutable
class ArchiveGroup {
  const ArchiveGroup(this.section, this.items);

  final ArchiveSection section;
  final List<ItemSummary> items;
}

/// Everything the Archive screen renders for one [ArchiveFilter].
@immutable
class ArchiveView {
  const ArchiveView({
    required this.total,
    required this.counts,
    required this.items,
    required this.groups,
  });

  /// Builds the view from [all] archived items (newest archive first).
  /// Rows keep [all]'s order for [ArchiveSort.newest]; "oldest" reverses it
  /// (and lists "Earlier" first); "title" sorts each section A–Z.
  factory ArchiveView.from(
    List<ItemSummary> all,
    ArchiveFilter filter,
    DateTime now,
  ) {
    final counts = <ItemType, int>{};
    for (final s in all) {
      counts[s.type] = (counts[s.type] ?? 0) + 1;
    }
    final items = [
      for (final s in all)
        if (filter.matches(s)) s,
    ];
    switch (filter.sort) {
      case ArchiveSort.newest:
        break;
      case ArchiveSort.oldest:
        items.setAll(0, items.reversed.toList());
      case ArchiveSort.title:
        items.sort(
          (a, b) => a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          ),
        );
    }
    final bySection = <ArchiveSection, List<ItemSummary>>{};
    for (final s in items) {
      final section = ArchiveSection.of(s.archivedAt ?? s.updatedAt, now);
      (bySection[section] ??= []).add(s);
    }
    return ArchiveView(
      total: all.length,
      counts: Map.unmodifiable(counts),
      items: List.unmodifiable(items),
      groups: [
        for (final section
            in filter.sort == ArchiveSort.oldest
                ? ArchiveSection.values.reversed
                : ArchiveSection.values)
          if (bySection[section] case final rows?) ArchiveGroup(section, rows),
      ],
    );
  }

  /// Every archived item, whatever the filter.
  final int total;

  /// Archived items per module (modules without any are absent).
  final Map<ItemType, int> counts;

  /// The rows matching the filter, newest archive first.
  final List<ItemSummary> items;
  final List<ArchiveGroup> groups;

  List<ItemRef> get refs => [for (final s in items) s.ref];
}
