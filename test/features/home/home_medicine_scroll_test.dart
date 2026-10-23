/// Repro: Home and the Medicines list with many doses, flung down and back
/// up repeatedly. Must not throw, must not keep rebuilding, and must scroll
/// back to the top.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';
import 'home_seed.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<TestHarness> seeded(WidgetTester tester) async {
    final h = (await tester.runAsync(() => TestHarness.create(now: homeNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() async {
      await seedHomeMockup(h);
      final repo = h.read(medicinesRepositoryProvider);
      for (var i = 0; i < 6; i++) {
        await repo.save(
          Medicine.draft(startDate: homeToday, name: 'Medicine $i').copyWith(
            doses: [
              DoseTime(7 * 60 + i),
              DoseTime(12 * 60 + i),
              DoseTime(18 * 60 + i),
              DoseTime(22 * 60 + i),
            ],
          ),
        );
      }
    });
    return h;
  }

  Future<void> flingAround(WidgetTester tester, Finder list) async {
    for (var i = 0; i < 4; i++) {
      await tester.fling(list, const Offset(0, -3000), 5000);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.fling(list, const Offset(0, 3000), 5000);
      await settle(tester);
      expect(tester.takeException(), isNull);
    }
    expect(tester.state<ScrollableState>(list).position.pixels, 0);
    // Idle: nothing keeps scheduling frames.
    await tester.pump(const Duration(seconds: 2));
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
  }

  testWidgets('Home: Medicine section scrolls in and out', (tester) async {
    final h = await seeded(tester);
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 844));
    await settle(tester, rounds: 6);
    await flingAround(tester, find.byType(Scrollable).first);
  });

  testWidgets('Medicines list: long day scrolls smoothly', (tester) async {
    final h = await seeded(tester);
    await pumpApp(tester, h, AppRoutes.medicines, size: const Size(390, 844));
    await settle(tester, rounds: 6);
    await flingAround(tester, find.byType(Scrollable).first);
  });
}
