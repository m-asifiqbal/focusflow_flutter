/// ============================================================
/// ARCHIVE ACTIONS — what the Archive (23) / Trash (24) controls do
/// ============================================================
///
/// What: thin glue between the two screens and the shared lifecycle
/// helpers (`item_lifecycle_actions.dart`: confirmation dialog 28 + 5 s
/// Undo snackbar), the selection state and the sort sheet.
/// Why: keeps the screens layout-only; every destructive action goes
/// through the one shared path, so Undo / confirmation behave the same as
/// everywhere else in the app.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/archive/domain/archive_view.dart';
import 'package:focusflow/features/archive/presentation/providers/archive_providers.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/widgets/choice_sheets.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';

/// Selection scopes of the two screens.
const String kArchiveScope = 'archive';
const String kTrashScope = 'trash';

/// Which list an [ArchiveActions] works on.
enum ArchiveList { archive, trash }

/// Row and bulk actions of one screen.
class ArchiveActions {
  const ArchiveActions(this.context, this.ref, this.list);

  final BuildContext context;
  final WidgetRef ref;
  final ArchiveList list;

  String get _scope =>
      list == ArchiveList.archive ? kArchiveScope : kTrashScope;

  ItemSelection get _selection =>
      ref.read(itemSelectionProvider(_scope).notifier);

  /// Tap: toggles in selection mode; otherwise opens the archived item
  /// (Archive) or starts selecting it (Trash — deleted items don't open).
  void tap(ItemSummary item) {
    final sel = ref.read(itemSelectionProvider(_scope));
    if (sel.active) {
      _selection.toggle(item.ref);
    } else if (list == ArchiveList.archive) {
      openLibraryItem(context, item.ref);
    } else {
      _selection.start(item.ref);
    }
  }

  /// Long-press: enters selection mode with [item] selected.
  void longPress(ItemSummary item) {
    final sel = ref.read(itemSelectionProvider(_scope));
    sel.active ? _selection.toggle(item.ref) : _selection.start(item.ref);
  }

  /// Restore / recover [items]; leaves selection mode when it worked.
  Future<void> restore(List<ItemSummary> items) async {
    final refs = [for (final s in items) s.ref];
    final title = items.length == 1 ? items.single.displayTitle : null;
    final done = list == ArchiveList.archive
        ? await restoreFromArchive(context, ref, refs, title: title)
        : await restoreFromTrash(context, ref, refs, title: title);
    if (done) _selection.clear();
  }

  /// Archive: moves [items] to Recently Deleted (confirm + Undo).
  /// Trash: deletes them forever (confirm, no Undo).
  Future<void> delete(List<ItemSummary> items) async {
    final refs = [for (final s in items) s.ref];
    final title = items.length == 1 ? items.single.displayTitle : null;
    final done = list == ArchiveList.archive
        ? await deleteItems(
            context,
            ref,
            refs,
            offerArchive: false,
            title: title,
          )
        : await deleteItemsForever(context, ref, refs, title: title);
    if (done) _selection.clear();
  }

  /// "All" / "None" in the header while selecting.
  void toggleAll(List<ItemRef> visible) {
    final sel = ref.read(itemSelectionProvider(_scope));
    final all = visible.isNotEmpty && visible.every(sel.contains);
    all ? _selection.start() : _selection.selectAll(visible);
  }

  /// Archive's search filter button: sort order sheet.
  Future<void> pickSort() async {
    final current = ref.read(archiveFilterProvider).sort;
    final picked = await showChoiceSheet<ArchiveSort>(
      context,
      title: tr('Sort archive'),
      selected: current,
      options: [
        for (final s in ArchiveSort.values)
          ChoiceOption(value: s, label: s.label),
      ],
    );
    if (picked != null) {
      ref.read(archiveFilterProvider.notifier).setSort(picked.value);
    }
  }
}

/// The selected rows of [items], in list order.
List<ItemSummary> selectedOf(List<ItemSummary> items, SelectionState sel) => [
  for (final s in items)
    if (sel.contains(s.ref)) s,
];
