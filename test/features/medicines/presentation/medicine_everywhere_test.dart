/// Medicines beyond their own screens: Insights › Medicine (every chart,
/// Daily / Monthly / Yearly), the Home "Medicine" section (only with
/// medicines; TAKEN from Home), and the Calendar agenda — light and dark,
/// no overflow at 360 pt / text 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

final _now = DateTime(2026, 10, 23, 8, 30);

/// Metformin 08:00 + 20:00 since Oct 10 (mostly taken, some late, a few
/// missed / skipped) and Vitamin D3 09:00 since Oct 15.
Future<String> _seed(MedicinesRepository repo, FakeClockSetter setClock) async {
  final metformin = await repo.save(
    Medicine.draft(
      startDate: DateTime(2026, 10, 10),
      name: 'Metformin',
    ).copyWith(
      strength: '500 mg',
      doses: const [DoseTime(8 * 60), DoseTime(20 * 60)],
    ),
  );
  await repo.save(
    Medicine.draft(
      startDate: DateTime(2026, 10, 15),
      name: 'Vitamin D3',
    ).copyWith(form: MedicineForm.capsule, doses: const [DoseTime(9 * 60)]),
  );
  for (var d = 10; d <= 22; d++) {
    final day = DateTime(2026, 10, d);
    // Morning on time, evening 2 h late on Mondays (19th), missed on 21st.
    setClock(DateTime(2026, 10, d, 8, 5));
    await repo.markTaken(metformin, day, 480);
    if (d == 21) continue;
    setClock(DateTime(2026, 10, d, d == 19 ? 22 : 20, 10));
    if (d == 16) {
      await repo.markSkipped(metformin, day, 1200);
    } else {
      await repo.markTaken(metformin, day, 1200);
    }
  }
  setClock(_now);
  return metformin;
}

typedef FakeClockSetter = void Function(DateTime);

void main() {
  setUpAll(loadAppFonts);

  late TestHarness h;
  late MedicinesRepository repo;

  setUp(() async {
    h = await TestHarness.create(now: _now);
    repo = h.read(medicinesRepositoryProvider);
  });

  tearDown(() => h.dispose());

  Future<void> seed(WidgetTester tester) =>
      tester.runAsync(() => _seed(repo, h.clock.set));

  testWidgets('Insights › Medicine shows every chart for each period', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.insights, size: const Size(390, 2600));
    await tester.tap(find.text('Medicine'));
    await settle(tester, rounds: 8);
    await captureScreen(tester, 'medicine_insights_daily');
    expect(find.text('Your medicines at a glance'), findsOneWidget);
    for (final title in [
      'Dose outcomes',
      'Doses by day',
      'Adherence trend',
      'Your days at a glance',
      'When you take them',
      'By medicine',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }

    await tester.tap(find.text('Monthly'));
    await settle(tester, rounds: 8);
    expect(find.text('Doses by day'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    // The yearly pass runs on a background isolate.
    for (var i = 0; i < 4; i++) {
      await settle(tester, rounds: 6);
    }
    expect(find.text('Doses by month'), findsOneWidget);
    await captureScreen(tester, 'medicine_insights_yearly');

    // Back to the overview.
    await tester.tap(find.text('Overview'));
    await settle(tester);
    expect(find.text('Your productivity at a glance'), findsOneWidget);
  });

  testWidgets('Home shows Medicine only with medicines; TAKEN works', (
    tester,
  ) async {
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 2200));
    expect(find.text('Medicine'), findsNothing);
    final id = await tester.runAsync(
      () => repo.save(
        Medicine.draft(
          startDate: DateTime(2026, 10, 23),
          name: 'Metformin',
        ).copyWith(doses: const [DoseTime(8 * 60), DoseTime(20 * 60)]),
      ),
    );
    await settle(tester, rounds: 6);
    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('0 of 2 doses taken'), findsOneWidget);
    await captureScreen(tester, 'medicine_home');
    await tester.tap(find.text('TAKEN'));
    await settle(tester, rounds: 6);
    expect(find.text('1 of 2 doses taken'), findsOneWidget);
    final log = await tester.runAsync(
      () => repo.doseLog(id!, DateTime(2026, 10, 23), 480),
    );
    expect(log?.isTaken, isTrue);
  });

  testWidgets('Calendar agenda lists the day\'s doses', (tester) async {
    await seed(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.calendarOn(DateTime(2026, 10, 22)),
      size: const Size(390, 2200),
    );
    expect(find.text('Metformin'), findsWidgets);
    expect(find.textContaining('Medicine · 1 tablet · taken'), findsWidgets);
    await captureScreen(tester, 'medicine_calendar');
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360 pt / 1.3 (dark: $dark)', (tester) async {
      await seed(tester);
      await pumpApp(
        tester,
        h,
        AppRoutes.insights,
        size: const Size(360, 2400),
        textScale: 1.3,
        dark: dark,
      );
      await tester.tap(find.text('Medicine'));
      await settle(tester, rounds: 8);
      expect(tester.takeException(), isNull);
      await captureScreen(
        tester,
        'medicine_insights_360_${dark ? 'dark' : 'light'}',
      );
      for (final route in [AppRoutes.home, AppRoutes.calendar]) {
        await pumpApp(
          tester,
          h,
          route,
          size: const Size(360, 800),
          textScale: 1.3,
          dark: dark,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
}
