/// Screen 15 confirmations: picking the other habit type for a habit with
/// history asks to reset it (Cancel keeps everything; confirm resets with
/// an Undo that still works after the editor closed; a save after Undo is
/// blocked by the same question), and a new goal on a habit with history
/// asks "Apply to past days?" before saving. Plus the perfect-day confetti
/// claim persisting across restarts and the 24-hour history clock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/domain/services/habit_history.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../habits_seed.dart';

const _tall = Size(390, 1136);

/// The snackbar's Undo action (label case is the design system's choice).
final Finder _undo = find.textContaining(
  RegExp(r'^undo$', caseSensitive: false),
);

void main() {
  group('editor dialogs', () {
    late TestHarness h;
    late HabitsRepository repo;
    late String id;

    Future<void> open(WidgetTester tester) async {
      await loadAppFonts();
      h = (await tester.runAsync(() => TestHarness.create(now: mockupNow)))!;
      addTearDown(() => tester.runAsync(h.dispose));
      repo = h.read(habitsRepositoryProvider);
      final ids = await tester.runAsync(() => seedMockupHabits(repo));
      id = ids!['Drink Water']!;
      await pumpApp(tester, h, AppRoutes.habitEdit(id), size: _tall);
    }

    HabitEditorArgs args() => (id: id, name: null);

    Future<int> logCount(WidgetTester tester) async => (await tester.runAsync(
      () async => (await repo.watchHabitWithLogs(id).first)!.logs.length,
    ))!;

    Future<void> pickQuit(WidgetTester tester) async {
      await tester.tap(find.text('Habit type'));
      await settle(tester);
      await tester.tap(find.text('Quit (do less)').last);
      await settle(tester);
    }

    testWidgets('type change with history: cancel keeps everything', (
      tester,
    ) async {
      await open(tester);
      final logs = await logCount(tester);
      expect(logs, greaterThan(0));
      await pickQuit(tester);
      expect(find.text('Change habit type?'), findsOneWidget);
      expect(find.textContaining('would turn into slips'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await settle(tester);
      expect(
        h.read(habitEditorControllerProvider(args())).value!.draft.kind,
        HabitKind.build,
      );
      expect(await logCount(tester), logs);
    });

    testWidgets('reset & change; Undo after leaving; save blocked again', (
      tester,
    ) async {
      await open(tester);
      final logs = await logCount(tester);
      await pickQuit(tester);
      await tester.tap(find.text('Reset & change'));
      await settle(tester);
      expect(await logCount(tester), 0);
      expect(
        h.read(habitEditorControllerProvider(args())).value!.draft.kind,
        HabitKind.quit,
      );
      expect(find.text('History of "Drink Water" reset'), findsOneWidget);

      // Undo restores the logs — the type change is now unsafe again, so
      // Save asks the same question instead of saving.
      await tester.tap(_undo);
      await settle(tester);
      expect(await logCount(tester), logs);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Change habit type?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await settle(tester);
      final stored = await tester.runAsync(() => repo.getHabit(id));
      expect(stored!.kind, HabitKind.build);
    });

    testWidgets('Undo of Reset history works after the editor closed', (
      tester,
    ) async {
      await open(tester);
      final logs = await logCount(tester);
      await tester.scrollUntilVisible(find.text('Reset history'), 200);
      await tester.tap(find.text('Reset history'));
      await settle(tester);
      await tester.tap(find.text('Reset'));
      await settle(tester);
      expect(await logCount(tester), 0);
      // Leave the editor: its auto-dispose controller goes away.
      h.read(routerProvider).go(AppRoutes.habits);
      await settle(tester);
      expect(
        h.container.exists(habitEditorControllerProvider(args())),
        isFalse,
      );
      await tester.tap(_undo);
      await settle(tester);
      expect(await logCount(tester), logs);
    });

    testWidgets('new goal on a habit with history asks before saving', (
      tester,
    ) async {
      await open(tester);
      h.read(habitEditorControllerProvider(args()).notifier).setTarget(10);
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Apply to past days?'), findsOneWidget);
      expect(find.textContaining('the new daily target'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await settle(tester);
      var stored = await tester.runAsync(() => repo.getHabit(id));
      expect(stored!.targetCount, 8);

      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.tap(find.text('Save').last);
      await settle(tester);
      stored = await tester.runAsync(() => repo.getHabit(id));
      expect(stored!.targetCount, 10);
    });
  });

  group('perfect-day confetti', () {
    test('claimed day survives an app restart', () async {
      final day = DateTime(2026, 6, 12);
      final first = await TestHarness.create(now: mockupNow);
      expect(
        first.read(perfectDayCelebrationProvider.notifier).claim(day),
        isTrue,
      );
      expect(
        first.read(perfectDayCelebrationProvider.notifier).claim(day),
        isFalse,
      );
      await first.dispose();

      // A fresh process: same stored preferences, new provider graph.
      final second = await TestHarness.create(
        now: mockupNow,
        prefs: {PerfectDayCelebration.prefsKey: '2026-06-12'},
      );
      addTearDown(second.dispose);
      final c = second.read(perfectDayCelebrationProvider.notifier);
      expect(second.read(perfectDayCelebrationProvider), day);
      expect(c.claim(day), isFalse);
      expect(c.claim(DateTime(2026, 6, 13)), isTrue);
    });

    test('the claim is written to SharedPreferences', () async {
      final h = await TestHarness.create(now: mockupNow);
      addTearDown(h.dispose);
      h
          .read(perfectDayCelebrationProvider.notifier)
          .claim(DateTime(2026, 6, 12, 9));
      await Future<void>.delayed(Duration.zero);
      expect(
        h
            .read(sharedPreferencesProvider)
            .getString(PerfectDayCelebration.prefsKey),
        '2026-06-12',
      );
    });
  });

  test('history clock follows the 24-hour setting', () {
    final habit = Habit.draft(
      startDate: DateTime(2026, 6, 1),
      name: 'Water',
      targetCount: 8,
      unit: 'glasses',
    );
    final log = HabitLog(
      id: 'l',
      habitId: '',
      date: DateTime(2026, 6, 12),
      count: 8,
      createdAt: DateTime(2026, 6, 12, 16, 10),
      updatedAt: DateTime(2026, 6, 12, 16, 10),
    );
    final entry = HabitHistoryEntry(
      log: log,
      kind: HabitHistoryKind.done,
      progress: 1,
    );
    expect(
      HabitFormat.historySubtitle(habit, entry),
      'Goal reached at 4:10 PM',
    );
    expect(
      HabitFormat.historySubtitle(habit, entry, use24h: true),
      'Goal reached at 16:10',
    );
  });
}
