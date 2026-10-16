/// Screen 14 — Habits list: mockup data renders (light + dark captures),
/// check-in updates live, chips filter, empty state, long-press actions,
/// no overflow at 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_check_button.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../habits_seed.dart';

/// The mockup PNG is 1170×3420 (390×1140 pt).
const _mockupTall = Size(390, 1140);

void main() {
  late TestHarness h;

  Future<void> seed(WidgetTester tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(() => TestHarness.create(now: mockupNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(
      () => seedMockupHabits(h.read(habitsRepositoryProvider)),
    );
  }

  testWidgets('renders the mockup data (light)', (tester) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall);

    expect(find.text('Habits'), findsWidgets);
    expect(find.text('2 of 5 done today'), findsOneWidget);
    expect(find.text('Keep the chain going!'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    for (final chip in ['Today', 'All habits', 'Morning', 'Evening']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('Drink Water'), findsOneWidget);
    expect(find.text('6 / 8 glasses'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('5 / 10 min'), findsOneWidget);
    expect(find.text('Mon · Wed · Fri'), findsOneWidget);
    expect(find.textContaining('Quit habit · day'), findsOneWidget);
    expect(find.byType(HabitCard), findsNWidgets(5));
    await captureScreen(tester, '14_habits_list');
  });

  testWidgets('dark mode capture', (tester) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall, dark: true);
    expect(find.byType(HabitCard), findsNWidgets(5));
    await captureScreen(tester, '14_habits_list_dark');
  });

  testWidgets('tapping + checks in and updates header + card', (tester) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall);
    await tester.tap(find.byType(HabitCheckButton).first);
    await settle(tester);
    expect(find.text('7 / 8 glasses'), findsOneWidget);
    await tester.tap(find.byType(HabitCheckButton).first);
    await settle(tester);
    expect(find.text('Completed'), findsNWidgets(2));
    expect(find.text('3 of 5 done today'), findsOneWidget);
  });

  testWidgets('amount sheet: Clear today offers Undo back to 6/8', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall);
    await tester.longPress(find.byType(HabitCheckButton).first);
    await settle(tester);
    await tester.tap(find.text('Clear today'));
    await settle(tester);
    expect(find.text('0 / 8 glasses'), findsOneWidget);
    expect(find.text('Cleared today · "Drink Water"'), findsOneWidget);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect(find.text('6 / 8 glasses'), findsOneWidget);
  });

  testWidgets('chips filter by part of day', (tester) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall);
    await tester.tap(find.text('Morning'));
    await settle(tester);
    expect(find.byType(HabitCard), findsNWidgets(2));
    await tester.tap(find.text('Evening'));
    await settle(tester);
    // Evening includes afternoon habits.
    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(find.text('Gym workout'), findsOneWidget);
    expect(find.text('Drink Water'), findsNothing);
  });

  testWidgets('long-press opens the actions sheet with habit rows', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall);
    await tester.longPress(find.text('Meditate'));
    await settle(tester);
    expect(find.text('Log today'), findsOneWidget);
    expect(find.text('Pause habit'), findsOneWidget);
    await tester.tap(find.text('Log today'));
    await settle(tester);
    expect(find.text('6 / 10 min'), findsOneWidget);
  });

  testWidgets('empty state without habits', (tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(() => TestHarness.create(now: mockupNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpApp(tester, h, AppRoutes.habits);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('Keep the chain going!'), findsNothing);
    await captureScreen(tester, '14_habits_list_empty');
  });

  testWidgets('archived chip lists archived habits only', (tester) async {
    await seed(tester);
    await pumpApp(tester, h, AppRoutes.habits, size: _mockupTall);
    await tester.drag(find.text('Evening'), const Offset(-300, 0));
    await settle(tester);
    await tester.tap(find.text('Archived'));
    await settle(tester);
    expect(find.text('No archived habits'), findsOneWidget);
    expect(HabitsScope.archived.name, 'archived');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await seed(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.habits,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '14_habits_list_360_scale130');
  });
}
