/// Screen 08 — note editor: renders the mockup note (light / dark / small
/// + large text), auto-saves edits, discards empty new notes, and wires
/// the header, colour row, toolbar, image and dictation buttons.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../notes_fixtures.dart';

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('ff_docs'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<TestHarness> harness(
    WidgetTester tester, {
    FakeVoiceDictation? voice,
    FakeImagePicker? picker,
  }) async {
    // Status bar + home indicator like the other harness captures, so the
    // header sits where design/08 has it.
    const inset = FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view
      ..padding = inset
      ..viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final h = (await tester.runAsync(
      () => TestHarness.create(
        now: kNotesNow,
        overrides: notesOverrides(docs, voice: voice, picker: picker),
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  Future<Note?> note(WidgetTester tester, TestHarness h, String id) => tester
      .runAsync(() => h.read(notesRepositoryProvider).getNote(id))
      .then((n) => n);

  /// Runs [body] with real (blurred) shadows, as on a device, so the
  /// captures compare fairly with the mockups.
  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  /// Lets the 600 ms debounce fire and the write land.
  Future<void> autosave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
  }

  testWidgets('renders the mockup note (light)', (tester) async {
    await loadAppFonts();
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.note(id));
      await captureScreen(tester, '08_note_editor');
    });

    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('AUTO-SAVED'), findsOneWidget);
    expect(find.text('IDEAS'), findsOneWidget);
    expect(find.text('#DESIGN'), findsOneWidget);
    expect(find.text('#UX'), findsOneWidget);
    expect(find.text('Mobile App Design Trends 2024'), findsOneWidget);
    expect(
      find.textContaining(
        'Edited today, 9:12 AM · 214 words',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Reminder Fri'), findsOneWidget);
    expect(find.bySemanticsLabel('Unpin note'), findsOneWidget);
    expect(find.bySemanticsLabel('More note actions'), findsOneWidget);
    expect(find.bySemanticsLabel('Checklist'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    await loadAppFonts();
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.note(id), dark: true);
      await captureScreen(tester, '08_note_editor_dark');
    });
    expect(find.text('Mobile App Design Trends 2024'), findsOneWidget);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await loadAppFonts();
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(
      tester,
      h,
      AppRoutes.note(id),
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '08_note_editor_360_x1.3');
  });

  testWidgets('no overflow at text scale 0.85', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id), textScale: 0.85);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected text stays visible; cursor handle slides the caret', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    final quill = editor.controller;

    // 1. The selection tint is translucent (Quill paints it over the text).
    final selection = Theme.of(
      tester.element(find.byType(QuillEditor)),
    ).textSelectionTheme.selectionColor!;
    expect(selection.a, lessThan(0.5));

    // 2. Body text is a notch larger than the old 15.5.
    expect(NoteBodyMetrics.fontSize, 17);

    // 3. Tapping the body focuses it and shows the caret handle.
    await tester.tap(find.textContaining('landscape', findRichText: true));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final handle = find.byKey(const ValueKey('note-caret-handle'));
    expect(handle, findsOneWidget);
    final before = quill.selection.baseOffset;
    expect(quill.selection.isCollapsed, isTrue);

    // 4. Dragging it moves the caret (here: further down the note).
    await tester.drag(handle, const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(quill.selection.isCollapsed, isTrue);
    expect(quill.selection.baseOffset, isNot(before));

    // 5. Typing hides it.
    quill.replaceText(
      quill.selection.baseOffset,
      0,
      'x',
      TextSelection.collapsed(offset: quill.selection.baseOffset + 1),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(handle, findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('editing the title auto-saves', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.enterText(
      find.text('Mobile App Design Trends 2024'),
      'Design trends',
    );
    await tester.pump();
    expect(find.text('SAVING…'), findsOneWidget);
    await autosave(tester);
    expect(find.text('AUTO-SAVED'), findsOneWidget);
    expect((await note(tester, h, id))!.title, 'Design trends');
  });

  testWidgets('colour row and pin write through', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('Mint note colour'));
    await tester.tap(find.bySemanticsLabel('Unpin note'));
    await settle(tester);
    final n = (await note(tester, h, id))!;
    expect(n.colorHex, 'D1FAE5');
    expect(n.isPinned, isFalse);
    expect(find.bySemanticsLabel('Pin note'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('White note colour'));
    await settle(tester);
    expect((await note(tester, h, id))!.colorHex, isNull);
  });

  testWidgets('checklist button formats the line; Undo reverts', (
    tester,
  ) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('Checklist'));
    await autosave(tester);
    var n = (await note(tester, h, id))!;
    expect(n.checklist.first.text, startsWith('The landscape'));

    await tester.tap(find.bySemanticsLabel('Undo'));
    await autosave(tester);
    n = (await note(tester, h, id))!;
    expect(n.checklist.first.text, 'Audit current spacing scale');
  });

  testWidgets('dictation inserts the transcript at the cursor', (tester) async {
    final voice = FakeVoiceDictation(words: 'hello from voice');
    final h = await harness(tester, voice: voice);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('Dictate'));
    await autosave(tester);
    final n = (await note(tester, h, id))!;
    expect(n.plainText, startsWith('hello from voiceThe landscape'));
  });

  testWidgets('app pause saves pending edits before the debounce', (
    tester,
  ) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    await tester.enterText(
      find.text('Mobile App Design Trends 2024'),
      'Paused title',
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // No fake time passes: only the flush can have written.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect((await note(tester, h, id))!.title, 'Paused title');
  });

  testWidgets('leaving while dictating waits for stop and keeps the words', (
    tester,
  ) async {
    final voice = _SlowStopVoice();
    final h = await harness(tester, voice: voice);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.notes);
    h.read(routerProvider).push(AppRoutes.note(id));
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Dictate'));
    await settle(tester);
    voice.partial('hello');
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Back'));
    await settle(tester);
    expect(voice.stopping, isTrue);
    // The recogniser's final result arrives after the editor is gone.
    voice.finish('hello there world');
    await settle(tester);
    expect(tester.takeException(), isNull);
    final n = (await note(tester, h, id))!;
    expect(n.plainText, startsWith('hello there worldThe landscape'));
  });

  testWidgets('image button copies the photo into attachments', (tester) async {
    final source = File('${docs.path}/picked.png')
      ..writeAsBytesSync(List.filled(64, 1));
    final picker = FakeImagePicker(source.path);
    final h = await harness(tester, picker: picker);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('Add image'));
    await settle(tester);
    await tester.tap(find.text('Choose from library'));
    await settle(tester);
    await autosave(tester);
    final n = (await note(tester, h, id))!;
    expect(n.coverImagePath, startsWith('attachments/'));
    expect(File('${docs.path}/${n.coverImagePath}').existsSync(), isTrue);
    expect(n.contentDelta, contains('"image"'));
  });

  testWidgets('an empty new note is discarded on back', (tester) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    h.read(routerProvider).push(AppRoutes.newNote);
    await settle(tester);
    expect(find.text('Title'), findsOneWidget);
    var all = await tester.runAsync(
      () =>
          h.read(notesRepositoryProvider).watchNotes(const NotesQuery()).first,
    );
    expect(all, hasLength(1));

    await tester.tap(find.bySemanticsLabel('Back'));
    await settle(tester);
    all = await tester.runAsync(
      () =>
          h.read(notesRepositoryProvider).watchNotes(const NotesQuery()).first,
    );
    expect(all, isEmpty);
  });

  testWidgets('a new note with text is kept on back', (tester) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    h.read(routerProvider).push(AppRoutes.newNoteWith(text: 'Buy milk'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await settle(tester);
    final all = (await tester.runAsync(
      () =>
          h.read(notesRepositoryProvider).watchNotes(const NotesQuery()).first,
    ))!;
    expect(all.single.plainText, 'Buy milk');
  });

  testWidgets('locked notes ask for the vault first', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h, locked: true)))!;
    await pumpApp(tester, h, AppRoutes.note(id));
    expect(find.text('This note is locked'), findsOneWidget);
    expect(find.text('Mobile App Design Trends 2024'), findsNothing);
  });

  testWidgets('archived notes open read-only', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(
      () => seedMockupNote(h, archived: true),
    ))!;
    await pumpApp(tester, h, AppRoutes.note(id));
    expect(find.text('Archived — restore it to edit.'), findsOneWidget);
    expect(find.bySemanticsLabel('Checklist'), findsNothing);
    expect(find.text('AUTO-SAVED'), findsNothing);
  });

  testWidgets('tags row: add, remove with undo, move folder', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('Add tag'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'research');
    await tester.pump();
    await tester.tap(find.text('Add tags').last);
    await settle(tester);
    expect(find.text('#RESEARCH'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Tag ux'));
    await settle(tester);
    expect(find.text('#UX'), findsNothing);
    expect(find.text('#ux removed'), findsOneWidget);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect(find.text('#UX'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Folder Ideas'));
    await settle(tester);
    await tester.tap(find.text('No folder'));
    await settle(tester);
    final n = (await note(tester, h, id))!;
    expect(n.folderId, isNull);
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('More opens the item actions with the note rows', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('More note actions'));
    await settle(tester);
    expect(find.text('Share / export (PDF, TXT, MD)'), findsOneWidget);
    expect(find.text('Lock with Vault PIN'), findsOneWidget);
    await tester.tap(find.text('Word count'));
    await settle(tester);
    expect(find.text('Reading time'), findsOneWidget);
  });

  testWidgets('More on an archived note offers only read-safe actions', (
    tester,
  ) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(
      () => seedMockupNote(h, archived: true),
    ))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('More note actions'));
    await settle(tester);
    Finder inSheet(String text) => find.descendant(
      of: find.byType(FFActionSheet),
      matching: find.text(text),
    );
    for (final row in [
      'Restore',
      'Duplicate',
      'Share / export (PDF, TXT, MD)',
      'Word count',
      'Delete',
    ]) {
      expect(inSheet(row), findsOneWidget, reason: row);
    }
    for (final row in [
      'Lock with Vault PIN',
      'Unpin',
      'Pin to top',
      'Change colour',
      'Set reminder',
      'Archive',
    ]) {
      expect(inSheet(row), findsNothing, reason: row);
    }
  });

  testWidgets('archiving from More closes the editor', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.notes);
    h.read(routerProvider).push(AppRoutes.note(id));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('More note actions'));
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);
    expect(find.bySemanticsLabel('More note actions'), findsNothing);
    expect((await note(tester, h, id))!.isArchived, isTrue);
  });
}

/// Dictation whose stop() only completes when [finish] delivers the final
/// result — like speech_to_text, whose last result trails the stop call.
class _SlowStopVoice extends FakeVoiceDictation {
  void Function(String)? _onText;
  void Function(String)? _onDone;
  final _stopped = Completer<void>();
  bool stopping = false;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(String text) onDone,
  }) async {
    _onText = onText;
    _onDone = onDone;
    return true;
  }

  void partial(String words) => _onText?.call(words);

  void finish(String words) {
    _onDone?.call(words);
    _stopped.complete();
  }

  @override
  Future<void> stop() {
    stopping = true;
    return _stopped.future;
  }
}
