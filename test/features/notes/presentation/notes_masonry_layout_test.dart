/// Masonry placement: shorter column first, alternate when level; the
/// first-run hint text parses as a note in quick capture.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_list_states.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_masonry.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_masonry_layout.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/domain/services/quick_capture_parser.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

void main() {
  group('MasonryLayout.assign', () {
    test('equal cards zig-zag', () {
      expect(MasonryLayout.assign([100, 100, 100, 100]), [0, 1, 0, 1]);
    });

    test('a tall card makes the next ones fill the shorter column', () {
      // Tall card left, then three short ones all go right until level.
      expect(MasonryLayout.assign([600, 150, 150, 150, 150]), [0, 1, 1, 1, 1]);
      expect(MasonryLayout.assign([150, 600, 150, 150, 150]), [0, 1, 0, 0, 0]);
    });
  });

  test('estimates grow with content (cover, checklist, long text)', () {
    final base = Note(
      id: 'n',
      title: 'Short',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final h = estimateNoteCardHeight(base);
    expect(
      estimateNoteCardHeight(base.copyWith(coverImagePath: 'a.png')),
      greaterThan(h),
    );
    expect(
      estimateNoteCardHeight(base.copyWith(plainText: 'word ' * 40)),
      greaterThan(h),
    );
  });

  testWidgets('cards keep their column while content updates', (tester) async {
    final h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 12, 9)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    Note n(String id, String text) => Note(
      id: id,
      title: id,
      plainText: text,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    var notes = [n('A', ''), n('B', ''), n('C', ''), n('D', '')];
    late StateSetter setNotes;
    await pumpScreen(
      tester,
      h,
      StatefulBuilder(
        builder: (context, set) {
          setNotes = set;
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                NotesSliver(notes: notes, grid: true, now: DateTime(2026)),
              ],
            ),
          );
        },
      ),
    );
    Map<String, double> xs() => {
      for (final id in ['A', 'B', 'C', 'D'])
        id: tester.getTopLeft(find.text(id)).dx,
    };
    final before = xs();
    expect(before['A'], lessThan(before['B']!));

    // A grows a lot: a fresh placement would move C/D, the cache doesn't.
    setNotes(() => notes = [n('A', 'word ' * 60), ...notes.skip(1)]);
    await tester.pump();
    expect(xs(), before);
  });

  test('the empty-state hint captures a note', () {
    final c = const QuickCaptureParser().parse(
      NotesEmptyState.hintText,
      DateTime(2026, 6, 12, 9),
    );
    expect(c.kind, QuickCaptureKind.note);
  });
}
