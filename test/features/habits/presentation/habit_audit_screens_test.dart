/// Screens 14 + 16 after the habits audit: a quit habit without logs shows
/// its stats; N× per week streaks read "weeks" on the card and the stat
/// grid (and a met quota is "Week goal met", not due); the heatmap and the
/// week squares draw rest days distinctly; history times follow Settings ›
/// 24-hour time; reorder mode drags within the pinned / other group.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_heatmap.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_week_squares.dart';
import 'package:focusflow/features/habits/presentation/widgets/habits_list_body.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../habits_seed.dart';

const _tall = Size(390, 1400);

void main() {
  late TestHarness h;
  final today = DateUtilsX.dateOnly(mockupNow); // Friday 12 June 2026

  Future<HabitsRepository> setUp(WidgetTester tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(() => TestHarness.create(now: mockupNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h.read(habitsRepositoryProvider);
  }

  /// 3× per week since Mon 25 May; every week's quota met by Wednesday.
  Future<String> seedWeekly(WidgetTester tester, HabitsRepository repo) async =>
      (await tester.runAsync(() async {
        final id = await repo.save(
          Habit.draft(
            startDate: DateTime(2026, 5, 25),
            name: 'Swim',
            frequency: const HabitFrequency.timesPerWeek(3),
          ),
        );
        for (final start in [25, 32, 39]) {
          for (var i = 0; i < 3; i++) {
            await repo.setLog(id, DateTime(2026, 5, start + i), count: 1);
          }
        }
        return id;
      }))!;

  testWidgets('quit habit without any log shows its stats', (tester) async {
    final repo = await setUp(tester);
    final id = (await tester.runAsync(
      () => repo.save(
        Habit.draft(
          startDate: DateUtilsX.addDays(today, -8),
          name: 'No sugar',
          kind: HabitKind.quit,
          unit: 'slips',
        ),
      ),
    ))!;
    await pumpApp(tester, h, AppRoutes.habit(id), size: _tall);
    expect(find.text('No check-ins yet'), findsNothing);
    expect(find.text('Consistency'), findsOneWidget);
    // 9 clean days (start … today), 100 % clean.
    expect(find.text('9', findRichText: true), findsWidgets);
    expect(find.text('100%', findRichText: true), findsWidgets);
    expect(find.text('clean days'), findsOneWidget);
    expect(find.text('No slips logged yet'), findsOneWidget);
  });

  testWidgets('quit habit starting tomorrow is still empty', (tester) async {
    final repo = await setUp(tester);
    final id = (await tester.runAsync(
      () => repo.save(
        Habit.draft(
          startDate: DateUtilsX.addDays(today, 1),
          name: 'No soda',
          kind: HabitKind.quit,
        ),
      ),
    ))!;
    await pumpApp(tester, h, AppRoutes.habit(id), size: _tall);
    expect(find.text('Not started yet'), findsOneWidget);
    expect(find.text('Consistency'), findsNothing);
  });

  testWidgets('weekly habit: streak in weeks on the stat grid', (tester) async {
    final repo = await setUp(tester);
    final id = await seedWeekly(tester, repo);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _tall);
    expect(find.text('weeks'), findsNWidgets(2)); // current + best
    expect(find.text('days'), findsNothing);
    expect(find.bySemanticsLabel('Current streak: 3 weeks'), findsOneWidget);
  });

  testWidgets('weekly habit card: "3 weeks", quota met = not due today', (
    tester,
  ) async {
    final repo = await setUp(tester);
    await seedWeekly(tester, repo);
    await pumpApp(tester, h, AppRoutes.habits, size: _tall);
    final card = find.byType(HabitCard);
    expect(
      find.descendant(of: card, matching: find.text('3 weeks')),
      findsOneWidget,
    );
    expect(find.text('Week goal met'), findsOneWidget);
    expect(find.text('Nothing due today'), findsOneWidget);
    // Thu–Sun of this week are rest days in the squares.
    final squares = tester.widget<HabitWeekSquares>(
      find.byType(HabitWeekSquares),
    );
    expect(squares.week.map(HabitWeekSquares.kindOf).toList(), [
      HabitSquareKind.done,
      HabitSquareKind.done,
      HabitSquareKind.done,
      HabitSquareKind.rest,
      HabitSquareKind.rest,
      HabitSquareKind.rest,
      HabitSquareKind.rest,
    ]);
    expect(
      HabitWeekSquares.semanticsFor(squares.week),
      'This week: done Mon, Tue, Wed; rest days Thu, Fri, Sat, Sun',
    );
  });

  testWidgets('week squares: rest days are outlined, misses filled', (
    tester,
  ) async {
    final repo = await setUp(tester);
    await tester.runAsync(() => seedMockupHabits(repo));
    await pumpApp(tester, h, AppRoutes.habits, size: _tall);
    // Gym workout (Mon · Wed · Fri): Tue, Thu, Sat, Sun are rest days.
    final gymCard = find.ancestor(
      of: find.text('Gym workout'),
      matching: find.byType(HabitCard),
    );
    final status = tester.widget<HabitCard>(gymCard).status;
    expect(
      [for (final c in status.week) HabitWeekSquares.kindOf(c)],
      [
        HabitSquareKind.done,
        HabitSquareKind.rest,
        HabitSquareKind.done,
        HabitSquareKind.rest,
        HabitSquareKind.open, // today, not done yet
        HabitSquareKind.rest,
        HabitSquareKind.rest,
      ],
    );
    final outlined = find.descendant(
      of: find.descendant(of: gymCard, matching: find.byType(HabitWeekSquares)),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      ),
    );
    expect(outlined, findsNWidgets(4));
  });

  testWidgets('heatmap draws rest days distinctly + legend', (tester) async {
    final repo = await setUp(tester);
    final ids = await tester.runAsync(() => seedMockupHabits(repo));
    await pumpApp(
      tester,
      h,
      AppRoutes.habit(ids!['Gym workout']!),
      size: _tall,
    );
    expect(find.text('Rest day'), findsOneWidget);
    final map = tester.widget<HabitHeatmap>(find.byType(HabitHeatmap));
    final tue = DateTime(2026, 6, 9);
    final wed = DateTime(2026, 6, 10);
    final missedMon = DateTime(2026, 4, 20); // before the 49 logged days
    expect(map.isRestCell(tue), isTrue);
    expect(map.isRestCell(wed), isFalse);
    expect(map.levelOf(wed), 3);
    expect(map.isRestCell(missedMon), isFalse);
    expect(map.levelOf(missedMon), 0); // a miss stays a (faint) miss
  });

  testWidgets('history times follow Settings › 24-hour time', (tester) async {
    final repo = await setUp(tester);
    final ids = await tester.runAsync(() => seedMockupHabits(repo));
    final id = ids!['Read 20 pages']!;
    await pumpApp(tester, h, AppRoutes.habit(id), size: _tall);
    expect(find.text('Done at 9:41 AM'), findsWidgets);

    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(use24HourTime: true)),
    );
    await settle(tester);
    expect(find.text('Done at 09:41'), findsWidgets);
    expect(find.text('Done at 9:41 AM'), findsNothing);
  });

  testWidgets('reorder mode scopes dragging to pinned / other habits', (
    tester,
  ) async {
    final repo = await setUp(tester);
    final ids = await tester.runAsync(() => seedMockupHabits(repo));
    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).setPinned([
        ItemRef(ItemType.habit, ids!['Meditate']!),
      ], true),
    );
    await pumpApp(tester, h, AppRoutes.habits, size: _tall);
    await tester.tap(find.bySemanticsLabel('More options'));
    await settle(tester);
    await tester.tap(find.text('Reorder habits'));
    await settle(tester);

    final groups = tester
        .widgetList<HabitReorderGroup>(find.byType(HabitReorderGroup))
        .toList();
    expect(groups, hasLength(2));
    List<String> names(HabitReorderGroup g) => [
      for (final HabitDayStatus s in g.list) s.habit.name,
    ];
    expect(names(groups.first), ['Meditate']);
    expect(names(groups.last), hasLength(4));
    expect(names(groups.last), isNot(contains('Meditate')));
    expect(find.text('PINNED'), findsOneWidget);
    expect(find.text('OTHER HABITS'), findsOneWidget);
  });
}
