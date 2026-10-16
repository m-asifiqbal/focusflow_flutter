/// Screen 09 — the shared item actions sheet: long-press on a note card
/// opens it with the mockup header and rows (light + dark captures), Pin
/// toggles its label, Archive shows Undo; the multi-select variant reads
/// "3 items selected" and works on every selected item.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../features/notes/notes_fixtures.dart';
import '../features/notes/presentation/notes_list_fixtures.dart';
import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

const _rows = [
  'Pin to top',
  'Add to favourites',
  'Duplicate',
  'Change colour',
  'Edit tags / move to folder',
  'Set reminder',
  'Share / export (PDF, TXT, MD)',
  'Lock with Vault PIN',
];

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('ff_sheet'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<(TestHarness, SeededNotes)> harness(WidgetTester tester) async {
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
    final ids = (await tester.runAsync(() async {
      final ids = await seedNotesList(h, docs);
      // The mockup offers "Pin to top" for this note.
      await h
          .read(notesRepositoryProvider)
          .setPinned(ids['Mobile App Design Trends 2024']!, false);
      h.clock.set(kListNow);
      return ids;
    }))!;
    return (h, ids);
  }

  Future<void> openSheet(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await settle(tester);
  }

  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('single item: header, rows, captures', (tester) async {
    await loadAppFonts();
    final (h, _) = await harness(tester);
    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.notes);
      await openSheet(tester, 'Mobile App Design Trends 2024');
      await captureScreen(tester, '09_item_actions_sheet');
    });

    expect(find.byType(FFActionSheet), findsOneWidget);
    expect(find.text('Note · Ideas · Edited today'), findsOneWidget);
    for (final row in _rows) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Archive'));
    await settle(tester);

    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.notes, dark: true);
      await openSheet(tester, 'Project FocusFlow Roadmap');
      await captureScreen(tester, '09_item_actions_sheet_dark');
    });
    expect(find.text('Unpin'), findsOneWidget);
  });

  testWidgets('Pin toggles; Archive shows Undo', (tester) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    final id = ids['Mobile App Design Trends 2024']!;

    await openSheet(tester, 'Mobile App Design Trends 2024');
    await tester.tap(find.text('Pin to top'));
    await settle(tester);
    final pinned = await tester.runAsync(
      () => h.read(notesRepositoryProvider).getNote(id),
    );
    expect(pinned!.isPinned, isTrue);

    await openSheet(tester, 'Mobile App Design Trends 2024');
    expect(find.text('Unpin'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await settle(tester);
    expect(find.text('UNDO'), findsOneWidget);
    final archived = await tester.runAsync(
      () => h.read(notesRepositoryProvider).getNote(id),
    );
    expect(archived!.isArchived, isTrue);
  });

  testWidgets('multi-select variant: "3 items selected"', (tester) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    final taskId = (await tester.runAsync(
      () => h
          .read(tasksRepositoryProvider)
          .save(
            TaskItem(
              id: '',
              title: 'Renew passport',
              createdAt: kListNow,
              updatedAt: kListNow,
            ),
          ),
    ))!;
    final refs = [
      noteRef(ids['Shopping List']!),
      noteRef(ids['Inspiration Trip']!),
      ItemRef(ItemType.task, taskId),
    ];
    var done = 0;
    await pumpScreen(
      tester,
      h,
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showSelectionActions(
                context,
                ref,
                refs,
                onDone: () => done++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await captureScreen(tester, '09_item_actions_sheet_multi');

    expect(find.text('3 items selected'), findsOneWidget);
    expect(find.text('Pin to top'), findsOneWidget);
    expect(find.text('Add to favourites'), findsOneWidget);
    expect(find.text('Add tags'), findsOneWidget);
    // Mixed modules can't share a folder.
    expect(find.text('Move to folder'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add to favourites'));
    await settle(tester);
    expect(done, 1);
    final items = h.read(itemsRepositoryProvider);
    for (final r in refs) {
      final item = await tester.runAsync(() => items.get(r));
      expect(item!.isFavorite, isTrue, reason: '$r');
    }
  });

  testWidgets('notes-only selection offers Move to folder', (tester) async {
    await loadAppFonts();
    final (h, ids) = await harness(tester);
    await pumpScreen(
      tester,
      h,
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => showSelectionActions(context, ref, [
              for (final id in ids.values.take(3)) noteRef(id),
            ]),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('3 notes selected'), findsOneWidget);
    expect(find.text('Move to folder'), findsOneWidget);
  });
}
