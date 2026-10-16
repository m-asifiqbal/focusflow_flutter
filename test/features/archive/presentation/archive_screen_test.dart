/// Archive (23) and Recently Deleted (24): mockup captures (light / dark /
/// 360 pt × 1.3), live rows from the items kernel, chips + search, restore
/// with Undo, bulk delete through the confirm dialog (28), delete forever,
/// empty trash and the empty states.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_rows.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../archive_fixtures.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<TestHarness> harness(
    WidgetTester tester, {
    bool mockup = false,
  }) async {
    const inset = FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view
      ..padding = inset
      ..viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final h = (await tester.runAsync(
      () => TestHarness.create(
        now: kArchiveNow,
        overrides: archiveOverrides(mockup: mockup),
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FFNavAction, label));
    await settle(tester);
  }

  /// Lets the 5 s Undo snackbar leave so it doesn't cover the bottom bar.
  Future<void> waitOutSnack(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
  }

  testWidgets('Archive matches design/23 (light, dark, 360 × 1.3)', (
    tester,
  ) async {
    final h = await harness(tester, mockup: true);
    await pumpApp(tester, h, AppRoutes.archive);
    await captureScreen(tester, '23_archive');

    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Search 7 archived items…'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('Note · archived Jun 2'), findsOneWidget);
    expect(find.text('Task · completed · archived May 28'), findsOneWidget);
    expect(find.text('Habit · 34-day streak saved'), findsOneWidget);
    expect(find.text('Restore all'), findsOneWidget);
    expect(find.bySemanticsLabel('Restore Passport renewal'), findsOneWidget);

    await pumpApp(tester, h, AppRoutes.archive, dark: true);
    await captureScreen(tester, '23_archive_dark');
    expect(tester.takeException(), isNull);

    await pumpApp(
      tester,
      h,
      AppRoutes.archive,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '23_archive_360_x1.3');
  });

  testWidgets('Recently Deleted matches design/24 (2 selected)', (
    tester,
  ) async {
    final h = await harness(tester, mockup: true);
    await pumpApp(tester, h, AppRoutes.trash);
    expect(find.text('5 ITEMS'), findsOneWidget);
    expect(find.text('Empty trash'), findsOneWidget);
    expect(find.text('29 days'), findsOneWidget);
    expect(find.text('28 days'), findsOneWidget);
    expect(find.text('20 days'), findsOneWidget);
    expect(find.text('16 days'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('Note · deleted today'), findsOneWidget);
    expect(find.text('Task · deleted yesterday'), findsOneWidget);

    await tapText(tester, 'Random thoughts');
    await tapText(tester, 'Buy printer ink');
    expect(find.text('2 SELECTED · 5 ITEMS'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Recover (2)'), findsOneWidget);
    expect(find.text('Delete (2)'), findsOneWidget);
    await captureScreen(tester, '24_trash');

    await pumpApp(tester, h, AppRoutes.trash, dark: true);
    await captureScreen(tester, '24_trash_dark');
    expect(tester.takeException(), isNull);

    await pumpApp(
      tester,
      h,
      AppRoutes.trash,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '24_trash_360_x1.3');
  });

  testWidgets('Archive is live: chips, search, restore + Undo', (tester) async {
    final h = await harness(tester);
    await tester.runAsync(() => seedArchive(h));
    await pumpApp(tester, h, AppRoutes.archive);

    expect(find.text('Conference notes'), findsOneWidget);
    expect(find.text('Q1 OKR review'), findsOneWidget);
    expect(find.text('Random thoughts'), findsNothing);

    await tapText(tester, 'Tasks');
    expect(find.text('Conference notes'), findsNothing);
    expect(find.text('Q1 OKR review'), findsOneWidget);
    await tapText(tester, 'All');

    await tester.enterText(find.byType(EditableText), 'confer');
    await settle(tester);
    expect(find.text('Q1 OKR review'), findsNothing);
    expect(find.text('Conference notes'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'zzz');
    await settle(tester);
    expect(find.text('No matches'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '');
    await settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is RestoreButton && w.semanticLabel == 'Restore Conference notes',
      ),
    );
    await settle(tester);
    expect(find.text('Conference notes'), findsNothing);
    expect(find.text('"Conference notes" restored'), findsOneWidget);
    final active = await tester.runAsync(
      () => h.read(itemsRepositoryProvider).watchArchived().first,
    );
    expect(active!.map((s) => s.displayTitle), ['Q1 OKR review']);

    await tapText(tester, 'UNDO');
    expect(find.text('Conference notes'), findsOneWidget);
  });

  testWidgets('Archive select → All → Delete moves items to the trash', (
    tester,
  ) async {
    final h = await harness(tester);
    await tester.runAsync(() => seedArchive(h));
    await pumpApp(tester, h, AppRoutes.archive);

    await tapNav(tester, 'Select');
    expect(find.text('Restore (0)'), findsOneWidget);
    await tapNav(tester, 'All');
    expect(find.text('None'), findsOneWidget);
    await tapText(tester, 'Delete (2)');
    expect(find.text('Delete 2 items?'), findsOneWidget);
    expect(find.text('Archive instead'), findsNothing);
    await tapText(tester, 'Delete');

    expect(find.text('Nothing archived yet'), findsOneWidget);
    final trash = await tester.runAsync(
      () => h.read(itemsRepositoryProvider).watchTrash().first,
    );
    expect(trash!.length, 3);
  });

  testWidgets('Trash: recover, delete forever, empty trash, empty state', (
    tester,
  ) async {
    final h = await harness(tester);
    final seed = (await tester.runAsync(() => seedArchive(h)))!;
    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).moveToTrash([
        ItemRef(ItemType.task, seed.task),
      ]),
    );
    await pumpApp(tester, h, AppRoutes.trash);
    expect(find.text('2 ITEMS'), findsOneWidget);

    // Swipe-free bulk path: select one, recover it.
    await tapText(tester, 'Random thoughts');
    await tapText(tester, 'Recover (1)');
    expect(find.text('Random thoughts'), findsNothing);
    expect(find.text('"Random thoughts" restored'), findsOneWidget);
    await waitOutSnack(tester);

    // Delete forever asks first (no Undo).
    await tapText(tester, 'Q1 OKR review');
    await tapText(tester, 'Delete (1)');
    expect(find.text('Delete forever?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(find.text('Q1 OKR review'), findsOneWidget);

    await tapNav(tester, 'Cancel');
    await tapText(tester, 'Empty trash');
    expect(find.text('Delete forever?'), findsOneWidget);
    await tapText(tester, 'Delete forever');
    expect(find.text('Nothing in Recently Deleted'), findsOneWidget);
    final task = await tester.runAsync(
      () => h
          .read(itemsRepositoryProvider)
          .get(ItemRef(ItemType.task, seed.task)),
    );
    expect(task, isNull);
    await captureScreen(tester, '24_trash_empty');
  });
}
