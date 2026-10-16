/// Library collections: Tags & Folders (`/library/tags`), Favourites and
/// Pinned (`/library/favourites`, `/library/pinned`) — live rows, empty
/// states, navigation into a note folder, captures (light / dark /
/// 360 pt × 1.3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../library_fixtures.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<TestHarness> harness(WidgetTester tester) async {
    const inset = FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view
      ..padding = inset
      ..viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final h = (await tester.runAsync(
      () => TestHarness.create(now: kLibraryNow, overrides: libraryOverrides()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  testWidgets('Tags & Folders lists tags and folders with live counts', (
    tester,
  ) async {
    final h = await harness(tester);
    await tester.runAsync(() => seedLibrary(h));
    await pumpApp(tester, h, AppRoutes.tags);
    await captureScreen(tester, 'library_tags_folders');

    expect(find.text('Tags & Folders'), findsOneWidget);
    expect(find.text('1 TAG · 1 FOLDER'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('NOTE FOLDERS'), findsOneWidget);
    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.runAsync(
      () => h.read(foldersRepositoryProvider).create(ItemType.task, 'Errands'),
    );
    await settle(tester);
    expect(find.text('TASK LISTS'), findsOneWidget);
    expect(find.text('Errands'), findsOneWidget);
    expect(find.text('1 TAG · 2 FOLDERS'), findsOneWidget);

    await tester.tap(find.text('Ideas'));
    await settle(tester);
    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Product launch plan'), findsWidgets);
  });

  testWidgets('Tags & Folders: dark + 360 pt × 1.3 without overflow', (
    tester,
  ) async {
    final h = await harness(tester);
    await tester.runAsync(() => seedLibrary(h));
    await pumpApp(tester, h, AppRoutes.tags, dark: true);
    await captureScreen(tester, 'library_tags_folders_dark');
    expect(tester.takeException(), isNull);
    await pumpApp(
      tester,
      h,
      AppRoutes.tags,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Tags & Folders and Pinned show their empty states', (
    tester,
  ) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.tags);
    expect(find.text('No tags or folders yet'), findsOneWidget);

    await pumpApp(tester, h, AppRoutes.pinned);
    expect(find.text('Nothing pinned yet'), findsOneWidget);
  });

  testWidgets('Favourites is live: un-favouriting empties the list', (
    tester,
  ) async {
    final h = await harness(tester);
    final seed = (await tester.runAsync(() => seedLibrary(h)))!;
    await pumpApp(tester, h, AppRoutes.favourites);
    await captureScreen(tester, 'library_favourites');
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('Product launch plan'), findsOneWidget);

    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).setFavorite([
        ItemRef(ItemType.note, seed.pinnedNote),
      ], false),
    );
    await settle(tester);
    expect(find.text('Product launch plan'), findsNothing);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('a deleted tag shows "Tag deleted" on its list', (tester) async {
    final h = await harness(tester);
    final seed = (await tester.runAsync(() => seedLibrary(h)))!;
    await pumpApp(tester, h, AppRoutes.tag(seed.workTag));
    expect(find.text('Send the invoice'), findsOneWidget);

    await tester.runAsync(
      () => h.read(tagsRepositoryProvider).delete(seed.workTag),
    );
    await settle(tester);
    expect(find.text('Tag deleted'), findsOneWidget);
  });
}
