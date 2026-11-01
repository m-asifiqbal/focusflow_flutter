/// Home › Prayer: the day's summary (done ring, now / next, Hijri date) and
/// every prayer, fast and practice of today as one timeline — Mark prayed
/// on the open one, +1 on a counter, the rest showing their result or how
/// long until they start (captures: light, dark, 360 pt × 1.3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/home/presentation/widgets/home_prayer_section.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_day_card.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

/// Sun 1 Nov 2026, 3:50 PM — Asr (3:45 – 5:45 PM) is open.
final _now = DateTime(2026, 11, 1, 15, 50);
final _day = DateTime(2026, 11, 1);

void main() {
  Future<TestHarness> boot(WidgetTester tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() async {
      await h.updateSettings(
        (s) => s.copyWith(
          prayer: const PrayerPrefs(tradition: 'islam', discreet: false),
        ),
      );
      final repo = h.read(prayersRepositoryProvider);
      final presets = PrayerPresets.of(PrayerTradition.islam, _now);
      await repo.addAll(
        PrayerPresets.manual([
          for (final p in presets)
            if (p.core || p.draft.name == 'Evening adhkar') p.draft,
        ]),
      );
      final list = await repo.watchPrayers(PrayersScope.active).first;
      Prayer named(String n) => list.firstWhere((p) => p.name == n);
      await repo.mark(named('Fajr').id, _day, PrayerStatus.onTime);
      await repo.mark(named('Dhuhr').id, _day, PrayerStatus.late);
      await repo.save(
        named('Asr').copyWith(
          jamaat: const PrayerJamaat.at(16 * 60),
          remindBeforeJamaat: 10,
        ),
      );
      await repo.addCount(named('Evening adhkar').id, _day, 40, target: 100);
    });
    return h;
  }

  Future<void> showSection(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byType(HomePrayerSection),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
  }

  testWidgets('the whole day: summary, every prayer, Mark prayed, +1', (
    tester,
  ) async {
    final h = await boot(tester);
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 2400));
    await showSection(tester);
    expect(find.byType(PrayerDayCard), findsOneWidget);
    // Summary: 2 of 5 done, Asr open now.
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('Asr now'), findsOneWidget);
    expect(find.text('Ends in 1h 55m'), findsWidgets);
    for (final name in [
      'Fajr',
      'Dhuhr',
      'Asr',
      'Evening adhkar',
      'Maghrib',
      'Isha',
    ]) {
      expect(
        find.descendant(
          of: find.byType(PrayerDayCard),
          matching: find.text(name),
        ),
        findsOneWidget,
        reason: name,
      );
    }
    expect(find.text('On time'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('40 / 100 today'), findsOneWidget);
    expect(find.text('Jamaat 04:00 PM · in 10 min'), findsOneWidget);
    expect(find.text('in 1h 55m'), findsWidgets);
    await captureScreen(tester, 'home_prayer');

    await tester.tap(find.text('Mark prayed'));
    await settle(tester);
    expect(find.text('3/5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add one to Evening adhkar'));
    await settle(tester);
    expect(find.text('41 / 100 today'), findsOneWidget);
  });

  testWidgets('dark mode and 360 pt × 1.3 without overflow', (tester) async {
    final h = await boot(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.home,
      size: const Size(390, 2400),
      dark: true,
    );
    await showSection(tester);
    await captureScreen(tester, 'home_prayer_dark');
    expect(tester.takeException(), isNull);
    await pumpApp(
      tester,
      h,
      AppRoutes.home,
      size: const Size(360, 3000),
      textScale: 1.3,
    );
    await showSection(tester);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, 'home_prayer_360_x13');
  });
}
