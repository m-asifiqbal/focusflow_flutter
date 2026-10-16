/// ============================================================
/// NOTES MASONRY — the grid / list slivers of the notes list (screen 07)
/// ============================================================
///
/// What: a 2-column masonry (each card goes to the shorter column, see
/// notes_masonry_layout.dart; the placement is cached per ordered id list,
/// so cards never jump between columns while their content updates) or a
/// compact list.
/// Each note: tap = open (or toggle in multi-select), long-press = item
/// actions sheet, swipe = ItemSwipe (Settings › Gestures). With the
/// "Manual" sort, long-press + drag moves a note onto another card's slot
/// (within its group: pinned or not);
/// long-press + release without moving still opens the actions sheet.
/// Why: lazy slivers (SliverCrossAxisGroup of two SliverLists) keep big
/// lists cheap; pinned-first order comes from the repository.
/// ============================================================
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/widgets/ff_open_origin.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/presentation/notes_list_actions.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_list_row.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_masonry_layout.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/item_actions/item_swipe.dart';
import 'package:go_router/go_router.dart';

/// The notes as slivers (grid when [grid], else rows).
class NotesSliver extends StatefulWidget {
  const NotesSliver({
    required this.notes,
    required this.grid,
    required this.now,
    super.key,
  });

  final List<Note> notes;
  final bool grid;
  final DateTime now;

  @override
  State<NotesSliver> createState() => _NotesSliverState();
}

class _NotesSliverState extends State<NotesSliver> {
  List<String> _ids = const [];
  List<int> _columns = const [];

  /// Column per note; recomputed only when the ordered ids change.
  List<int> _placement(List<Note> notes) {
    final ids = [for (final n in notes) n.id];
    if (!listEquals(ids, _ids)) {
      _ids = ids;
      _columns = MasonryLayout.assign([
        for (final n in notes) estimateNoteCardHeight(n),
      ]);
    }
    return _columns;
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes;
    final grid = widget.grid;
    final now = widget.now;
    Widget item(Note n) =>
        _NoteItem(note: n, notes: notes, grid: grid, now: now);
    const gap = AppSpacing.cardGap;
    if (!grid) {
      return SliverPadding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.screen,
        ),
        sliver: SliverList.separated(
          itemCount: notes.length,
          itemBuilder: (context, i) => item(notes[i]),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 2),
        ),
      );
    }
    final columns = _placement(notes);
    final left = [
      for (var i = 0; i < notes.length; i++)
        if (columns[i] == 0) notes[i],
    ];
    final right = [
      for (var i = 0; i < notes.length; i++)
        if (columns[i] == 1) notes[i],
    ];
    Widget column(List<Note> list, EdgeInsetsDirectional padding) =>
        SliverCrossAxisExpanded(
          flex: 1,
          sliver: SliverPadding(
            padding: padding,
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsetsDirectional.only(bottom: gap),
                child: item(list[i]),
              ),
            ),
          ),
        );
    return SliverPadding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      sliver: SliverCrossAxisGroup(
        slivers: [
          column(left, const EdgeInsetsDirectional.only(end: gap / 2)),
          column(right, const EdgeInsetsDirectional.only(start: gap / 2)),
        ],
      ),
    );
  }
}

class _NoteItem extends ConsumerWidget {
  const _NoteItem({
    required this.note,
    required this.notes,
    required this.grid,
    required this.now,
  });

  final Note note;
  final List<Note> notes;
  final bool grid;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = itemSelectionProvider(notesSelectionScope);
    final selecting = ref.watch(provider.select((s) => s.active));
    final selected = ref.watch(provider.select((s) => s.contains(note.ref)));
    final manual =
        !selecting && ref.watch(notesSortProvider) == NotesSort.manual;

    void toggle() => ref.read(provider.notifier).toggle(note.ref);
    void actions() => showItemActions(context, ref, note.ref);
    final VoidCallback onTap = selecting
        ? toggle
        : () => context.push(AppRoutes.note(note.id));
    final VoidCallback? onLongPress = manual
        ? null
        : (selecting ? toggle : actions);

    Widget child = grid
        ? NoteCard(
            note: note,
            now: now,
            selecting: selecting,
            selected: selected,
            onTap: onTap,
            onLongPress: onLongPress,
          )
        : NoteListRow(
            note: note,
            now: now,
            selecting: selecting,
            selected: selected,
            onTap: onTap,
            onLongPress: onLongPress,
          );
    // The editor grows out of this card (open-container transition).
    child = FFOpenOriginTracker(
      radius: grid ? AppRadii.card : AppRadii.row,
      child: child,
    );
    if (manual) {
      child = _DragToReorder(
        id: note.id,
        radius: grid ? AppRadii.card : AppRadii.row,
        // Pinned notes always lead the list, so a note can only be dropped
        // within its own group (pinned ↔ pinned, others ↔ others).
        canAccept: (dragged) =>
            dragged != note.id &&
            notes.any((n) => n.id == dragged && n.isPinned == note.isPinned),
        onDrop: (dragged) => moveNote(ref, notes, dragged, note.id),
        onHold: actions,
        child: child,
      );
    }
    return ItemSwipe(
      key: ValueKey(note.id),
      item: note.ref,
      isPinned: note.isPinned,
      isFavorite: note.isFavorite,
      enabled: !selecting,
      radius: grid ? AppRadii.card : AppRadii.row,
      title: note.displayTitle,
      child: child,
    );
  }
}

/// Long-press + drag onto another note (Manual sort). A long-press
/// released in place calls [onHold] (the actions sheet).
class _DragToReorder extends StatefulWidget {
  const _DragToReorder({
    required this.id,
    required this.radius,
    required this.canAccept,
    required this.onDrop,
    required this.onHold,
    required this.child,
  });

  final String id;
  final double radius;

  /// Whether the dragged note (by id) may be dropped on this one.
  final bool Function(String dragged) canAccept;
  final ValueChanged<String> onDrop;
  final VoidCallback onHold;
  final Widget child;

  @override
  State<_DragToReorder> createState() => _DragToReorderState();
}

class _DragToReorderState extends State<_DragToReorder> {
  Offset? _start;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<String>(
        onWillAcceptWithDetails: (d) => widget.canAccept(d.data),
        onAcceptWithDetails: (d) => widget.onDrop(d.data),
        builder: (context, candidates, _) => LongPressDraggable<String>(
          data: widget.id,
          onDragStarted: () {
            final box = context.findRenderObject() as RenderBox?;
            _start = box?.localToGlobal(Offset.zero);
          },
          onDragEnd: (details) {
            final start = _start;
            if (!details.wasAccepted &&
                start != null &&
                (details.offset - start).distance < kTouchSlop) {
              widget.onHold();
            }
          },
          feedback: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Opacity(opacity: 0.92, child: widget.child),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              border: candidates.isEmpty
                  ? null
                  : Border.all(color: ff.primary, width: 2),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
