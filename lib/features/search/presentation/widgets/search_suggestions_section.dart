/// ============================================================
/// SEARCH SUGGESTIONS — "PINNED" pills before anything is typed
/// ============================================================
///
/// What: up to five pinned items (any module but the vault) as pills with
/// their module icon; a tap opens the item. Hidden when nothing is pinned.
/// Why: prompt 06's initial state is "recent + suggestions" — pinned items
/// are what the user already marked as important, and the list is a live
/// stream (pinning elsewhere updates it). Built from [SearchPill] so it
/// reads like the recent-search pills above it.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/search/presentation/providers/search_providers.dart';
import 'package:focusflow/features/search/presentation/widgets/search_sections.dart';

class SearchSuggestionsSection extends ConsumerWidget {
  const SearchSuggestionsSection({required this.onOpen, super.key});

  /// Opens a suggested item.
  final ValueChanged<ItemSummary> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(searchSuggestionsProvider).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SearchSectionLabel('Pinned'),
        SearchPillWrap(
          children: [
            for (final item in items)
              SearchPill(
                label: item.title.trim().isEmpty
                    ? item.ref.type.label
                    : item.title.trim(),
                icon: item.ref.type.style.icon,
                semanticLabel: 'Open ${item.title.trim()}',
                onTap: () => onOpen(item),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}
