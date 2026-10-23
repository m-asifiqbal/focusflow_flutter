/// Screen 08 — the editor panel's newer tools: numbered lists, text colours (stored as Quill `color`, drawn per
/// brightness), the hide / show chevron (kept for the session), the longer
/// scrolling note-colour row, and edits saved from a lazy draft.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
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

  Future<TestHarness> harness(WidgetTester tester) async {
    const inset = FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view
      ..padding = inset
      ..viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final h = (await tester.runAsync(
      () => TestHarness.create(now: kNotesNow, overrides: notesOverrides(docs)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  Future<Note> note(WidgetTester tester, TestHarness h, String id) async =>
      (await tester.runAsync(
        () => h.read(notesRepositoryProvider).getNote(id),
      ))!;

  Future<void> autosave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
  }

  QuillController quill(WidgetTester tester) =>
      tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

  /// Ops of the saved body.
  Future<List<Map<String, dynamic>>> ops(
    WidgetTester tester,
    TestHarness h,
    String id,
  ) async => (jsonDecode((await note(tester, h, id)).contentDelta) as List)
      .cast<Map<String, dynamic>>();

  testWidgets('Numbered list button numbers the cursor line', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    final q = quill(tester);
    q.updateSelection(
      const TextSelection.collapsed(offset: 3),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Numbered list'));
    await autosave(tester);

    expect(q.getSelectionStyle().attributes[Attribute.list.key], Attribute.ol);
    final saved = await ops(tester, h, id);
    expect(
      saved.any((o) => (o['attributes'] as Map?)?['list'] == 'ordered'),
      isTrue,
    );
    // The button shows as on for that line.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Numbered list')),
      isSemantics(isToggled: true),
    );
  });

  testWidgets('Text colour colours the selection; Default removes it', (
    tester,
  ) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    final q = quill(tester);
    q.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 13),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Text colour'));
    await settle(tester);
    expect(find.bySemanticsLabel('Mint note colour'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Red text colour'));
    await autosave(tester);

    var first = (await ops(tester, h, id)).first;
    expect(first['insert'], 'The landscape');
    expect((first['attributes'] as Map)['color'], '#DC2626');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red text colour')),
      isSemantics(isSelected: true),
    );

    await tester.tap(find.bySemanticsLabel('Default text colour'));
    await autosave(tester);
    first = (await ops(tester, h, id)).first;
    expect(first['attributes'], isNull);

    // Back to the note colours.
    await tester.tap(find.bySemanticsLabel('Text colour'));
    await settle(tester);
    expect(find.bySemanticsLabel('Mint note colour'), findsOneWidget);
  });

  test('text colours are stored light and drawn lighter in dark mode', () {
    final light = NoteTextColors.quillPalette(Brightness.light);
    final dark = NoteTextColors.quillPalette(Brightness.dark);
    expect(light.keys, hasLength(NoteTextColors.swatches.length));
    expect(light['#DC2626'], const Color(0xFFDC2626));
    expect(
      dark['#DC2626']!.computeLuminance(),
      greaterThan(light['#DC2626']!.computeLuminance()),
    );
    // The body ink is (near) black on light cards.
    expect(
      NoteTextColors.body(Brightness.light).computeLuminance(),
      lessThan(0.02),
    );
  });

  testWidgets('the chevron hides and shows the panel for the session', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    await tester.tap(find.bySemanticsLabel('Hide formatting panel'));
    await settle(tester);
    expect(find.bySemanticsLabel('Bold'), findsNothing);
    expect(find.bySemanticsLabel('Mint note colour'), findsNothing);
    expect(find.bySemanticsLabel('Undo'), findsOneWidget);
    expect(h.read(noteToolbarCollapsedProvider), isTrue);
    await captureScreen(tester, '08_note_editor_panel_hidden');

    await tester.tap(find.bySemanticsLabel('Show formatting panel'));
    await settle(tester);
    expect(find.bySemanticsLabel('Bold'), findsOneWidget);
    expect(h.read(noteToolbarCollapsedProvider), isFalse);
  });

  testWidgets('the colour row scrolls to the newer colours', (tester) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    final coral = find.bySemanticsLabel('Coral note colour');
    await tester.ensureVisible(coral);
    await settle(tester);
    await tester.tap(coral);
    await settle(tester);
    expect((await note(tester, h, id)).colorHex, 'FEE2E2');
    expect(NoteColors.hexes, hasLength(10));
  });

  testWidgets('text colour mode fits at 360 pt and text scale 1.3', (
    tester,
  ) async {
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
    await tester.tap(find.bySemanticsLabel('Text colour'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '08_note_editor_text_colours_360');
  });

  testWidgets('typing saves once after the pause, from a lazy draft', (
    tester,
  ) async {
    final h = await harness(tester);
    final id = (await tester.runAsync(() => seedMockupNote(h)))!;
    await pumpApp(tester, h, AppRoutes.note(id));

    final q = quill(tester);
    for (final ch in 'Hey '.split('')) {
      final at = q.selection.baseOffset < 0 ? 0 : q.selection.baseOffset;
      q.replaceText(at, 0, ch, TextSelection.collapsed(offset: at + 1));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('SAVING…'), findsOneWidget);
    expect((await note(tester, h, id)).plainText, startsWith('The landscape'));
    await autosave(tester);
    expect((await note(tester, h, id)).plainText, startsWith('Hey The'));
    expect(find.text('AUTO-SAVED'), findsOneWidget);
  });
}
