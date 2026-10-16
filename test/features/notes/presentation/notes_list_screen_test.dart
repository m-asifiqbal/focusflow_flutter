/// Screen 07 — notes list: renders the mockup notes in the masonry (light
/// / dark / 360 pt × 1.3 captures), pinned first in stable columns; the
/// grid/list toggle and sort persist in Settings; folder chips, search and
/// "+ New folder" filter; multi-select archives with Undo; locked notes
/// hide their preview; empty states.
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_list_states.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_add_sheet.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:focusflow/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card_parts.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_list_row.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/filmstrip.dart';
import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../notes_fixtures.dart';
import 'notes_list_fixtures.dart';

/// The mockup is a scrolled capture: 390 × 1150 pt.
const Size _mockupSize = Size(390, 1150);

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('ff_notes_list'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<(TestHarness, SeededNotes)> harness(
    WidgetTester tester, {
    bool seed = true,
    bool locked = false,
  }) async {
    // The mockups' status bar and home indicator (padding + viewPadding,
    // which sheets read).
    const inset = FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view
      ..padding = inset
      ..viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final h = (await tester.runAsync(
      () => TestHarness.create(now: kListNow, overrides: notesOverrides(docs)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    final ids = seed
        ? (await tester.runAsync(() => seedNotesList(h, docs, locked: locked)))!
        : <String, String>{};
    return (h, ids);
  }

  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  /// Image.file decodes outside the fake-async zone (bounded so a stuck
  /// decode can't hang the test).
  Future<void> loadImages(WidgetTester tester) async {
    for (final e in find.byType(Image).evaluate()) {
      final image = e.widget as Image;
      await tester.runAsync(
        () => precacheImage(
          image.image,
          e,
        ).timeout(const Duration(seconds: 5), onTimeout: () {}),
      );
    }
    await settle(tester);
  }

  Future<Note?> note(WidgetTester tester, TestHarness h, String id) =>
      tester.runAsync<Note?>(() => h.read(notesRepositoryProvider).getNote(id));

  Offset center(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text));

  testWidgets('renders the mockup notes (light + dark captures)', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.notes, size: _mockupSize);
      await loadImages(tester);
      await captureScreen(tester, '07_notes_list');
    });

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('6 notes · 2 pinned'), findsOneWidget);
    expect(find.text('Last edited'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    for (final chip in ['All', 'Ideas', 'Work', 'Personal', 'Travel']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('IDEAS'), findsOneWidget);
    expect(find.text('TODAY · IDEAS'), findsOneWidget);
    expect(find.text('JUN 10 · WORK'), findsOneWidget);
    expect(find.text('YESTERDAY · PERSONAL'), findsOneWidget);
    expect(find.text('JUN 8 · TRAVEL'), findsOneWidget);
    expect(
      find.textContaining('Avocado oil', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(NoteCover), findsOneWidget);
    expect(find.byType(NotePinMark), findsNWidgets(2));

    // Pinned first, then last edited; note i in column i % 2.
    final mobile = center(tester, 'Mobile App Design Trends 2024');
    final roadmap = center(tester, 'Project FocusFlow Roadmap');
    final shopping = center(tester, 'Shopping List');
    final trip = center(tester, 'Inspiration Trip');
    final routine = center(tester, 'Morning Routine');
    expect(mobile.dx, lessThan(roadmap.dx));
    expect(shopping.dx, mobile.dx);
    expect(trip.dx, roadmap.dx);
    expect(routine.dx, mobile.dx);
    expect(shopping.dy, greaterThan(mobile.dy));

    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.notes, size: _mockupSize, dark: true);
      await loadImages(tester);
      await captureScreen(tester, '07_notes_list_dark');
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await loadAppFonts();
    final (h, _) = await harness(tester, locked: true);
    await pumpApp(
      tester,
      h,
      AppRoutes.notes,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    await captureScreen(tester, '07_notes_list_360_x1.3');
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Show as list'));
    await settle(tester);
    expect(find.byType(NoteListRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked notes show a lock and hide the preview', (tester) async {
    await loadAppFonts();
    final (h, _) = await harness(tester, locked: true);
    await pumpApp(tester, h, AppRoutes.notes, size: _mockupSize);
    expect(find.byType(NoteLockMark), findsOneWidget);
    expect(find.byType(NoteLockedPreview), findsOneWidget);
    expect(find.textContaining('Phase 1'), findsNothing);
  });

  testWidgets('view toggle and sort persist in settings', (tester) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);

    await tester.tap(find.bySemanticsLabel('Show as list'));
    await settle(tester);
    expect(h.read(settingsProvider).notesView, NotesView.list);
    expect(find.byType(NoteListRow), findsWidgets);
    expect(find.byType(NoteCard), findsNothing);

    await tester.tap(find.text('Last edited'));
    await settle(tester);
    await tester.tap(find.text('Title A–Z'));
    await settle(tester);
    expect(h.read(settingsProvider).notesSort, NotesSort.titleAz);
    expect(find.text('Title A–Z'), findsOneWidget);
    // Pinned first, then A–Z: Mobile, Project, Inspiration, Meeting…
    expect(
      center(tester, 'Inspiration Trip').dy,
      lessThan(center(tester, 'Meeting notes — Sprint 12').dy),
    );
  });

  testWidgets('folder chips, search and new folder filter the list', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);

    await tester.tap(find.text('Work'));
    await settle(tester);
    expect(find.byType(NoteCard), findsNWidgets(2));
    expect(find.text('Shopping List'), findsNothing);

    await tester.tap(find.text('All'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'avocado');
    await settle(tester);
    expect(find.byType(NoteCard), findsOneWidget);
    expect(find.text('Shopping List'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await settle(tester);
    expect(find.text('No matching notes'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await settle(tester);
    expect(find.byType(NoteCard), findsWidgets);

    await tester.ensureVisible(find.text('New folder'));
    await settle(tester);
    await tester.tap(find.text('New folder'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Recipes');
    // Let the button enable before tapping it.
    await tester.pump();
    await tester.tap(find.widgetWithText(FFPrimaryButton, 'Create folder'));
    await settle(tester);
    expect(find.text('No notes in Recipes'), findsOneWidget);
  });

  testWidgets('multi-select archives with Undo', (tester) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes, size: _mockupSize);

    await tester.tap(find.text('Select'));
    await settle(tester);
    expect(find.text('Select notes'), findsOneWidget);
    await tester.tap(find.text('Shopping List'));
    await tester.tap(find.text('Inspiration Trip'));
    await settle(tester);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byType(NoteSelectMark), findsWidgets);

    await tester.tap(find.text('Archive').last);
    await settle(tester);
    final shopping = await note(tester, h, ids['Shopping List']!);
    expect(shopping!.isArchived, isTrue);
    expect(find.text('Shopping List'), findsNothing);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await settle(tester);
    final restored = await note(tester, h, ids['Shopping List']!);
    expect(restored!.isArchived, isFalse);
  });

  testWidgets('manual sort: drag onto a card moves it; hold opens actions', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await h.updateSettings((s) => s.copyWith(notesSort: NotesSort.manual));
    await pumpApp(tester, h, AppRoutes.notes, size: _mockupSize);
    expect(find.text('Manual'), findsOneWidget);

    int indexOf(String title) =>
        h.read(notesListProvider).value!.indexWhere((n) => n.title == title);
    const dragged = 'Meeting notes — Sprint 12';
    Future<void> drag(String onto) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(dragged)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(find.text(onto)));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      await gesture.up();
      await settle(tester);
    }

    // Pinned notes stay first: a drop onto a pinned card is refused.
    final before = indexOf(dragged);
    await drag('Mobile App Design Trends 2024');
    expect(indexOf(dragged), before);

    // A drop onto the first unpinned card takes its slot.
    final firstUnpinned = h
        .read(notesListProvider)
        .value!
        .firstWhere((n) => !n.isPinned);
    expect(firstUnpinned.title, isNot(dragged));
    final slot = indexOf(firstUnpinned.title);
    await drag(firstUnpinned.title);
    expect(find.byType(FFActionSheet), findsNothing);
    expect(indexOf(dragged), slot);

    // Long-press released in place → the actions sheet.
    final hold = await tester.startGesture(
      tester.getCenter(find.text('Shopping List')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await hold.up();
    await settle(tester);
    expect(find.byType(FFActionSheet), findsOneWidget);
  });

  testWidgets('tap opens the editor', (tester) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    await tester.tap(find.text('Shopping List'));
    await settle(tester);
    final editor = tester.widget<NoteEditorScreen>(
      find.byType(NoteEditorScreen),
    );
    expect(editor.noteId, ids['Shopping List']);
  });

  testWidgets('opening grows out of the card and closing shrinks back', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    final card = tester.getRect(find.text('Shopping List'));
    await tester.tap(find.text('Shopping List'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    // Mid-flight: a clipped, growing container starts at the card.
    Rect clip() => tester.getRect(
      find
          .ancestor(
            of: find.byType(NoteEditorScreen),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    final opening = clip();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(opening.width, lessThan(screen.width - 1));
    await captureScreen(tester, 'transition_open_midflight');
    await tester.pump(const Duration(milliseconds: 500));
    expect(clip().width, closeTo(screen.width, 1));

    // Back: it must shrink toward the card again, not vanish or slide.
    h.read(routerProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final closing = clip();
    expect(closing.width, lessThan(screen.width - 1));
    await captureScreen(tester, 'transition_close_midflight');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(NoteEditorScreen), findsNothing);
    expect(card.width, greaterThan(0));
  });

  testWidgets('filmstrip: card → editor → back (visual check)', (tester) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    await tester.tap(find.text('Shopping List'));
    await tester.pump();
    await captureFilmstrip(
      tester,
      'film_open',
      frames: 12,
      step: const Duration(milliseconds: 30),
    );
    await tester.pump(const Duration(milliseconds: 600));
    h.read(routerProvider).pop();
    await tester.pump();
    await captureFilmstrip(
      tester,
      'film_close',
      frames: 12,
      step: const Duration(milliseconds: 24),
    );
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('first-run empty state', (tester) async {
    await loadAppFonts();
    final (h, _) = await harness(tester, seed: false);
    await pumpApp(tester, h, AppRoutes.notes);
    expect(find.text('Write your first note'), findsOneWidget);
    expect(find.text('0 notes'), findsOneWidget);
    await captureScreen(tester, '07_notes_list_empty');

    // Screen 29: the tappable hint pre-fills quick capture.
    final hint = find.text('Try: "${NotesEmptyState.hintText}"');
    expect(hint, findsOneWidget);
    await tester.tap(hint);
    await settle(tester);
    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text(NotesEmptyState.hintText), findsWidgets);
  });
}
