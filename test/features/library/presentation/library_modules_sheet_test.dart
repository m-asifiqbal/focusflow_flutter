/// Prompt 05 ⋯ menu "reorder/hide modules": orderedLibraryModules (Vault
/// always last), the hub cards follow AppSettings.libraryModuleOrder, and
/// the Spaces sheet reorders by drag handle and hides by switch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/widgets/library_module_card.dart';
import 'package:focusflow/features/library/presentation/widgets/library_modules_sheet.dart';
import 'package:focusflow/features/library/presentation/widgets/library_sections.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../library_fixtures.dart';

void main() {
  setUpAll(loadAppFonts);

  group('orderedLibraryModules', () {
    test('default order with Vault last', () {
      expect(orderedLibraryModules(const []), ItemType.values);
    });

    test('custom order; unknown keys skipped, missing appended, Vault pinned '
        'last', () {
      expect(
        orderedLibraryModules([
          ItemType.vault.key,
          ItemType.habit.key,
          'nope',
          ItemType.note.key,
        ]),
        [
          ItemType.habit,
          ItemType.note,
          ItemType.task,
          ItemType.reminder,
          ItemType.medicine,
          ItemType.vault,
        ],
      );
    });
  });

  Future<TestHarness> harness(WidgetTester tester) async {
    final h = (await tester.runAsync(
      () => TestHarness.create(
        now: kLibraryNow,
        overrides: libraryOverrides(mockup: true),
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  testWidgets('hub cards follow libraryModuleOrder', (tester) async {
    final h = await harness(tester);
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          libraryModuleOrder: [ItemType.habit.key, ItemType.reminder.key],
        ),
      ),
    );
    await pumpApp(tester, h, AppRoutes.library, size: const Size(390, 1271));
    final cards = tester
        .widgetList<LibraryModuleCard>(find.byType(LibraryModuleCard))
        .map((c) => c.type)
        .toList();
    expect(cards, [
      ItemType.habit,
      ItemType.reminder,
      ItemType.note,
      ItemType.task,
      ItemType.medicine,
      ItemType.vault,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet: drag a handle to reorder, switch to hide', (
    tester,
  ) async {
    final h = await harness(tester);
    await pumpScreen(
      tester,
      h,
      const Scaffold(body: SingleChildScrollView(child: LibraryModulesSheet())),
    );
    expect(find.bySemanticsLabel('Reorder Notes'), findsOneWidget);
    expect(find.bySemanticsLabel('Reorder Vault'), findsNothing);

    // Drag Notes' handle below Tasks.
    final handle = find.bySemanticsLabel('Reorder Notes');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 35));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 35));
    await tester.pump();
    await gesture.up();
    await settle(tester);
    final order = orderedLibraryModules(
      h.read(settingsProvider).libraryModuleOrder,
    );
    expect(order.take(2), [ItemType.task, ItemType.note]);
    expect(order.last, ItemType.vault);

    await tester.tap(find.byType(FFSwitch).at(2));
    await settle(tester);
    expect(h.read(settingsProvider).hiddenLibraryModules, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet fits 360 pt at text scale 1.3 (dark)', (tester) async {
    final h = await harness(tester);
    await pumpScreen(
      tester,
      h,
      const Scaffold(body: SingleChildScrollView(child: LibraryModulesSheet())),
      size: const Size(360, 800),
      textScale: 1.3,
      dark: true,
    );
    expect(tester.takeException(), isNull);
  });
}
