/// Screen 15 — Habit editor: mockup state (Drink Water template) renders in
/// light + dark, Create saves a habit, edit mode loads the habit and shows
/// Manage, weekday circles edit the schedule, no overflow at 360 pt / 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_templates.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../habits_seed.dart';

/// The mockup PNG is 1170×3408 (390×1136 pt).
const _mockupTall = Size(390, 1136);
const HabitEditorArgs _newArgs = (id: null, name: null);

/// The page's vertical scrollable (the templates row scrolls sideways).
final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  late TestHarness h;

  Future<void> setUp(WidgetTester tester, {bool seed = false}) async {
    await loadAppFonts();
    h = (await tester.runAsync(() => TestHarness.create(now: mockupNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
  }

  HabitEditorController controller() =>
      h.read(habitEditorControllerProvider(_newArgs).notifier);

  Future<void> applyWater(WidgetTester tester) async {
    controller().applyTemplate(
      HabitTemplates.all.firstWhere((t) => t.label == 'Drink water'),
    );
    await settle(tester);
  }

  testWidgets('new habit: mockup state (light)', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.newHabit(), size: _mockupTall);
    expect(find.text('New Habit'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    await applyWater(tester);

    expect(find.text('Drink Water'), findsNWidgets(2));
    expect(find.text('8 glasses daily'), findsOneWidget);
    for (final t in ['Meditate', 'Read', 'Exercise', 'Sleep']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('9:00 · 13:00 · 17:00'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.bySemanticsLabel('Monday'), findsOneWidget);
    await captureScreen(tester, '15_habit_editor');
  });

  testWidgets('new habit: dark capture', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.newHabit(),
      size: _mockupTall,
      dark: true,
    );
    await applyWater(tester);
    await captureScreen(tester, '15_habit_editor_dark');
  });

  testWidgets('Create saves the draft and leaves', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.newHabit(name: 'Stretch'));
    expect(find.text('Stretch'), findsWidgets);
    // Weekday circle toggles the schedule (Saturday off → specific days).
    await tester.ensureVisible(find.bySemanticsLabel('Saturday'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Saturday'));
    await settle(tester);
    expect(
      h
          .read(habitEditorControllerProvider((id: null, name: 'Stretch')))
          .value!
          .draft
          .frequency,
      HabitFrequency.onWeekdays([1, 2, 3, 4, 5, 7]),
    );
    await tester.tap(find.text('Create'));
    await settle(tester);
    final habits = await tester.runAsync(
      () => h
          .read(habitsRepositoryProvider)
          .watchHabits(const HabitsQuery())
          .first,
    );
    expect(habits!.single.name, 'Stretch');
    expect(find.text('New Habit'), findsNothing);
  });

  testWidgets('time of day row; quit hides the schedule; 44-pt day slots', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.newHabit(name: 'Walk'));
    final monday = find.bySemanticsLabel('Monday');
    await tester.ensureVisible(monday);
    await settle(tester);
    expect(tester.getSize(monday).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(monday).height, greaterThanOrEqualTo(44));

    await tester.ensureVisible(find.text('Time of day'));
    await settle(tester);
    expect(find.text('Anytime'), findsOneWidget);
    await tester.tap(find.text('Time of day'));
    await settle(tester);
    await tester.tap(find.text('Evening').last);
    await settle(tester);
    expect(
      h
          .read(habitEditorControllerProvider((id: null, name: 'Walk')))
          .value!
          .draft
          .partOfDay,
      PartOfDay.evening,
    );

    h
        .read(habitEditorControllerProvider((id: null, name: 'Walk')).notifier)
        .setKind(HabitKind.quit);
    await settle(tester);
    expect(find.text('Frequency'), findsNothing);
    expect(find.bySemanticsLabel('Monday'), findsNothing);
    expect(find.textContaining('Quit habits count every day'), findsOneWidget);
  });

  testWidgets('edit mode loads the habit and shows Manage', (tester) async {
    await setUp(tester);
    final ids = await tester.runAsync(
      () => seedMockupHabits(h.read(habitsRepositoryProvider)),
    );
    await pumpApp(
      tester,
      h,
      AppRoutes.habitEdit(ids!['Drink Water']!),
      size: _mockupTall,
    );
    expect(find.text('Edit Habit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Quick start'.toUpperCase()), findsNothing);
    await tester.scrollUntilVisible(find.text('Reset history'), 200);
    expect(find.text('Archive habit'), findsOneWidget);
    expect(find.text('Delete habit'), findsOneWidget);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.newHabit(),
      size: const Size(360, 800),
      textScale: 1.3,
    );
    await applyWater(tester);
    expect(tester.takeException(), isNull);
    // The Colour label is never truncated (swatches wrap instead).
    final colour = tester.renderObject<RenderParagraph>(find.text('Colour'));
    expect(colour.didExceedMaxLines, isFalse);
    await tester.scrollUntilVisible(
      find.text('Start date'),
      200,
      scrollable: _vertical,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '15_habit_editor_360_scale130');
  });
}
