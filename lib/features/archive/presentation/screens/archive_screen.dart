/// ============================================================
/// ARCHIVE — `/library/archive` (screen 23)
/// ============================================================
///
/// What: every archived item across modules — search (with sort), module
/// chips with counts, the "hidden from lists" banner, rows grouped
/// "This month" / "Earlier" with a restore button, swipe → Restore /
/// Delete, "Select" → multi-select (Cancel · All), and the sticky
/// "Restore all · Delete all" bar (acts on the rows shown).
/// Why: archived items are out of every normal list; this is the one place
/// to bring them back. Live: archiving anywhere adds the row at once.
/// All writes go through `archive_actions.dart` → lifecycle helpers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/archive/domain/archive_view.dart';
import 'package:focusflow/features/archive/presentation/archive_actions.dart';
import 'package:focusflow/features/archive/presentation/archive_format.dart';
import 'package:focusflow/features/archive/presentation/providers/archive_providers.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_bottom_bar.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_header.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_notice.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_rows.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(archiveFilterProvider);
    final async = ref.watch(archiveProvider(filter));
    final view = async.valueOrNull;
    final sel = ref.watch(itemSelectionProvider(kArchiveScope));
    final actions = ArchiveActions(context, ref, ArchiveList.archive);
    final selecting = sel.active;
    final hasItems = view != null && view.total > 0;
    final shown = view?.items ?? const <ItemSummary>[];
    final picked = selectedOf(shown, sel);

    final compact = ArchiveBottomBar.compact(context);
    return FFScaffold(
      bottomBar: hasItems && shown.isNotEmpty
          ? ArchiveBottomBar(
              start: FFSecondaryButton(
                variant: FFSecondaryVariant.surface,
                icon: compact ? null : FontAwesomeIcons.boxOpen,
                label: selecting
                    ? ArchiveFormat.withCount('Restore', picked.length)
                    : 'Restore all',
                onPressed: selecting && picked.isEmpty
                    ? null
                    : () => actions.restore(selecting ? picked : shown),
              ),
              end: FFSoftDangerButton(
                icon: compact ? null : FontAwesomeIcons.trashCan,
                label: selecting
                    ? ArchiveFormat.withCount('Delete', picked.length)
                    : 'Delete all',
                onPressed: selecting && picked.isEmpty
                    ? null
                    : () => actions.delete(selecting ? picked : shown),
              ),
            )
          : null,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
          ),
          children: [
            ArchiveHeader(
              title: 'Archive',
              selecting: selecting,
              canSelect: hasItems,
              allSelected: shown.isNotEmpty && picked.length == shown.length,
              onSelect: () => ref
                  .read(itemSelectionProvider(kArchiveScope).notifier)
                  .start(),
              onCancel: () => ref
                  .read(itemSelectionProvider(kArchiveScope).notifier)
                  .clear(),
              onToggleAll: () =>
                  actions.toggleAll([for (final s in shown) s.ref]),
            ),
            ..._body(context, async, view, filter, actions, sel),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AsyncValue<ArchiveView> async,
    ArchiveView? view,
    ArchiveFilter filter,
    ArchiveActions actions,
    SelectionState sel,
  ) {
    const pad = EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.grouped);
    if (view == null) {
      return [
        Padding(
          padding: pad.add(
            const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          ),
          child: async.hasError
              ? FFEmptyState.compact(
                  colors: TagPalette.high,
                  icon: FontAwesomeIcons.triangleExclamation,
                  title: "Couldn't load the archive",
                  body: 'Your items are safe. Try again.',
                  ctaLabel: 'Retry',
                  ctaIcon: FontAwesomeIcons.arrowsRotate,
                  onCta: () => ref.invalidate(archivedItemsProvider),
                )
              : const FFSkeletonList(kind: FFSkeletonKind.row, count: 6),
        ),
      ];
    }
    if (view.total == 0) {
      return const [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.grouped,
            AppSpacing.xxxl,
            AppSpacing.grouped,
            0,
          ),
          child: FFEmptyState(
            colors: TagPalette.ideas,
            icon: FontAwesomeIcons.boxArchive,
            title: 'Nothing archived yet',
            body: 'Swipe left on any item to archive it.',
          ),
        ),
      ];
    }
    final now = ref.watch(clockProvider).now();
    final notifier = ref.read(archiveFilterProvider.notifier);
    return [
      Padding(
        padding: pad.add(const EdgeInsetsDirectional.only(top: 4)),
        child: FFSearchField(
          controller: _search,
          hint: ArchiveFormat.searchHint(view.total),
          onChanged: notifier.setQuery,
          onClear: () => notifier.setQuery(''),
          onFilter: actions.pickSort,
          filterActive: filter.sort != ArchiveSort.newest,
          filterSemanticLabel: 'Sort archive',
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FFChipBar<String>(
        padding: pad,
        selected: filter.type?.key ?? 'all',
        onSelected: (k) => notifier.setType(ItemType.fromKey(k)),
        items: [
          FFChipItem(value: 'all', label: 'All', count: view.total),
          for (final t in ItemType.values)
            if (view.counts[t] case final n?)
              FFChipItem(
                value: t.key,
                label: t.plural,
                icon: t.style.icon,
                count: n,
              ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      const Padding(
        padding: pad,
        child: ArchiveNotice(
          icon: FontAwesomeIcons.circleInfo,
          body:
              'Archived items are hidden from lists, search and reminders '
              'but kept safe & synced.',
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      if (view.items.isEmpty)
        const Padding(
          padding: pad,
          child: FFEmptyState.compact(
            colors: TagPalette.ideas,
            icon: FontAwesomeIcons.magnifyingGlass,
            title: 'No matches',
            body: 'No archived items match this search or filter.',
          ),
        ),
      for (final g in view.groups) ...[
        Padding(
          padding: pad,
          child: FFGroupedList(
            label: g.section.label,
            dividerIndent: kArchiveDividerIndent,
            children: [
              for (final s in g.items)
                ArchivedItemRow(
                  key: ValueKey(s.ref),
                  item: s,
                  now: now,
                  selecting: sel.active,
                  selected: sel.contains(s.ref),
                  actions: ArchiveRowActions(
                    onTap: () => actions.tap(s),
                    onLongPress: () => actions.longPress(s),
                    onRestore: () => actions.restore([s]),
                    onDelete: () => actions.delete([s]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    ];
  }
}
