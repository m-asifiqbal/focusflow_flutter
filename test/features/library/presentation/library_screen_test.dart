/// Screen 05 — Library hub: mockup captures (light / dark / 360 pt × 1.3),
/// live counts from the real repositories, the vault card's Locked /
/// Unlocked state, Show counts + hidden spaces, navigation to the
/// collections and tag long-press actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';
import 'package:focusflow/features/library/presentation/screens/library_collection_screen.dart';
import 'package:focusflow/features/library/presentation/widgets/library_module_card.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../library_fixtures.dart';

/// design/05 is a scrolled capture: 1170 × 3813 px = 390 × 1271 pt.
const Size _mockupSize = Size(390, 1271);

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
        now: kLibraryNow,
        overrides: libraryOverrides(mockup: mockup),
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('matches design/05 (light)', (tester) async {
    final h = await harness(tester, mockup: true);
    await withShadows(() async {
      await pumpApp(tester, h, AppRoutes.library, size: _mockupSize);
      await captureScreen(tester, '05_library');
    });
    expect(find.text('Library'), findsWidgets);
    expect(find.text('113 items across 6 spaces'), findsOneWidget);
    expect(find.text('3 pinned'), findsOneWidget);
    expect(find.text('Edited 2h ago'), findsOneWidget);
    expect(find.text('7 due today'), findsOneWidget);
    expect(find.text('2 overdue'), findsOneWidget);
    expect(find.text('3 today'), findsOneWidget);
    expect(find.text('Next 10:00 AM'), findsOneWidget);
    expect(find.text('2/4 done today'), findsOneWidget);
    expect(find.text('Best streak 45d'), findsOneWidget);
    expect(find.text('2 weak'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.lock), findsOneWidget);
    for (final v in ['9', '14', '11', '37', '5']) {
      expect(find.text(v), findsOneWidget);
    }
    expect(find.text('Auto-deletes after 30 days'), findsOneWidget);
    expect(find.text('Start a focus session'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);
    expect(find.text('#ideas'), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.bySemanticsLabel('More options'), findsOneWidget);
  });

  testWidgets('dark mode and 360 pt × 1.3 without overflow', (tester) async {
    final h = await harness(tester, mockup: true);
    await withShadows(() async {
      await pumpApp(
        tester,
        h,
        AppRoutes.library,
        size: _mockupSize,
        dark: true,
      );
      await captureScreen(tester, '05_library_dark');
    });
    expect(tester.takeException(), isNull);
    await pumpApp(
      tester,
      h,
      AppRoutes.library,
      size: const Size(360, 1500),
      textScale: 1.3,
    );
    await captureScreen(tester, '05_library_360_x1.3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('counts are live and the vault card follows the lock', (
    tester,
  ) async {
    final h = await harness(tester);
    final seed = (await tester.runAsync(() => seedLibrary(h)))!;
    await pumpApp(tester, h, AppRoutes.library, size: _mockupSize);

    expect(find.text('3 items across 6 spaces'), findsOneWidget);
    expect(find.text('1 pinned'), findsOneWidget);
    expect(find.text('1 due today'), findsOneWidget);
    expect(find.text(LibraryFormat.createFirst), findsNWidgets(4));
    expect(find.text('#work'), findsOneWidget);

    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).setPinned([
        ItemRef(ItemType.note, seed.plainNote),
      ], true),
    );
    await settle(tester);
    expect(find.text('2 pinned'), findsOneWidget);

    expect(find.text('Locked'), findsOneWidget);
    h.container.read(testVaultStatus.notifier).state = VaultStatus.unlocked;
    await settle(tester);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.lock), findsNothing);
  });

  testWidgets('Show counts off hides numbers; hidden spaces drop out', (
    tester,
  ) async {
    final h = await harness(tester, mockup: true);
    await pumpApp(tester, h, AppRoutes.library, size: _mockupSize);
    expect(find.byType(LibraryModuleCard), findsNWidgets(6));

    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          libraryShowCounts: false,
          hiddenLibraryModules: {ItemType.habit.key},
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(LibraryModuleCard), findsNWidgets(5));
    expect(find.text('107 items across 5 spaces'), findsOneWidget);
    expect(find.text('37'), findsNothing);
    expect(find.text('2/4 done today'), findsNothing);
  });

  testWidgets('Pinned row and tag pills open the mixed lists', (tester) async {
    final h = await harness(tester);
    await tester.runAsync(() => seedLibrary(h));
    await pumpApp(tester, h, AppRoutes.library, size: _mockupSize);

    await tester.tap(find.text('Pinned'));
    await settle(tester);
    expect(find.byType(LibraryCollectionScreen), findsOneWidget);
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('Product launch plan'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing);

    await tester.tap(find.byType(FFBackButton));
    await settle(tester);
    await tester.tap(find.text('#work'));
    await settle(tester);
    // FFNavHeader shows the subtitle as an uppercase caption.
    expect(find.text('2 ITEMS'), findsOneWidget);
    expect(find.text('Product launch plan'), findsOneWidget);
    expect(find.text('Send the invoice'), findsOneWidget);
    expect(find.text('TASKS'), findsOneWidget);
  });

  testWidgets('long-press a tag → delete with confirmation and Undo', (
    tester,
  ) async {
    final h = await harness(tester);
    final seed = (await tester.runAsync(() => seedLibrary(h)))!;
    // An archived item keeps the tag through delete + Undo too.
    final task = ItemRef(ItemType.task, seed.task);
    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).archive([task]),
    );
    await pumpApp(tester, h, AppRoutes.library, size: _mockupSize);

    await tester.longPress(find.text('#work'));
    await settle(tester);
    await tester.tap(find.text('Delete tag'));
    await settle(tester);
    await tester.tap(find.text('Delete tag').last);
    await settle(tester);
    expect(find.text('#work'), findsNothing);
    expect(find.text('#work deleted'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await settle(tester, rounds: 6);
    expect(find.text('#work'), findsOneWidget);
    final tags = (await tester.runAsync(
      () => h.read(tagsRepositoryProvider).watchTags().first,
    ))!;
    expect(tags.single.name, 'work');
    final ofTask = (await tester.runAsync(
      () => h.read(tagsRepositoryProvider).watchTagsOf(task).first,
    ))!;
    expect(ofTask.map((t) => t.name), ['work']);
  });
}
