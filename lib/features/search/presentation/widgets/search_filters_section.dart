/// ============================================================
/// SEARCH FILTERS SECTION — Date range · Tag · Priority · Include archived
/// ============================================================
///
/// Pills under "SEARCH FILTERS" (screen 06). An applied filter turns its
/// pill solid and shows its value ("Last 7 days" range → "6/4 – 6/10",
/// "#work", "High+"). Trashed items are never searchable, so there is no
/// "include deleted" option.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/search/presentation/providers/search_providers.dart';
import 'package:focusflow/features/search/presentation/widgets/search_filter_sheets.dart';
import 'package:focusflow/features/search/presentation/widgets/search_sections.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class SearchFiltersSection extends ConsumerWidget {
  const SearchFiltersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(searchControllerProvider.select((s) => s.filters));
    final ctl = ref.read(searchControllerProvider.notifier);

    Future<void> apply(Future<SearchFilters?> pick) async {
      final next = await pick;
      if (next != null) ctl.setFilters(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionLabel(tr('Search filters')),
        SearchPillWrap(
          children: [
            SearchPill(
              label: searchDateRangeLabel(f),
              icon: FontAwesomeIcons.solidCalendar,
              active: f.hasDateRange,
              semanticLabel: tr('Date range filter, {searchDateRangeLabel}', {
                'searchDateRangeLabel': searchDateRangeLabel(f),
              }),
              onTap: () => apply(
                pickSearchDateRange(context, f, ref.read(clockProvider).now()),
              ),
            ),
            SearchPill(
              label: f.tagName == null ? tr('Tag') : '#${f.tagName}',
              icon: FontAwesomeIcons.tag,
              active: f.tagId != null,
              semanticLabel: f.tagName == null
                  ? tr('Tag filter')
                  : tr('Tag filter, {tagName}', {'tagName': f.tagName}),
              onTap: () => apply(pickSearchTag(context, ref, f)),
            ),
            SearchPill(
              label: searchPriorityLabel(f),
              icon: FontAwesomeIcons.solidFlag,
              active: f.minPriority != null,
              semanticLabel: tr('Priority filter, {searchPriorityLabel}', {
                'searchPriorityLabel': searchPriorityLabel(f),
              }),
              onTap: () => apply(pickSearchPriority(context, f)),
            ),
            SearchPill(
              label: tr('Include archived'),
              icon: FontAwesomeIcons.boxArchive,
              active: f.includeArchived,
              onTap: () => ctl.setFilters(
                f.copyWith(includeArchived: !f.includeArchived),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
