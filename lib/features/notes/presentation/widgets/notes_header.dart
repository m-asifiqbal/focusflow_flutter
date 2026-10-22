/// ============================================================
/// NOTES HEADER — "Notes · 48 notes · 3 pinned" (screen 07)
/// ============================================================
///
/// What: the large header with the grid/list toggle and the ⋯ menu; in
/// multi-select mode a compact "3 selected" bar with Done, the bulk
/// actions sheet ("3 items selected") and All / None.
/// Why: counts are live ([notesCountsProvider]); the toggle persists in
/// Settings › Notes.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart' as settings;
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/notes_format.dart';
import 'package:focusflow/features/notes/presentation/notes_list_actions.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_menus.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';

class NotesHeader extends ConsumerWidget {
  const NotesHeader({super.key});

  static const EdgeInsetsGeometry _padding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.screen,
    AppSpacing.sm,
    AppSpacing.screen,
    AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecting = ref.watch(
      itemSelectionProvider(notesSelectionScope).select((s) => s.active),
    );
    if (selecting) return const _SelectionHeader();
    final counts = ref.watch(notesCountsProvider).valueOrNull;
    final grid = ref.watch(notesViewProvider) == settings.NotesView.grid;
    return FFLargeHeader(
      title: tr('Notes'),
      leading: const FFBackButton(),
      padding: _padding,
      subtitle: counts == null
          ? ' '
          : NotesFormat.headerSubtitle(counts.total, counts.pinned),
      actions: [
        FFRoundIconButton(
          icon: grid
              ? FontAwesomeIcons.tableCellsLarge
              : FontAwesomeIcons.listUl,
          semanticLabel: grid ? tr('Show as list') : tr('Show as grid'),
          onPressed: () => setNotesView(
            ref,
            grid ? settings.NotesView.list : settings.NotesView.grid,
          ),
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.ellipsis,
          semanticLabel: tr('More options'),
          onPressed: () => showNotesMoreMenu(context, ref),
        ),
      ],
    );
  }
}

class _SelectionHeader extends ConsumerWidget {
  const _SelectionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = itemSelectionProvider(notesSelectionScope);
    final sel = ref.watch(provider);
    final selector = ref.read(provider.notifier);
    final visible = ref.watch(notesListProvider).valueOrNull ?? const [];
    final allSelected =
        visible.isNotEmpty && visible.every((n) => sel.contains(n.ref));
    return FFNavHeader(
      leading: FFNavAction(
        label: tr('Done'),
        emphasized: true,
        onPressed: selector.clear,
      ),
      title: sel.count == 0
          ? tr('Select notes')
          : tr('{count} selected', {'count': sel.count}),
      trailing: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.ellipsis,
          semanticLabel: tr('Actions for selected notes'),
          onPressed: sel.count == 0
              ? null
              : () => showSelectionActions(
                  context,
                  ref,
                  sel.selected.toList(),
                  onDone: selector.clear,
                ),
        ),
        FFNavAction(
          label: allSelected ? tr('None') : tr('All'),
          onPressed: () => allSelected
              ? selector.selectAll(const [])
              : selector.selectAll(visible.map((n) => n.ref)),
        ),
      ],
    );
  }
}
