/// HabitEditorController (screen 15) intents over a real DB: templates,
/// weekday circles, habit type, reminders, save, and Reset history + Undo.
/// Editing the schedule must never touch existing logs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_templates.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late HabitsRepository repo;
  final now = DateTime(2026, 6, 12, 9);

  setUp(() async {
    h = await TestHarness.create(now: now);
    repo = h.read(habitsRepositoryProvider);
  });

  tearDown(() => h.dispose());

  Future<HabitEditorController> open(HabitEditorArgs args) async {
    final p = habitEditorControllerProvider(args);
    h.container.listen(p, (_, _) {});
    await h.container.read(p.future);
    return h.container.read(p.notifier);
  }

  HabitEditorState state(HabitEditorArgs args) =>
      h.container.read(habitEditorControllerProvider(args)).valueOrNull!;

  test('template fills every field; Create saves it', () async {
    const args = (id: null, name: null);
    final c = await open(args);
    c.applyTemplate(HabitTemplates.all.firstWhere((t) => t.label == 'Read'));
    final d = state(args).draft;
    expect(d.name, 'Read 20 pages');
    expect(d.partOfDay, PartOfDay.evening);
    expect(d.reminderEnabled, isTrue);
    expect(d.reminderTimes, ['21:00']);
    final id = await c.save();
    expect(id, isNotNull);
    expect((await repo.getHabit(id!))!.name, 'Read 20 pages');
  });

  test(
    'weekday circles: all seven collapse to every day; none blocks save',
    () async {
      const args = (id: null, name: 'Gym');
      final c = await open(args);
      c.setFrequencyKind(HabitFrequencyKind.specificDays);
      expect(state(args).draft.frequency.label, 'Weekdays');
      c
        ..toggleWeekday(DateTime.saturday)
        ..toggleWeekday(DateTime.sunday);
      expect(state(args).draft.frequency, isA<EveryDayFrequency>());
      for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
        c.toggleWeekday(d);
      }
      expect(state(args).hasValidSchedule, isFalse);
      expect(state(args).canSave, isFalse);
    },
  );

  test('time of day puts a custom habit under the Morning chip', () async {
    const args = (id: null, name: 'Stretch');
    final c = await open(args);
    c.setPartOfDay(PartOfDay.morning);
    expect(state(args).draft.partOfDay, PartOfDay.morning);
    await c.save();

    Future<List<String>> chip(HabitsScope scope) async {
      final p = habitDayStatusesProvider(scope);
      final sub = h.container.listen(p, (_, _) {});
      final list = await h.container.read(p.future);
      sub.close();
      return [for (final s in list) s.habit.name];
    }

    expect(await chip(HabitsScope.morning), ['Stretch']);
    expect(await chip(HabitsScope.evening), isEmpty);
  });

  test('quit ignores the schedule: frequency resets, meta omits it', () async {
    const args = (id: null, name: 'No sugar');
    final c = await open(args);
    c
      ..setFrequencyKind(HabitFrequencyKind.specificDays)
      ..setKind(HabitKind.quit);
    final d = state(args).draft;
    expect(d.frequency, isA<EveryDayFrequency>());
    expect(
      HabitFormat.meta(d.copyWith(category: 'Health')),
      'Health · Quit habit',
    );
  });

  test(
    'quit type forces target 1 / slips; back to build restores a unit',
    () async {
      const args = (id: null, name: 'No sugar');
      final c = await open(args);
      c
        ..setTarget(8)
        ..setKind(HabitKind.quit);
      expect(state(args).draft.targetCount, 1);
      expect(state(args).draft.unit, 'slips');
      c.setKind(HabitKind.build);
      expect(state(args).draft.unit, 'times');
    },
  );

  test(
    'reminders: on adds 09:00, removing the last time turns it off',
    () async {
      const args = (id: null, name: 'Walk');
      final c = await open(args);
      c.setReminderEnabled(true);
      expect(state(args).draft.reminderTimes, ['09:00']);
      c.addReminderTime('07:30');
      expect(state(args).draft.reminderTimes, ['07:30', '09:00']);
      c
        ..removeReminderTime('07:30')
        ..removeReminderTime('09:00');
      expect(state(args).draft.reminderEnabled, isFalse);
    },
  );

  test(
    'editing the schedule keeps logs; Reset history + Undo restores',
    () async {
      final id = await repo.save(
        Habit.draft(startDate: DateTime(2026, 6, 1), name: 'Water'),
      );
      for (var d = 1; d <= 5; d++) {
        await repo.setLog(id, DateTime(2026, 6, d), count: 1, note: 'n$d');
      }
      final args = (id: id, name: null);
      final c = await open(args);
      c.setFrequencyKind(HabitFrequencyKind.timesPerWeek);
      await c.save();
      expect((await repo.watchHabitWithLogs(id).first)!.logs, hasLength(5));

      final removed = await c.resetHistory();
      expect(removed, hasLength(5));
      expect((await repo.watchHabitWithLogs(id).first)!.logs, isEmpty);
      await c.restoreHistory(removed);
      final back = (await repo.watchHabitWithLogs(id).first)!.logs;
      expect(back.map((l) => l.note), ['n1', 'n2', 'n3', 'n4', 'n5']);
    },
  );
}
