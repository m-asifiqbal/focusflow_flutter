/// Jamaat (congregation) time end to end: the editor's Off · Set time ·
/// After start switch saves it with a reminder, the Prayer page shows it
/// under the window ("Jamaat 04:00 PM · in 10 min") and on the "Now" card;
/// fasts have no jamaat section (captures: editor, page, 360 pt × 1.3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/editor/prayer_jamaat_section.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_hero.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

/// Sun 1 Nov 2026, 3:50 PM — Asr (3:45 – 5:45 PM) is open.
final _now = DateTime(2026, 11, 1, 15, 50);

void main() {
  Future<(TestHarness, List<Prayer>)> boot(WidgetTester tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    final list = (await tester.runAsync(() async {
      await h.updateSettings(
        (s) => s.copyWith(
          prayer: const PrayerPrefs(tradition: 'islam', discreet: false),
        ),
      );
      final repo = h.read(prayersRepositoryProvider);
      await repo.addAll(
        PrayerPresets.manual([
          for (final p in PrayerPresets.of(PrayerTradition.islam, _now))
            if (p.core) p.draft,
        ]),
      );
      return repo.watchPrayers(PrayersScope.active).first;
    }))!;
    return (h, list);
  }

  Future<Prayer> reload(WidgetTester tester, TestHarness h, String id) async =>
      (await tester.runAsync(
        () => h.read(prayersRepositoryProvider).getPrayer(id),
      ))!;

  testWidgets('set a jamaat time in the editor, see it on the page', (
    tester,
  ) async {
    final (h, list) = await boot(tester);
    final asr = list.firstWhere((p) => p.name == 'Asr');
    await pumpApp(
      tester,
      h,
      AppRoutes.prayerEdit(asr.id),
      size: const Size(390, 2200),
    );
    expect(find.text('JAMAAT (CONGREGATION)'), findsOneWidget);
    await tester.tap(find.text('Set time'));
    await settle(tester);
    // 15 minutes into today's window, reminded 10 minutes before.
    expect(find.text('Today: jamaat at 04:00 PM'), findsOneWidget);
    expect(find.text('10 min before'), findsWidgets);
    await captureScreen(tester, 'prayer_editor_jamaat');
    await tester.tap(find.text('Save').last);
    await settle(tester);
    final saved = await reload(tester, h, asr.id);
    expect(saved.jamaat, const PrayerJamaat.at(16 * 60));
    expect(saved.remindBeforeJamaat, 10);

    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1400));
    expect(find.text('Jamaat 04:00 PM · in 10 min'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(PrayerHeroCard),
        matching: find.textContaining('Jamaat 04:00 PM'),
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'prayer_page_jamaat');

    await pumpApp(
      tester,
      h,
      AppRoutes.prayers,
      size: const Size(360, 1600),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('"After start" follows the window; Off removes it', (
    tester,
  ) async {
    final (h, list) = await boot(tester);
    final maghrib = list.firstWhere((p) => p.name == 'Maghrib');
    await pumpApp(
      tester,
      h,
      AppRoutes.prayerEdit(maghrib.id),
      size: const Size(390, 2200),
    );
    await tester.tap(find.text('After start'));
    await settle(tester);
    expect(find.text('After the start'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    await tester.tap(find.text('Save').last);
    await settle(tester);
    expect(
      (await reload(tester, h, maghrib.id)).jamaat,
      const PrayerJamaat.afterStart(10),
    );

    await pumpApp(
      tester,
      h,
      AppRoutes.prayerEdit(maghrib.id),
      size: const Size(390, 2200),
    );
    await tester.tap(find.text('Off').first);
    await settle(tester);
    await tester.tap(find.text('Save').last);
    await settle(tester);
    final off = await reload(tester, h, maghrib.id);
    expect((off.jamaat, off.remindBeforeJamaat), (null, null));
  });

  testWidgets('a fast has no jamaat section', (tester) async {
    final (h, _) = await boot(tester);
    await pumpApp(tester, h, AppRoutes.newPrayer, size: const Size(390, 2200));
    expect(find.byType(PrayerJamaatSection), findsOneWidget);
    await tester.tap(find.text('Fasting'));
    await settle(tester);
    expect(find.byType(PrayerJamaatSection), findsNothing);
  });
}
