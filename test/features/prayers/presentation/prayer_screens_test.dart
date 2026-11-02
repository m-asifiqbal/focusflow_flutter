/// Prayer screens in the real app: the tab (hero, today's rows, a fast and
/// a counter, progress; light / dark / 360 pt at text 1.3 captures), "Mark
/// prayed" from the hero with Undo, the progress Day / Week / Month / Year
/// views, the bar without a Prayer tab, the setup picker saving
/// a tradition's prayers, and the editor saving a new prayer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_progress_views.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_day_card.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_hero.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_sun_arc.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

/// Sat 1 Nov 2026, 3:50 PM — Asr is open (fixed windows, no location).
final _now = DateTime(2026, 11, 1, 15, 50);
final _day = DateTime(2026, 11, 1);

const _dhaka = PrayerPrefs(tradition: 'islam', discreet: false);

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
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1800));
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
      AppRoutes.prayers,
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
      AppRoutes.prayers,
      size: const Size(360, 2000),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, 'prayer_tab_360_x13');
  });

  testWidgets('progress: Day, Week, Month and Year views (captures)', (
    tester,
  ) async {
    final h = await boot(tester);
    await seed(tester, h);
    Future<void> open({Size size = const Size(390, 2400), double t = 1}) =>
        pumpApp(tester, h, AppRoutes.prayers, size: size, textScale: t);
    Future<void> pick(String view) async {
      await tester.tap(
        find.descendant(
          of: find.byType(FFSegmented<PrayerProgressView>),
          matching: find.text(view),
        ),
      );
      await settle(tester);
    }

    await open();
    // Week is the default.
    expect(find.text('Last 7 days'), findsOneWidget);

    await pick('Day');
    expect(find.text('Today'), findsWidgets);
    expect(find.text('2 of 5 prayed'), findsOneWidget);
    expect(find.textContaining('Marked'), findsWidgets);
    expect(find.textContaining('In congregation'), findsWidgets);
    await captureScreen(tester, 'prayer_progress_day');
    await tester.tap(find.bySemanticsLabel('Previous day'));
    await settle(tester);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('5 of 5 prayed'), findsOneWidget);

    await pick('Month');
    expect(find.text('November 2026'), findsOneWidget);
    await captureScreen(tester, 'prayer_progress_month');
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);

    await pick('Year');
    expect(find.text('Last 12 months'), findsOneWidget);
    expect(find.byType(FFHeatmap), findsOneWidget);
    await captureScreen(tester, 'prayer_progress_year');

    // Every view at 360 pt and text 1.3 without overflow.
    await open(size: const Size(360, 2800), t: 1.3);
    for (final view in ['Day', 'Week', 'Month', 'Year']) {
      await pick(view);
      expect(tester.takeException(), isNull, reason: view);
    }
  });

  testWidgets('Mark prayed in the list; the card shows what comes next; '
      'Prayer is not a tab', (tester) async {
    final h = await boot(tester);
    await seed(tester, h);
    // Set up, and still the four classic tabs.
    await pumpApp(tester, h, AppRoutes.home);
    final nav = tester.widget<FFBottomNav>(find.byType(FFBottomNav));
    expect(nav.items.map((i) => i.label), [
      'Home',
      'Library',
      'Insights',
      'Settings',
    ]);
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1800));
    Finder inCard(Finder f) =>
        find.descendant(of: find.byType(PrayerHeroCard), matching: f);
    // 3:50 PM: Asr's waqt is open and not marked → the card shows it ("NOW",
    // time left), without a Mark button; it is marked from its row.
    expect(inCard(find.text('Asr')), findsOneWidget);
    expect(inCard(find.text('NOW')), findsOneWidget);
    expect(inCard(find.textContaining('Ends in')), findsOneWidget);
    // The sky arc's live H:MM:SS countdown.
    expect(
      inCard(find.textContaining(RegExp(r'^\d+:\d\d:\d\d left$'))),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PrayerHeroCard),
        matching: find.text('Mark prayed'),
      ),
      findsNothing,
    );
    expect(find.byType(PrayerSunArc), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(PrayerDayCard),
        matching: find.text('Mark prayed'),
      ),
    );
    await settle(tester);
    expect(find.text('UNDO'), findsOneWidget);
    // Marked → the card moves on to the next prayer.
    expect(inCard(find.text('Maghrib')), findsOneWidget);
    expect(inCard(find.text('NEXT')), findsOneWidget);
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

  testWidgets('all done: a line under the card, which shows tomorrow', (
    tester,
  ) async {
    final h = await boot(tester);
    await seed(tester, h);
    await tester.runAsync(() async {
      final repo = h.read(prayersRepositoryProvider);
      final list = await repo.watchPrayers(PrayersScope.active).first;
      for (final p in list) {
        if (p.kind != PrayerKind.salah) continue;
        await repo.mark(p.id, _day, PrayerStatus.onTime);
      }
    });
    // Late evening: nothing left today.
    h.clock.set(DateTime(2026, 11, 1, 23, 50));
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1800));
    expect(find.text('All prayers done today'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PrayerHeroCard),
        matching: find.text('All prayers done today'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PrayerHeroCard),
        matching: find.text('Fajr'),
      ),
      findsOneWidget,
    );
    expect(find.text('NEXT · TOMORROW'), findsOneWidget);
    // The sky arc's travel and pop-in finish first.
    await tester.pump(const Duration(seconds: 3));
    await captureScreen(tester, 'prayer_all_done_night');
    await pumpApp(
      tester,
      h,
      AppRoutes.prayers,
      size: const Size(390, 1800),
      dark: true,
    );
    // The sky arc's travel and pop-in finish first.
    await tester.pump(const Duration(seconds: 3));
    await captureScreen(tester, 'prayer_all_done_night_dark');
  });

  testWidgets('setup: a tradition\'s prayers saved', (tester) async {
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
