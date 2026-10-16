/// Screen 06 — Global search: mockup state ("design", 14 matches) in light
/// and dark, debounced typing, module chips, recent searches, filters,
/// no-results copy, opening a result, recent searches in the secure store
/// (migrated from settings; vault opens never recorded), pinned
/// suggestions, and no overflow at 360 pt / 1.3.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/features/search/data/datasource/recent_searches_store.dart';
import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/presentation/widgets/search_result_row.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../core/sync/drive_fakes.dart' show MemorySecureStore;
import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../search_seed.dart';

/// design/06 is 1170×2622 px = 390×874 pt.
const _mockup = Size(390, 874);

void main() {
  late TestHarness h;
  late MemorySecureStore secure;
  late SearchSeed data;

  /// What the secure store holds (newest first).
  List<String> stored() {
    final raw = secure.values[RecentSearchesStore.storageKey];
    return raw == null ? const [] : List<String>.from(jsonDecode(raw) as List);
  }

  String location() => h
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .last
      .matchedLocation;

  Future<void> setUp(WidgetTester tester, {bool seed = true}) async {
    await loadAppFonts();
    secure = MemorySecureStore();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: searchNow,
        overrides: [secureStoreProvider.overrideWithValue(secure)],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    if (seed) data = (await tester.runAsync(() => seedSearchMockup(h)))!;
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          recentSearches: const [
            'groceries',
            'Q3 strategy',
            'netflix',
            '#finance',
          ],
        ),
      ),
    );
  }

  String q(String text) => '${AppRoutes.search}?q=$text';

  testWidgets('mockup state (light)', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, q('design'), size: _mockup);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.bySemanticsLabel('All, 14'), findsOneWidget);
    expect(find.bySemanticsLabel('Notes, 5'), findsOneWidget);
    expect(find.byType(SearchResultRow), findsNWidgets(5));
    expect(find.text('Notes · Ideas · 2h ago'), findsOneWidget);
    expect(find.text('Tasks · Today 11:30 AM'), findsOneWidget);
    expect(find.text('Reminders · Fri 3:00 PM'), findsOneWidget);
    expect(find.text('Vault · unlock to view'), findsOneWidget);
    expect(find.text('Habits · 12-day streak'), findsOneWidget);
    expect(find.text('Q3 strategy'), findsOneWidget);
    expect(find.text('Include archived'), findsOneWidget);
    await captureScreen(tester, '06_global_search');
  });

  testWidgets('mockup state (dark)', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, q('design'), size: _mockup, dark: true);
    expect(find.byType(SearchResultRow), findsNWidgets(5));
    await captureScreen(tester, '06_global_search_dark');
  });

  testWidgets('typing is debounced; chips filter; Show all expands', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.search, size: _mockup);
    expect(find.text('Recent searches'.toUpperCase()), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'desig');
    await settle(tester);
    expect(find.byType(SearchResultRow), findsNWidgets(5));
    await tester.tap(find.text('Show all 14 results'));
    await settle(tester);
    expect(find.byType(SearchResultRow), findsAtLeastNWidgets(6));

    await tester.tap(find.bySemanticsLabel('Tasks, 4'));
    await settle(tester);
    expect(find.byType(SearchResultRow), findsNWidgets(4));
  });

  testWidgets('no results + Clear recent searches', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, q('zzz'), size: _mockup);
    expect(find.text('No matches for “zzz”'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(h.read(settingsProvider).recentSearches, isEmpty);
    expect(stored(), isEmpty);
    expect(find.text('groceries'), findsNothing);
  });

  testWidgets('Include archived toggles; recent pill re-runs a search', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.search, size: _mockup);
    await tester.tap(find.text('netflix'));
    await settle(tester);
    expect(find.text('No matches for “netflix”'), findsOneWidget);
    await tester.tap(find.text('Include archived'));
    await settle(tester);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('tapping a result opens the item and remembers the query', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, q('mobile'), size: _mockup);
    await tester.tap(find.byType(SearchResultRow).first);
    await settle(tester);
    // Stored in the secure store — not in plaintext settings.
    expect(stored().first, 'mobile');
    expect(h.read(settingsProvider).recentSearches, isEmpty);
    expect(location(), startsWith('/notes/'));
  });

  testWidgets('settings recent searches migrate to the secure store', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.search, size: _mockup);
    expect(find.text('netflix'), findsOneWidget);
    expect(stored(), ['groceries', 'Q3 strategy', 'netflix', '#finance']);
    expect(h.read(settingsProvider).recentSearches, isEmpty);
  });

  testWidgets('opening a vault result does not record the query', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, q('figma'), size: _mockup);
    await tester.tap(find.text('Vault · unlock to view'));
    await settle(tester);
    expect(stored(), isNot(contains('figma')));
    expect(location(), AppRoutes.search);
  });

  testWidgets('pinned items are suggested before typing', (tester) async {
    await setUp(tester);
    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).setPinned([
        ItemRef(ItemType.note, data.note),
        ItemRef(ItemType.vault, data.vault),
      ], true),
    );
    await pumpApp(tester, h, AppRoutes.search, size: _mockup);
    expect(find.text('PINNED'), findsOneWidget);
    expect(find.text('Mobile App Design Trends'), findsOneWidget);
    expect(find.text('Figma — design account'), findsNothing);
    await tester.tap(find.text('Mobile App Design Trends'));
    await settle(tester);
    expect(location(), '/notes/${data.note}');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      q('design'),
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '06_global_search_360_1.3');
  });

  test('meta line formats', () {
    final now = searchNow;
    SearchHit hit(ItemType t, {DateTime? due, int? min, DateTime? at}) =>
        SearchHit(
          ref: ItemRef(t, 'x'),
          title: 't',
          relevance: 1,
          updatedAt: now.subtract(const Duration(days: 2)),
          dueDay: due,
          dueMinutes: min,
          triggerAt: at,
          detail: t == ItemType.vault ? 'Login' : 'Health',
          isArchived: t == ItemType.habit,
        );
    expect(
      searchHitMeta(hit(ItemType.task, due: DateTime(2026, 6, 11)), now: now),
      'Tasks · Tomorrow',
    );
    expect(
      searchHitMeta(
        hit(ItemType.task, due: DateTime(2026, 6, 10), min: 690),
        now: now,
        use24h: true,
      ),
      'Tasks · Today 11:30',
    );
    expect(searchHitMeta(hit(ItemType.note), now: now), 'Notes · 2d ago');
    expect(
      searchHitMeta(hit(ItemType.vault), now: now, vaultUnlocked: true),
      'Vault · Login',
    );
    expect(
      searchHitMeta(hit(ItemType.habit), now: now),
      'Habits · Health · Archived',
    );
    expect(
      searchHitMeta(
        hit(ItemType.reminder, at: DateTime(2026, 7, 1, 9)),
        now: now,
      ),
      'Reminders · Jul 1 9:00 AM',
    );
  });
}
