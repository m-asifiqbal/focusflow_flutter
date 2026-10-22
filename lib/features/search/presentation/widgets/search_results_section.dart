/// ============================================================
/// SEARCH RESULTS SECTION — "TOP RESULTS" card + its states (screen 06)
/// ============================================================
///
/// Data → label row ("Sort: Relevance") + one card of [SearchResultRow]s
/// (All shows the top [allPreview]; "Show all N results" expands) ·
/// loading → skeleton rows · empty → 'No matches for "x"' (+ Clear
/// filters) · error → message + Retry.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/search/presentation/widgets/search_result_row.dart';
import 'package:focusflow/features/search/presentation/widgets/search_sections.dart';

class SearchResultsSection extends StatelessWidget {
  const SearchResultsSection({
    required this.results,
    required this.query,
    required this.sort,
    required this.filtersActive,
    required this.expanded,
    required this.onToggleSort,
    required this.onOpen,
    required this.onShowAll,
    required this.onClearFilters,
    required this.onRetry,
    this.loading = false,
    this.error = false,
    super.key,
  });

  /// Last results (null while the first query loads).
  final SearchResults? results;
  final String query;
  final SearchSort sort;
  final bool filtersActive;

  /// Show every hit instead of the top [allPreview].
  final bool expanded;
  final bool loading;
  final bool error;
  final VoidCallback onToggleSort;
  final ValueChanged<SearchHit> onOpen;
  final VoidCallback onShowAll;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;

  /// Rows shown before "Show all".
  static const int allPreview = 5;

  @override
  Widget build(BuildContext context) {
    final r = results;
    final Widget body;
    if (error && r == null) {
      body = FFEmptyState(
        compact: true,
        colors: ModuleStyle.reminders.colors,
        icon: FontAwesomeIcons.circleExclamation,
        title: tr('Search failed'),
        body: tr('Something went wrong while searching.'),
        ctaLabel: tr('Retry'),
        ctaIcon: FontAwesomeIcons.rotateRight,
        onCta: onRetry,
      );
    } else if (r == null || (loading && r.hits.isEmpty)) {
      body = const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.grouped,
        ),
        child: FFSkeletonList(count: 3, kind: FFSkeletonKind.row),
      );
    } else if (r.hits.isEmpty) {
      body = FFEmptyState(
        compact: true,
        colors: ModuleStyle.notes.colors,
        icon: FontAwesomeIcons.magnifyingGlass,
        title: tr('No matches for “{query}”', {'query': query}),
        body: filtersActive
            ? tr('Try removing filters or checking the spelling.')
            : tr('Try another word or check the spelling.'),
        ctaLabel: filtersActive ? tr('Clear filters') : null,
        ctaIcon: FontAwesomeIcons.xmark,
        onCta: filtersActive ? onClearFilters : null,
      );
    } else {
      final shown = expanded ? r.hits : r.hits.take(allPreview).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.grouped,
            ),
            child: FFCard(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                children: [
                  for (final hit in shown)
                    FFOpenOriginTracker(
                      key: ValueKey(hit.ref),
                      radius: 0,
                      child: SearchResultRow(
                        hit: hit,
                        query: query,
                        onTap: () => onOpen(hit),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (shown.length < r.hits.length)
            Center(
              child: FFTextButton(
                label: tr('Show all {length} results', {
                  'length': r.hits.length,
                }),
                onPressed: onShowAll,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionLabel(
          tr('Top results'),
          actionLabel: tr('Sort: {label}', {'label': sort.label}),
          onAction: onToggleSort,
        ),
        body,
      ],
    );
  }
}
