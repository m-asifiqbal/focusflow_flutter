/// Screen 03 / 37 — Home: mockup data renders (light + dark captures),
/// sections follow Settings › Home layout, completing a task updates the
/// hero live, the week strip filters the tasks, empty states, no overflow
/// at 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/home/presentation/widgets/home_focus_card.dart';
import 'package:focusflow/features/home/presentation/widgets/home_habits_section.dart';
import 'package:focusflow/features/home/presentation/widgets/home_task_tile.dart';
import 'package:focusflow/features/home/presentation/widgets/home_up_next.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';
import '../home_seed.dart';

/// The mockup PNG is 1170×4614 (390×1538 pt).
const _mockupTall = Size(390, 1538);

void main() {
  late TestHarness h;

  Future<void> boot(WidgetTester tester, {bool seed = true}) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () =>
          TestHarness.create(now: homeNow, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    if (seed) await tester.runAsync(() => seedHomeMockup(h));
  }

  testWidgets('renders the mockup data (light)', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.home, size: _mockupTall);
    await captureScreen(tester, '03_home');

    expect(find.text('TUESDAY, JUNE 13'), findsOneWidget);
    expect(find.text('Good morning, Asif'), findsOneWidget);
    expect(find.text("Today's Focus"), findsOneWidget);
    expect(find.text('57%'), findsOneWidget);
    expect(find.text('4/7'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('June 2023'), findsOneWidget);
    expect(find.text('Call the bank about card'), findsOneWidget);
    expect(find.text('in 25 min · 10:00 AM'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);
    expect(find.text("Today's Tasks"), findsOneWidget);
    expect(find.text('3 LEFT'), findsOneWidget);
    expect(find.text('Review FocusFlow Q3 Strategy'), findsOneWidget);
    expect(find.byType(HomeTaskTile), findsNWidgets(5));
    expect(find.text('View all 7 tasks'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Notifications, 1 unread, new'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Meditate'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Mobile App Design Trends'), findsOneWidget);
    expect(find.text('Weekend Shopping'), findsOneWidget);
    for (final n in ['Water', 'Reading', 'Gym', 'Meditate']) {
      expect(find.text(n), findsOneWidget);
    }
    await captureScreen(tester, '03_home_bottom');
  });

  testWidgets('dark mode capture', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.home, size: _mockupTall, dark: true);
    expect(find.byType(HomeFocusCard), findsOneWidget);
    await captureScreen(tester, '37_home_dark');
  });

  testWidgets('completing a task updates the hero live', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.home, size: _mockupTall);
    await tester.tap(find.bySemanticsLabel('Complete Design Home Screen v2'));
    await settle(tester);
    expect(find.text('5/7'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);
    expect(find.text('2 LEFT'), findsOneWidget);
    expect(find.textContaining('completed'), findsWidgets);
  });

  testWidgets('week strip filters the tasks to the picked day', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.home, size: _mockupTall);
    await tester.tap(find.text('15'));
    await settle(tester);
    expect(find.text('Tasks · Thu, Jun 15'), findsOneWidget);
    expect(find.text('Book dentist'), findsOneWidget);
    expect(find.byType(HomeTaskTile), findsOneWidget);
    expect(find.text('No reminders this day'), findsOneWidget);
  });

  testWidgets('sections follow Settings › Home layout', (tester) async {
    await boot(tester);
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          homeSections: [
            HomeSection.habits,
            ...HomeSection.values.where((x) => x != HomeSection.habits),
          ],
          hiddenHomeSections: {HomeSection.upNext},
        ),
      ),
    );
    await pumpApp(tester, h, AppRoutes.home, size: _mockupTall);
    expect(find.byType(HomeUpNextSection), findsNothing);
    final habits = tester.getTopLeft(find.byType(HomeHabitsSection)).dy;
    final hero = tester.getTopLeft(find.byType(HomeFocusCard)).dy;
    expect(habits, lessThan(hero));
  });

  testWidgets('empty library shows get started + empty states', (tester) async {
    await boot(tester, seed: false);
    await pumpApp(tester, h, AppRoutes.home, size: _mockupTall);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Nothing coming up'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await captureScreen(tester, '03_home_empty');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await boot(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.home,
      size: const Size(360, 1700),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '03_home_360_x13');
  });
}
