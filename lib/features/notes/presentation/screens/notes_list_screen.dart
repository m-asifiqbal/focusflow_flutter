/// ============================================================
/// NOTES LIST — screen 07 (`/library/notes`)
/// ============================================================
///
/// What: large header ("Notes" · "48 notes · 3 pinned", grid/list toggle,
/// ⋯), search with tag filter, folder chips (+ New folder), the sort /
/// Select row and the masonry grid (or list) of note cards, pinned first.
/// Multi-select swaps the header for "3 selected" and floats the
/// ItemSelectionBar (Archive · Delete · Move · Tag · Pin, with Undo).
/// Why: everything is live (StreamProviders over the repositories); the
/// writes go through notes_list_actions / the shared item actions, so
/// this file is layout only.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart' as settings;
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_header.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_list_states.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_masonry.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_menus.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_toolbar.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:go_router/go_router.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({this.folderId, super.key});

  /// Folder chip to start on (`/library/notes?folderId=…`, from Library ›
  /// Tags & Folders); null = All.
  final String? folderId;

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(notesListFilterProvider).text,
  );

  @override
  void initState() {
    super.initState();
    final folderId = widget.folderId;
    if (folderId != null) {
      // Providers can't change while the tree builds (initState runs inside
      // a build); pick the folder chip right after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(notesListFilterProvider.notifier).selectFolder(folderId);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    ref.read(notesListFilterProvider.notifier)
      ..search('')
      ..selectTag(null)
      ..selectFolder(null);
  }

  void _create() {
    final filter = ref.read(notesListFilterProvider);
    context.push(AppRoutes.newNoteWith(folderId: filter.folderId));
  }

  @override
  Widget build(BuildContext context) {
    final selecting = ref.watch(
      itemSelectionProvider(notesSelectionScope).select((s) => s.active),
    );
    final tagActive = ref.watch(
      notesListFilterProvider.select((f) => f.tagId != null),
    );
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(itemSelectionProvider(notesSelectionScope).notifier).clear();
        }
      },
      child: FFScaffold(
        safeBottom: false,
        floating: selecting
            ? const ItemSelectionBar(
                scope: notesSelectionScope,
                module: ItemType.note,
              )
            : null,
        // Title + view/more stay fixed; search, folders and notes scroll.
        body: Column(
          children: [
            const NotesHeader(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.screen,
                          AppSpacing.md,
                          AppSpacing.screen,
                          AppSpacing.lg,
                        ),
                        child: FFSearchField(
                          controller: _search,
                          hint: 'Search notes...',
                          onChanged: ref
                              .read(notesListFilterProvider.notifier)
                              .search,
                          onClear: () => ref
                              .read(notesListFilterProvider.notifier)
                              .search(''),
                          onFilter: () => pickNotesTagFilter(context, ref),
                          filterActive: tagActive,
                          filterSemanticLabel: 'Filter by tag',
                        ),
                      ),
                      const NotesFolderChips(),
                      const NotesSortRow(),
                      const SizedBox(height: AppSpacing.xxs),
                    ]),
                  ),
                  _body(),
                  SliverPadding(
                    padding: EdgeInsetsDirectional.only(
                      bottom:
                          bottom +
                          (selecting ? 96 : AppSpacing.bottomBarClearance),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final async = ref.watch(notesListProvider);
    final grid = ref.watch(notesViewProvider) == settings.NotesView.grid;
    final now = ref.watch(clockProvider).now();
    final notes = async.valueOrNull;
    if (notes == null) {
      return SliverToBoxAdapter(
        child: async.hasError
            ? NotesErrorState(onRetry: () => ref.invalidate(notesListProvider))
            : const NotesLoadingState(),
      );
    }
    if (notes.isEmpty) {
      final filter = ref.watch(notesListFilterProvider);
      final total = ref.watch(notesCountsProvider).valueOrNull?.total;
      final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];
      final folder = folders
          .where((f) => f.id == filter.folderId)
          .firstOrNull
          ?.name;
      return SliverToBoxAdapter(
        child: NotesEmptyState(
          hasNotes: filter.isFiltered || (total ?? 1) > 0,
          folderName: filter.text.isEmpty && filter.tagId == null
              ? folder
              : null,
          onCreate: _create,
          onClearFilter: _clearFilters,
        ),
      );
    }
    return NotesSliver(notes: notes, grid: grid, now: now);
  }
}
