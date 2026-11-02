/// Adding and editing a prayer in each tradition's own words, in the real
/// screens: "Set up Prayer" asks the tradition's school question and
/// remembers it (a Hanafi gets Witr and the Hanafi Asr); the "+" sheet
/// shows the school chips and each practice's hint; the editor speaks
/// Fard / Tefillah / Japa / Sitting, "Auto (zmanim)", the minyan, a Length
/// row for a 20-minute sit, parana for a Hindu fast (captures:
/// build/screens/prayer_trad_*.png).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_editor_screen.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_add_sheet.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

final _now = DateTime(2026, 11, 1, 9);

void main() {
  Future<TestHarness> boot(WidgetTester tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  Prayer preset(PrayerTradition t, String name, {PrayerSchool? school}) =>
      PrayerPresets.of(
        t,
        _now,
        school: school,
      ).firstWhere((p) => p.draft.name == name).draft;

  Future<void> editor(WidgetTester tester, TestHarness h, Prayer draft) async {
    await pumpScreen(
      tester,
      h,
      PrayerEditorScreen(initial: draft),
      size: const Size(390, 3200),
    );
  }

  group('Set up Prayer', () {
    testWidgets('asks the school question, keeps the answer', (tester) async {
      final h = await boot(tester);
      await pumpApp(
        tester,
        h,
        AppRoutes.prayerSetup,
        size: const Size(390, 3600),
      );
      await tester.tap(find.text('Islam'));
      await settle(tester);
      expect(
        find.text('WHICH SCHOOL OF PRAYER DO YOU FOLLOW?'),
        findsOneWidget,
      );
      expect(find.text('Hanafi'), findsOneWidget);
      expect(find.text('Jafari (Shia)'), findsOneWidget);
      expect(find.text('Not sure'), findsOneWidget);
      // Unasked: the five, no Witr ticked yet; each practice has its hint.
      expect(find.textContaining('4 rak\'at · fard'), findsWidgets);
      await tester.tap(find.text('Hanafi'));
      await settle(tester);
      await captureScreen(tester, 'prayer_trad_setup_islam_hanafi');
      await tester.tap(find.text('Manual'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);

      final prefs = h.read(prayerPrefsProvider);
      expect(prefs.schoolOf('islam'), 'hanafi');
      expect(prefs.asrSchool, 'hanafi'); // the Hanafi shadow
      final list = (await tester.runAsync(
        () => h
            .read(prayersRepositoryProvider)
            .watchPrayers(PrayersScope.active)
            .first,
      ))!;
      expect(list.map((p) => p.name), contains('Witr'));
      expect(list.map((p) => p.name), isNot(contains('Awwabin'))); // optional
    });

    testWidgets('Judaism asks "Which movement?"', (tester) async {
      final h = await boot(tester);
      await pumpApp(
        tester,
        h,
        AppRoutes.prayerSetup,
        size: const Size(390, 3600),
      );
      await tester.tap(find.text('Judaism'));
      await settle(tester);
      expect(find.text('WHICH MOVEMENT?'), findsOneWidget);
      await tester.tap(find.text('Reform or Progressive'));
      await settle(tester);
      await captureScreen(tester, 'prayer_trad_setup_judaism_reform');
      // Reform: Shacharit is an option, candle lighting is ticked.
      expect(find.textContaining('Optional'), findsWidgets);
      await tester.tap(find.text('Manual'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      final list = (await tester.runAsync(
        () => h
            .read(prayersRepositoryProvider)
            .watchPrayers(PrayersScope.active)
            .first,
      ))!;
      expect(list.map((p) => p.name), contains('Candle lighting'));
      expect(list.map((p) => p.name), isNot(contains('Shacharit')));
      expect(h.read(prayerPrefsProvider).asrSchool, 'standard'); // untouched
    });
  });

  group('the "+" sheet', () {
    Future<void> openSheet(WidgetTester tester, TestHarness h) async {
      await pumpScreen(
        tester,
        h,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showFFBottomSheet<Prayer>(
                  context,
                  builder: (_) => const PrayerAddSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        size: const Size(390, 1800),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('Hinduism: the stream, then puja and japa with hints', (
      tester,
    ) async {
      final h = await boot(tester);
      await openSheet(tester, h);
      await tester.tap(find.text('Hinduism'));
      await settle(tester);
      expect(find.text('WHICH STREAM OF HINDUISM?'), findsOneWidget);
      expect(find.text('Gaudiya (ISKCON)'), findsOneWidget);
      expect(find.text('Morning puja'), findsOneWidget);
      expect(
        find.textContaining('Puja ·'),
        findsWidgets,
      ); // the kind, in its word
      expect(find.textContaining('Japa ·'), findsWidgets);
      await captureScreen(tester, 'prayer_trad_add_hinduism');
      await tester.tap(find.text('Gaudiya (ISKCON)'));
      await settle(tester);
      expect(find.text('Hare Krishna japa'), findsOneWidget);
      expect(h.read(prayerPrefsProvider).schoolOf('hinduism'), 'gaudiya');
    });

    testWidgets('Buddhism: Sitting and Chanting, no "prayer"', (tester) async {
      final h = await boot(tester);
      await openSheet(tester, h);
      await tester.tap(find.text('Buddhism'));
      await settle(tester);
      expect(find.text('WHICH SCHOOL OF BUDDHISM?'), findsOneWidget);
      expect(find.text('Morning sit'), findsOneWidget);
      expect(find.textContaining('Sitting ·'), findsWidgets);
      expect(find.textContaining('Salah'), findsNothing);
      await captureScreen(tester, 'prayer_trad_add_buddhism');
    });
  });

  group('the editor', () {
    testWidgets('Islam: Fard, Sunnah, jamaat, Suhoor and Iftar', (
      tester,
    ) async {
      final h = await boot(tester);
      await editor(tester, h, preset(PrayerTradition.islam, 'Fajr'));
      expect(find.text('New prayer'), findsOneWidget);
      for (final w in ['Fard', 'Sunnah and nafl', 'Dhikr', 'Quran', 'Fast']) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
      expect(find.text('Auto (sun)'), findsWidgets);
      expect(find.text('JAMAAT (CONGREGATION)'), findsOneWidget);
      await captureScreen(tester, 'prayer_trad_editor_islam');
      await tester.tap(find.text('Fast'));
      await settle(tester);
      expect(find.text('STARTS (SUHOOR ENDS)'), findsOneWidget);
      expect(find.text('ENDS (IFTAR)'), findsOneWidget);
    });

    testWidgets('Judaism: Tefillah, zmanim and the minyan', (tester) async {
      final h = await boot(tester);
      await editor(tester, h, preset(PrayerTradition.judaism, 'Shacharit'));
      expect(find.text('New practice'), findsOneWidget);
      for (final w in ['Tefillah', 'Study', 'Observance', 'Counted', 'Fast']) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
      expect(find.text('Salah'), findsNothing);
      expect(find.text('Zmanim'), findsWidgets);
      expect(find.text('Halachic time'), findsWidgets);
      expect(
        find.text('Latest morning prayer (sof zman Tefillah)'),
        findsOneWidget,
      );
      expect(find.text('MINYAN (QUORUM OF TEN)'), findsOneWidget);
      await captureScreen(tester, 'prayer_trad_editor_judaism');
      // A fast: from alot to tzeit, in plain words.
      await tester.tap(find.text('Fast'));
      await settle(tester);
      expect(find.text('FAST BEGINS'), findsOneWidget);
      expect(find.text('FAST ENDS'), findsOneWidget);
      expect(find.text('Reminder before the fast ends'), findsOneWidget);
      expect(find.textContaining('Iftar'), findsNothing);
      await captureScreen(tester, 'prayer_trad_editor_judaism_fast');
    });

    testWidgets('Hinduism: Japa with a mala of 108, parana for a vrata', (
      tester,
    ) async {
      final h = await boot(tester);
      await editor(tester, h, preset(PrayerTradition.hinduism, 'Mala japa'));
      expect(find.text('Japa'), findsWidgets);
      expect(find.text('108'), findsOneWidget); // the daily goal
      expect(
        find.text('SATSANG OR AARTI TIME'),
        findsNothing,
      ); // a count has none
      await captureScreen(tester, 'prayer_trad_editor_hinduism');
      await tester.tap(find.text('Vrata'));
      await settle(tester);
      expect(find.text('ENDS (PARANA)'), findsOneWidget);
      expect(find.text('Parana reminder'), findsOneWidget);
    });

    testWidgets('Buddhism: a 20-minute sit with its Length', (tester) async {
      final h = await boot(tester);
      await editor(
        tester,
        h,
        // Fixed times: the sit is 5:30 – 5:50.
        PrayerPresets.manual([
          preset(PrayerTradition.buddhism, 'Morning sit'),
        ]).single,
      );
      for (final w in [
        'Sitting',
        'Chanting',
        'Mala',
        'Offering',
        'Observance',
      ]) {
        expect(find.text(w), findsWidgets, reason: w);
      }
      expect(find.text('Salah'), findsNothing);
      expect(find.text('JAMAAT (CONGREGATION)'), findsNothing);
      expect(find.text('SANGHA OR GROUP PRACTICE TIME'), findsOneWidget);
      expect(find.text('Length'), findsOneWidget);
      expect(find.text('20 min'), findsWidgets); // the row and the preview
      await captureScreen(tester, 'prayer_trad_editor_buddhism');
      // Change the length: the end moves, the start stays.
      await tester.tap(find.text('Length'));
      await settle(tester);
      await tester.tap(find.text('45 min'));
      await settle(tester);
      expect(find.text('45 min'), findsWidgets);
    });

    testWidgets('Christianity: the Rosary on its beads', (tester) async {
      final h = await boot(tester);
      await editor(
        tester,
        h,
        preset(
          PrayerTradition.christianity,
          'Rosary',
          school: PrayerSchool.catholic,
        ),
      );
      expect(find.text('Beads'), findsOneWidget);
      expect(find.text('Silent prayer'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      await captureScreen(tester, 'prayer_trad_editor_christianity');
    });
  });
}
