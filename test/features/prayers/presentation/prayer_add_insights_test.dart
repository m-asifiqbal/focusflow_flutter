/// The Prayer tab's "+" sheet (tradition first, then one of its prayers or
/// "Create your own"; the editor opens pre-filled) and Insights › Prayer
/// (KPIs and every card with history; light / dark / 360 pt at text 1.3
/// captures; the "Set up Prayer" empty state).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/providers/insights_providers.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_editor_screen.dart';
import 'package:focusflow/features/prayers/presentation/widgets/insights/prayer_insights_view.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_add_sheet.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

/// Sun 1 Nov 2026, 3:50 PM — Asr is open (fixed windows, no location).
final _now = DateTime(2026, 11, 1, 15, 50);
final _day = DateTime(2026, 11, 1);

const _islam = PrayerPrefs(tradition: 'islam', discreet: false);

void main() {
  Future<TestHarness> boot(WidgetTester tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  /// The 5 daily prayers as fixed times, added two weeks ago, with a week
  /// of history (one late Fajr, one missed Isha, two in congregation).
  Future<void> seed(WidgetTester tester, TestHarness h) async {
    await tester.runAsync(() async {
      await h.updateSettings((s) => s.copyWith(prayer: _islam));
      final repo = h.read(prayersRepositoryProvider);
      final core = [
        for (final p in PrayerPresets.of(PrayerTradition.islam, _now))
          if (p.core && p.draft.kind == PrayerKind.salah) p.draft,
      ];
      h.clock.set(_now.subtract(const Duration(days: 14)));
      await repo.addAll(PrayerPresets.manual(core));
      h.clock.set(_now);
      final list = await repo.watchPrayers(PrayersScope.active).first;
      for (var d = 1; d <= 6; d++) {
        final day = _day.subtract(Duration(days: d));
        for (final p in list) {
          if (d == 2 && p.name == 'Isha') continue;
          await repo.mark(
            p.id,
            day,
            d == 3 && p.name == 'Fajr'
                ? PrayerStatus.late
                : PrayerStatus.onTime,
            congregation: d == 1 && p.name != 'Fajr',
            place: d == 1 ? 'Mosque' : null,
          );
        }
      }
      await repo.mark(list.first.id, _day, PrayerStatus.onTime);
    });
  }

  testWidgets('+ asks for a tradition, then a prayer, then edits it', (
    tester,
  ) async {
    final h = await boot(tester);
    await seed(tester, h);
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1000));
    await tester.tap(find.bySemanticsLabel('Add prayer'));
    await settle(tester);
    expect(find.byType(PrayerAddSheet), findsOneWidget);
    expect(find.text('Choose a tradition'), findsOneWidget);
    expect(find.text('Christianity'), findsOneWidget);
    await captureScreen(tester, 'prayer_add_traditions');

    // Islam: the five already there say "Added"; extras can be picked.
    await tester.tap(find.text('Islam'));
    await settle(tester);
    expect(find.textContaining('· Added'), findsNWidgets(5));
    expect(find.text('Tahajjud'), findsOneWidget);
    expect(find.text('Create your own'), findsOneWidget);
    await captureScreen(tester, 'prayer_add_islam');

    // Back, then Christianity → its morning prayer opens in the editor.
    await tester.tap(find.bySemanticsLabel('Back to traditions'));
    await settle(tester);
    await tester.tap(find.text('Christianity'));
    await settle(tester);
    await tester.tap(find.text('Morning prayer'));
    await settle(tester);
    expect(find.byType(PrayerEditorScreen), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'Morning prayer');
    await tester.tap(find.text('Save').last);
    await settle(tester);
    final list = (await tester.runAsync(
      () => h
          .read(prayersRepositoryProvider)
          .watchPrayers(PrayersScope.active)
          .first,
    ))!;
    final added = list.firstWhere((p) => p.name == 'Morning prayer');
    expect(added.tradition, PrayerTradition.christianity);
    // The user's prayers are set by hand, so the new one is too.
    expect(added.usesSun, isFalse);
  });

  testWidgets('"Create your own" opens a blank prayer of that tradition', (
    tester,
  ) async {
    final h = await boot(tester);
    await seed(tester, h);
    await pumpApp(tester, h, AppRoutes.prayers, size: const Size(390, 1000));
    await tester.tap(find.bySemanticsLabel('Add prayer'));
    await settle(tester);
    await tester.tap(find.text('Buddhism'));
    await settle(tester);
    await tester.tap(find.text('Create your own'));
    await settle(tester);
    expect(find.byType(PrayerEditorScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField).first, 'Metta');
    await tester.tap(find.text('Save').last);
    await settle(tester);
    final list = (await tester.runAsync(
      () => h
          .read(prayersRepositoryProvider)
          .watchPrayers(PrayersScope.active)
          .first,
    ))!;
    final metta = list.firstWhere((p) => p.name == 'Metta');
    expect(metta.tradition, PrayerTradition.buddhism);
    expect(metta.kind, PrayerKind.custom);
  });

  Future<void> openPrayerInsights(
    WidgetTester tester,
    TestHarness h, {
    Size size = const Size(390, 2400),
    bool dark = false,
    double textScale = 1,
  }) async {
    h.read(insightsViewProvider.notifier).select(InsightsView.prayer);
    await pumpApp(
      tester,
      h,
      AppRoutes.insights,
      size: size,
      dark: dark,
      textScale: textScale,
    );
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
  }

  testWidgets('Insights › Prayer: KPIs and every card (captures)', (
    tester,
  ) async {
    final h = await boot(tester);
    await seed(tester, h);
    await openPrayerInsights(tester, h);
    expect(find.byType(PrayerInsightsView), findsOneWidget);
    expect(find.text('Your prayers at a glance'), findsOneWidget);
    // The Overview | Medicine | Prayer switch shows Prayer selected.
    expect(
      find.descendant(
        of: find.byType(FFSegmented<InsightsView>),
        matching: find.text('Prayer'),
      ),
      findsOneWidget,
    );
    for (final title in [
      'PRAYED',
      'BEST STREAK',
      'COMPLETE DAYS',
      'Prayer outcomes',
      'Prayers by day',
      'By prayer',
      'Your practice',
      'In congregation',
      'Where you prayed',
      'Mosque',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    await captureScreen(tester, 'insights_prayer');

    await tester.tap(find.text('Yearly'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Prayers by month'), findsOneWidget);

    await openPrayerInsights(tester, h, dark: true);
    await captureScreen(tester, 'insights_prayer_dark');
    expect(tester.takeException(), isNull);

    await openPrayerInsights(
      tester,
      h,
      size: const Size(360, 2800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, 'insights_prayer_360_x13');
  });

  testWidgets('Insights › Prayer before setup invites to set it up', (
    tester,
  ) async {
    final h = await boot(tester);
    await openPrayerInsights(tester, h, size: const Size(390, 900));
    expect(find.text('Set up Prayer'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    expect(find.text('Choose a tradition'), findsNothing);
    expect(find.text('Islam'), findsOneWidget);
  });
}
