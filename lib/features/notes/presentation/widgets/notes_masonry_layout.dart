/// ============================================================
/// NOTES MASONRY LAYOUT — which column each note card goes to (screen 07)
/// ============================================================
///
/// What: a greedy "shorter column" placement over *estimated* card heights
/// ([estimateNoteCardHeight]), so a tall card (cover, long preview) doesn't
/// leave one column far longer than the other. When both columns are
/// within [MasonryLayout.tolerance] the cards simply alternate, which keeps
/// the reading order of near-equal cards zig-zag (and matches the mockup).
/// Why estimates: real heights are only known after layout, and lazy slivers
/// need the split up front. The estimate mirrors NoteCard's parts.
/// Stability: NotesSliver caches the result per *ordered id list*, so
/// content edits never move a card between columns — only an insert,
/// delete or reorder re-runs the placement.
/// ============================================================
library;

import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/notes_format.dart';

abstract final class MasonryLayout {
  /// Height difference (pt) below which columns count as level.
  static const double tolerance = 48;

  /// Column (0 = start, 1 = end) of each of [heights], in order.
  static List<int> assign(List<double> heights) {
    final columns = <int>[];
    final totals = [0.0, 0.0];
    var previous = 1;
    for (final h in heights) {
      final diff = totals[0] - totals[1];
      final column = diff.abs() <= tolerance
          ? 1 - previous
          : (diff < 0 ? 0 : 1);
      columns.add(column);
      totals[column] += h;
      previous = column;
    }
    return columns;
  }
}

/// Rough height (pt) of [note]'s card in a ~160 pt wide column.
double estimateNoteCardHeight(Note note) {
  int lines(int chars, int perLine, int max) =>
      chars == 0 ? 0 : ((chars / perLine).ceil()).clamp(1, max);

  final locked = note.isLocked;
  var h = 64.0; // paddings + footer + gap
  if (note.tags.isNotEmpty || note.isPinned || locked) h += 28;
  h += lines(note.displayTitle.length, 12, 4) * 21;
  final preview = NotesFormat.cardPreview(note);
  if (preview.isNotEmpty) h += 8 + lines(preview.length, 24, 6) * 17;
  if (!locked) {
    if (note.coverImagePath != null) h += 108;
    final checks = note.checklist.length.clamp(0, 4);
    if (checks > 0) h += 4 + checks * 26;
  } else {
    h += 40;
  }
  return h;
}
