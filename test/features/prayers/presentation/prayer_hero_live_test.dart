/// The Prayer hero stays correct and calm while the page is open:
///   • when a waqt ends the card moves on to the next prayer at that second,
///     without leaving the page (the minute clock alone would lag);
///   • scrolling away and back keeps the very same hero (its sky is not
///     rebuilt, so the sun's intro does not replay);
///   • the people icon follows the jamaat words;
///   • the sky draws at every time of the day without errors (captures:
///     build/screens/prayer_sky_*.png).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_hero.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_sun_arc.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_palette.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_sprites.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

void main() {
  /// Sun 1 Nov 2026 at [at], Dhaka, the five daily prayers as fixed times.
  Future<TestHarness> boot(
    WidgetTester tester,
    DateTime at, {
    bool jamaat = false,
  }) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: at, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() async {
      await h.updateSettings(
        (s) => s.copyWith(
          prayer: const PrayerPrefs(
            tradition: 'islam',
            discreet: false,
            latitude: 23.81,
            longitude: 90.41,
            placeLabel: 'Dhaka',
          ),
        ),
      );
      final repo = h.read(prayersRepositoryProvider);
      await repo.addAll(
        PrayerPresets.manual([
          for (final p in PrayerPresets.of(PrayerTradition.islam, at))
            if (p.core) p.draft,
        ]),
      );
      if (jamaat) {
        final asr = (await repo.watchPrayers(PrayersScope.active).first)
            .firstWhere((p) => p.name == 'Asr');
        await repo.save(
          asr.copyWith(place: 'Mosque', jamaat: const PrayerJamaat.at(960)),
        );
      }
    });
    return h;
  }

  Finder inHero(Finder f) =>
      find.descendant(of: find.byType(PrayerHeroCard), matching: f);

  /// Writes just the hero card to build/screens/<name>.png.
  Future<void> captureHero(WidgetTester tester, String name) async {
    await tester.pump();
    final rect = tester.getRect(find.byType(PrayerHeroCard));
    final dpr = tester.view.devicePixelRatio;
    // ignore: invalid_use_of_protected_member
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final image = await layer.toImage(
        Rect.fromLTRB(
          rect.left * dpr,
          rect.top * dpr,
          rect.right * dpr,
          rect.bottom * dpr,
        ),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('build/screens/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('a waqt ending moves the card on by itself', (tester) async {
    // Asr is 3:45 – 5:45 PM; ten seconds before it ends.
    final h = await boot(tester, DateTime(2026, 11, 1, 17, 44, 50));
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1400));
    expect(inHero(find.text('Asr')), findsOneWidget);
    expect(inHero(find.text('NOW')), findsOneWidget);

    // The clock passes the end. Less than the minute clock's 30 s beat
    // goes by, so only the page's own wake-up can notice.
    h.clock.set(DateTime(2026, 11, 1, 17, 45, 1));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 500));
    // Maghrib begins at the very moment Asr ends: it is the open prayer now.
    expect(inHero(find.text('Maghrib')), findsOneWidget);
    expect(inHero(find.text('NOW')), findsOneWidget);
    expect(inHero(find.textContaining('Ends in')), findsOneWidget);
    expect(inHero(find.text('Asr')), findsNothing);
  });

  testWidgets('scrolling away and back keeps the same hero', (tester) async {
    final h = await boot(tester, DateTime(2026, 11, 1, 15, 50));
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 700));
    final first = tester.state(find.byType(PrayerSunArc));
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -2500));
    await tester.pump(const Duration(milliseconds: 400));
    // Far below the hero: it is off screen, but still alive.
    expect(find.byType(PrayerSunArc), findsNothing);
    expect(
      tester.state(find.byType(PrayerSunArc, skipOffstage: false)),
      same(first),
    );
    await tester.drag(list, const Offset(0, 2500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.state(find.byType(PrayerSunArc)), same(first));
  });

  testWidgets('the people icon comes after the jamaat words', (tester) async {
    final h = await boot(tester, DateTime(2026, 11, 1, 15, 50), jamaat: true);
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1400));
    final text = tester.getRect(inHero(find.textContaining('Jamaat')));
    final icon = tester.getRect(inHero(find.byIcon(FontAwesomeIcons.users)));
    expect(icon.left, greaterThan(text.left + 20));
    // On the last line of the words, not above them.
    expect(icon.bottom, greaterThan(text.center.dy));
  });

  // One page per time of day (captures: build/screens/prayer_sky_*.png).
  final times = {
    '0540': DateTime(2026, 11, 1, 5, 40),
    '0635': DateTime(2026, 11, 1, 6, 35),
    '0900': DateTime(2026, 11, 1, 9),
    '1230': DateTime(2026, 11, 1, 12, 30),
    '1620': DateTime(2026, 11, 1, 16, 20),
    '1715': DateTime(2026, 11, 1, 17, 15),
    '1845': DateTime(2026, 11, 1, 18, 45),
    '2200': DateTime(2026, 11, 1, 22),
    '0300': DateTime(2026, 11, 2, 3),
  };
  for (final e in times.entries) {
    testWidgets('the sky at ${e.key} draws (capture)', (tester) async {
      final h = await boot(tester, e.value, jamaat: true);
      await tester.runAsync(
        () => SkySprites.instance.warmUp(moonAge: SkyMoon.age(e.value)),
      );
      await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 700));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(inHero(find.byType(PrayerSunArc)), findsOneWidget);
      await captureHero(tester, 'prayer_sky_${e.key}');
    });
  }
}
