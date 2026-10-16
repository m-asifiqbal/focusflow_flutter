/// Lifecycle-aware item actions: the actions sheet of an archived item
/// (Restore + Delete) and a trashed one (Recover + Delete forever) never
/// offers edits / Archive / a second soft delete; restore's Undo keeps
/// the original archive date; the multi-select bar keeps its selection
/// when a confirm is cancelled and toggles Pin ↔ Unpin with Undo.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../features/notes/notes_fixtures.dart';
import '../features/notes/presentation/notes_list_fixtures.dart';
import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('ff_life'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<(TestHarness, SeededNotes)> harness(WidgetTester tester) async {
    final h = (await tester.runAsync(
      () => TestHarness.create(now: kListNow, overrides: notesOverrides(docs)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    final ids = (await tester.runAsync(() => seedNotesList(h, docs)))!;
    return (h, ids);
  }

  Future<void> pumpOpener(WidgetTester tester, TestHarness h, ItemRef ref) =>
      pumpScreen(
        tester,
        h,
        Consumer(
          builder: (context, wref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showItemActions(context, wref, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<T> db<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  testWidgets('archived item: Restore + Delete, Undo keeps archive date', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    final ref = noteRef(ids['Shopping List']!);
    final items = h.read(itemsRepositoryProvider);
    final archivedAt = DateTime(2026, 3, 1, 10);
    await db(tester, () => items.archive([ref], at: archivedAt));
    await pumpOpener(tester, h, ref);

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Share / export (PDF, TXT, MD)'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    for (final row in [
      'Archive',
      'Pin to top',
      'Change colour',
      'Set reminder',
      'Lock with Vault PIN',
      'Delete forever',
    ]) {
      expect(find.text(row), findsNothing, reason: row);
    }

    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect((await db(tester, () => items.get(ref)))!.isActive, isTrue);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect((await db(tester, () => items.get(ref)))!.archivedAt, archivedAt);
  });

  testWidgets('trashed item: Recover + Delete forever (confirm only)', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    final ref = noteRef(ids['Shopping List']!);
    final items = h.read(itemsRepositoryProvider);
    final deletedAt = DateTime(2026, 6, 1, 10);
    await db(tester, () => items.moveToTrash([ref], at: deletedAt));
    await pumpOpener(tester, h, ref);

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Recover'), findsOneWidget);
    expect(find.text('Delete forever'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Pin to top'), findsNothing);

    // Delete forever asks first; Cancel keeps it in the trash untouched.
    await tester.tap(find.text('Delete forever'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    final kept = (await db(tester, () => items.get(ref)))!;
    expect(kept.deletedAt, deletedAt);

    // Recover → Undo keeps the original deletion date (30 days don't restart).
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('Recover'));
    await settle(tester);
    expect((await db(tester, () => items.get(ref)))!.isActive, isTrue);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect((await db(tester, () => items.get(ref)))!.deletedAt, deletedAt);
  });

  group('selection bar', () {
    const scope = 'test';

    Future<void> pumpBar(WidgetTester tester, TestHarness h) => pumpScreen(
      tester,
      h,
      const Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: ItemSelectionBar(
          scope: scope,
          module: ItemType.note,
        ),
      ),
    );

    testWidgets('a cancelled delete keeps the selection', (tester) async {
      await loadAppFonts();
      final (h, ids) = await harness(tester);
      final refs = [
        noteRef(ids['Shopping List']!),
        noteRef(ids['Morning Routine']!),
      ];
      await pumpBar(tester, h);
      h.read(itemSelectionProvider(scope).notifier).selectAll(refs);
      await settle(tester);

      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      final sel = h.read(itemSelectionProvider(scope));
      expect(sel.active, isTrue);
      expect(sel.selected, refs.toSet());
      for (final r in refs) {
        expect(
          (await db(
            tester,
            () => h.read(itemsRepositoryProvider).get(r),
          ))!.isActive,
          isTrue,
        );
      }

      // Confirmed → selection ends.
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(h.read(itemSelectionProvider(scope)).active, isFalse);
    });

    testWidgets('Pin toggles to Unpin when all are pinned, with Undo', (
      tester,
    ) async {
      await loadAppFonts();
      final (h, ids) = await harness(tester);
      final items = h.read(itemsRepositoryProvider);
      // Both mockup-pinned notes.
      final pinned = [
        noteRef(ids['Mobile App Design Trends 2024']!),
        noteRef(ids['Project FocusFlow Roadmap']!),
      ];
      await pumpBar(tester, h);
      h.read(itemSelectionProvider(scope).notifier).selectAll(pinned);
      await settle(tester);
      expect(find.text('Unpin'), findsOneWidget);

      await tester.tap(find.text('Unpin'));
      await settle(tester);
      for (final r in pinned) {
        expect((await db(tester, () => items.get(r)))!.isPinned, isFalse);
      }
      await tester.tap(find.text('UNDO'));
      await settle(tester);
      for (final r in pinned) {
        expect((await db(tester, () => items.get(r)))!.isPinned, isTrue);
      }

      // Mixed selection → Pin pins the unpinned one only.
      final mixed = [pinned.first, noteRef(ids['Shopping List']!)];
      h.read(itemSelectionProvider(scope).notifier).selectAll(mixed);
      await settle(tester);
      expect(find.text('Pin'), findsOneWidget);
      await tester.tap(find.text('Pin'));
      await settle(tester);
      for (final r in mixed) {
        expect((await db(tester, () => items.get(r)))!.isPinned, isTrue);
      }
      await tester.tap(find.text('UNDO'));
      await settle(tester);
      expect((await db(tester, () => items.get(mixed[0])))!.isPinned, isTrue);
      expect((await db(tester, () => items.get(mixed[1])))!.isPinned, isFalse);
    });
  });
}
