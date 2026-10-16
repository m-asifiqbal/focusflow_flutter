/// ============================================================
/// GLOBAL SEARCH — screen 06 (`/search?q=`)
/// ============================================================
///
/// Focused search field + Cancel → module chips with live counts → TOP
/// RESULTS (highlighted titles, meta, Sort toggle) → RECENT SEARCHES →
/// SEARCH FILTERS. Typing is debounced 200 ms (GlobalSearchController); results
/// are a live StreamProvider, so edits elsewhere update the list. The
/// previous results stay on screen while the next query runs (no flicker).
/// Before typing: recent searches (secure store) + pinned suggestions.
/// Vault hits open only through ensureVaultUnlocked, and opening one never
/// records the query in the history.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/search/presentation/providers/search_providers.dart';
import 'package:focusflow/features/search/presentation/widgets/search_filters_section.dart';
import 'package:focusflow/features/search/presentation/widgets/search_results_section.dart';
import 'package:focusflow/features/search/presentation/widgets/search_sections.dart';
import 'package:focusflow/features/search/presentation/widgets/search_suggestions_section.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery, super.key});

  /// `?q=` — searched immediately.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  SearchResults? _last;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: q);
    if (q.isNotEmpty) {
      Future.microtask(
        () => ref.read(searchControllerProvider.notifier).searchNow(q),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  GlobalSearchController get _ctl =>
      ref.read(searchControllerProvider.notifier);

  void _useRecent(String term) {
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    _ctl.searchNow(term);
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _open(SearchHit hit) async {
    if (hit.type == ItemType.vault) {
      // What was typed to find a password stays out of the history.
      if (!await ensureVaultUnlocked(context) || !mounted) return;
    } else {
      await _ctl.remember();
      if (!mounted) return;
    }
    context.push(AppRoutes.open(hit.ref));
  }

  void _openSuggestion(ItemSummary item) =>
      context.push(AppRoutes.open(item.ref));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final recent = ref.watch(recentSearchesProvider).valueOrNull ?? const [];
    final hasSuggestions =
        ref.watch(searchSuggestionsProvider).valueOrNull?.isNotEmpty ?? false;
    AsyncValue<SearchResults>? async;
    if (state.hasQuery) {
      async = ref.watch(searchResultsProvider(state.request));
      final value = async!.valueOrNull;
      if (value != null) _last = value;
    } else {
      _last = null;
    }
    final results = state.hasQuery ? _last : null;

    return FFScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchBar(
            controller: _controller,
            focusNode: _focus,
            onChanged: (t) {
              setState(() => _expanded = false);
              _ctl.setInput(t);
            },
            onSubmitted: (t) {
              _ctl.searchNow(t);
              _ctl.remember();
            },
            onCancel: _cancel,
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsetsDirectional.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxxl,
              ),
              children: [
                _TypeChips(
                  selected: state.type,
                  results: results,
                  onSelected: (t) {
                    setState(() => _expanded = t != null);
                    _ctl.setType(t);
                  },
                ),
                const SizedBox(height: _gapAfterChips),
                if (state.hasQuery) ...[
                  SearchResultsSection(
                    results: results,
                    query: state.query.trim(),
                    sort: state.sort,
                    filtersActive: state.filters.isActive,
                    expanded: _expanded || state.type != null,
                    loading: async?.isLoading ?? false,
                    error: async?.hasError ?? false,
                    onToggleSort: _ctl.toggleSort,
                    onOpen: _open,
                    onShowAll: () => setState(() => _expanded = true),
                    onClearFilters: () => _ctl.setFilters(SearchFilters.none),
                    onRetry: () =>
                        ref.invalidate(searchResultsProvider(state.request)),
                  ),
                  // The next label row is a 44-pt tap target, so it brings its own air.
                  const SizedBox(height: AppSpacing.md),
                ],
                if (recent.isNotEmpty) ...[
                  SearchSectionLabel(
                    'Recent searches',
                    actionLabel: 'Clear',
                    onAction: () =>
                        ref.read(recentSearchesProvider.notifier).clear(),
                  ),
                  SearchPillWrap(
                    children: [
                      for (final term in recent)
                        SearchPill.recent(
                          term: term,
                          onTap: () => _useRecent(term),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                ],
                if (!state.hasQuery)
                  SearchSuggestionsSection(onOpen: _openSuggestion),
                if (recent.isEmpty && !state.hasQuery && !hasSuggestions) ...[
                  FFEmptyState(
                    compact: true,
                    colors: ModuleStyle.notes.colors,
                    icon: FontAwesomeIcons.magnifyingGlass,
                    title: 'Search everything',
                    body:
                        'Notes, tasks, reminders, habits and vault titles — '
                        'all offline.',
                  ),
                  const SizedBox(height: AppSpacing.section),
                ],
                const SearchFiltersSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _gapAfterChips = AppSpacing.sm;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  /// "Cancel" measured on design/06 (between `button` and `buttonSmall`).
  static const double _cancelSize = 15;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.grouped,
        AppSpacing.xs,
        AppSpacing.grouped,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: FFSearchField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              hint: 'Search everything',
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FFTextButton(
            label: 'Cancel',
            onPressed: onCancel,
            padding: EdgeInsetsDirectional.zero,
            style: context.text.button.copyWith(fontSize: _cancelSize),
          ),
        ],
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({
    required this.selected,
    required this.results,
    required this.onSelected,
  });

  final ItemType? selected;
  final SearchResults? results;
  final ValueChanged<ItemType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final r = results;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.xs,
      ),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          FFChip(
            label: 'All',
            count: r?.total,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final t in ItemType.values) ...[
            const SizedBox(width: AppSpacing.sm),
            FFChip(
              label: t.plural,
              icon: t.style.icon,
              count: r?.countOf(t),
              selected: selected == t,
              onTap: () => onSelected(t),
            ),
          ],
        ],
      ),
    );
  }
}
