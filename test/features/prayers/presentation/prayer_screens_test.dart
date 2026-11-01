/// Prayer screens in the real app: the tab (hero, today's rows, a fast and
/// a counter, progress; light / dark / 360 pt at text 1.3 captures), "Mark
/// prayed" from the hero with Undo, the 5-tab bar, the setup picker saving
/// a tradition's prayers, and the editor saving a new prayer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/widgets/ff_bottom_nav.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_hero.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

/// Sat 1 Nov 2026, 3:50 PM — Asr is open (fixed windows, no location).
final _now = DateTime(2026, 11, 1, 15, 50);
final _day = DateTime(2026, 11, 1);

const _dhaka = PrayerPrefs(tradition: 'islam', showTab: true, discreet: false);

void main() {
  Future<TestHarness> boot(WidgetTester tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  /// The Islam preset as fixed times + a dhikr goal, with a few days of
  /// history.
  Future<void> seed(WidgetTester tester, TestHarness h) async {
    await tester.runAsync(() async {
      await h.updateSettings((s) => s.copyWith(prayer: _dhaka));
      final repo = h.read(prayersRepositoryProvider);
      final presets = PrayerPresets.of(PrayerTradition.islam, DateTime(2026));
      final picked = [
        for (final p in presets)
          if (p.core ||
              p.draft.kind == PrayerKind.dhikr && p.draft.name.contains('Even'))
            p.draft,
      ];
      // Added two weeks ago, so last week counts.
      h.clock.set(_now.subtract(const Duration(days: 14)));
      final ids = await repo.addAll(PrayerPresets.manual(picked));
      h.clock.set(_now);
      final list = await repo.watchPrayers(PrayersScope.active).first;
      for (var d = 1; d <= 6; d++) {
        for (final p in list.take(5)) {
          await repo.mark(
            p.id,
            _day.subtract(Duration(days: d)),
            d == 3 && p.name == 'Fajr'
                ? PrayerStatus.late
                : PrayerStatus.onTime,
          );
        }
      }
      // Today: Fajr and Dhuhr done; dhikr part way.
      await repo.mark(list[0].id, _day, PrayerStatus.onTime);
      await repo.mark(
        list[1].id,
        _day,
        PrayerStatus.onTime,
        congregation: true,
      );
      final dhikr = list.firstWhere((p) => p.kind == PrayerKind.dhikr);
      await repo.addCount(dhikr.id, _day, 40, target: 100);
      expect(ids, hasLength(6));
    });
  }

  testWidgets('the Prayer tab: hero, today, progress (captures)', (
    tester,
  ) async {
    final h = await boot(tester);
    await seed(tester, h);
    await pumpApp(tester, h, AppRoutes.prayer, size: const Size(390, 1800));
    expect(find.byType(PrayerHeroCard), findsOneWidget);
    expect(find.text('Asr'), findsWidgets);
    expect(find.text('Mark prayed'), findsWidgets);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Prayer tip of the day'), findsOneWidget);
    await captureScreen(tester, 'prayer_tab');
    await pumpApp(
      tester,
      h,
      AppRoutes.prayer,
      size: const Size(390, 1800),
      dark: true,
    );
    await captureScreen(tester, 'prayer_tab_dark');
  });

  testWidgets('no overflow at 360 pt and text 1.3', (tester) async {
    final h = await boot(tester);
    await seed(tester, h);
    await pumpApp(
      tester,
      h,
      AppRoutes.prayer,
      size: const Size(360, 2000),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, 'prayer_tab_360_x13');
  });

  testWidgets('Mark prayed on the hero, and the 5-tab bar', (tester) async {
    final h = await boot(tester);
    await seed(tester, h);
    await pumpApp(tester, h, AppRoutes.prayer);
    final nav = tester.widget<FFBottomNav>(find.byType(FFBottomNav));
    expect(nav.items.map((i) => i.label), [
      'Home',
      'Library',
      'Prayer',
      'Insights',
      'Settings',
    ]);
    await tester.tap(
      find.descendant(
        of: find.byType(PrayerHeroCard),
        matching: find.text('Mark prayed'),
      ),
    );
    await settle(tester);
    expect(find.text('UNDO'), findsOneWidget);
    final asr = (await tester.runAsync(
      () => h
          .read(prayersRepositoryProvider)
          .watchPrayers(PrayersScope.active)
          .first,
    ))!.firstWhere((p) => p.name == 'Asr');
    final log = await tester.runAsync(
      () => h.read(prayersRepositoryProvider).log(asr.id, _day),
    );
    expect(log?.status, PrayerStatus.onTime);
  });

  testWidgets('setup: a tradition\'s prayers saved, the tab turned on', (
    tester,
  ) async {
    final h = await boot(tester);
    await pumpApp(tester, h, AppRoutes.prayerSetup);
    await tester.tap(find.text('Islam'));
    await settle(tester);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    await captureScreen(tester, 'prayer_setup');
    // Fixed times: no location prompt in a test.
    await tester.tap(find.text('Manual'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    final list = await tester.runAsync(
      () => h
          .read(prayersRepositoryProvider)
          .watchPrayers(PrayersScope.active)
          .first,
    );
    expect(list!.map((p) => p.name), [
      'Fajr',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ]);
    expect(list.every((p) => !p.usesSun), isTrue);
    final prefs = h.read(settingsProvider).prayer;
    expect(prefs.tradition, 'islam');
    expect(prefs.showTab, isTrue);
  });

  testWidgets('editor: a new prayer with a name is saved', (tester) async {
    final h = await boot(tester);
    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(prayer: _dhaka)),
    );
    await pumpApp(tester, h, AppRoutes.newPrayer, size: const Size(390, 1700));
    await captureScreen(tester, 'prayer_editor');
    await tester.enterText(find.byType(TextField).first, 'Ishraq');
    await tester.tap(find.text('Save').last);
    await settle(tester);
    final list = await tester.runAsync(
      () => h
          .read(prayersRepositoryProvider)
          .watchPrayers(PrayersScope.active)
          .first,
    );
    expect(list!.single.name, 'Ishraq');
  });
}
