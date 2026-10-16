/// HabitsRepository over a keyed temp DB: the row mapper round-trip, the
/// list chips of watchDayStatuses (Today / All / Morning / Evening /
/// Archived) and the log writes behind the card's check-in button.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/habits/data/repository/habit_row_mapper.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late HabitsRepository habits;

  /// Saturday 13 June 2026.
  final now = DateTime(2026, 6, 13, 9);
  final today = DateTime(2026, 6, 13);

  Habit draft(
    String name, {
    PartOfDay part = PartOfDay.anytime,
    HabitKind kind = HabitKind.build,
    int target = 1,
  }) => Habit.draft(
    startDate: DateTime(2026, 6, 1),
    name: name,
    partOfDay: part,
    kind: kind,
    targetCount: target,
    unit: 'glasses',
  );

  Future<List<String>> names(HabitsScope scope) async {
    final list = await habits
        .watchDayStatuses(HabitsQuery(scope: scope), today)
        .first;
    return [for (final s in list) s.habit.name];
  }

  setUp(() async {
    h = await TestHarness.create(now: now);
    habits = h.read(habitsRepositoryProvider);
  });

  tearDown(() => h.dispose());

  group('row mapper', () {
    test('save → get round-trips every user field', () async {
      final id = await habits.save(
        Habit.draft(
          startDate: DateTime(2026, 6, 1),
          name: '  Gym workout ',
          iconKey: 'dumbbell',
          colorHex: '6366F1',
          category: 'Fitness',
          targetCount: 0,
          frequency: HabitFrequency.onWeekdays([1, 3, 5]),
          partOfDay: PartOfDay.evening,
        ).copyWith(
          reminderEnabled: true,
          reminderTimes: ['07:30', '18:00'],
          tags: const [Tag(id: '', name: 'health')],
        ),
      );
      final got = (await habits.getHabit(id))!;
      expect(got.name, 'Gym workout');
      expect(got.iconKey, 'dumbbell');
      expect(got.colorHex, '6366F1');
      expect(got.category, 'Fitness');
      expect(got.targetCount, 1, reason: 'targets below 1 are clamped');
      expect(got.frequency, HabitFrequency.onWeekdays([1, 3, 5]));
      expect(got.frequency.label, 'Mon · Wed · Fri');
      expect(got.partOfDay, PartOfDay.evening);
      expect(got.reminderTimes, ['07:30', '18:00']);
      expect(got.startDate, DateTime(2026, 6, 1));
      expect(got.tags.map((t) => t.name), ['health']);
    });

    test('invalid reminder JSON decodes to no times', () {
      expect(HabitRowMapper.decodeTimes('not json'), isEmpty);
      expect(HabitRowMapper.decodeTimes('{"a":1}'), isEmpty);
      expect(HabitRowMapper.decodeTimes('["08:00", 3]'), ['08:00']);
    });
  });

  group('watchDayStatuses chips', () {
    setUp(() async {
      await habits.save(draft('Water'));
      await habits.save(draft('Run', part: PartOfDay.morning));
      await habits.save(draft('Walk', part: PartOfDay.afternoon));
      await habits.save(draft('Read', part: PartOfDay.evening));
      final paused = await habits.save(draft('Paused'));
      await habits.setPaused(paused, true);
      final archived = await habits.save(draft('Old'));
      await h.read(itemsRepositoryProvider).archive([
        ItemRef(ItemType.habit, archived),
      ]);
      final trashed = await habits.save(draft('Gone'));
      await h.read(itemsRepositoryProvider).moveToTrash([
        ItemRef(ItemType.habit, trashed),
      ]);
    });

    test('Today: active, not paused, manual order', () async {
      expect(await names(HabitsScope.today), ['Water', 'Run', 'Walk', 'Read']);
    });

    test('All habits includes paused ones', () async {
      expect(await names(HabitsScope.all), [
        'Water',
        'Run',
        'Walk',
        'Read',
        'Paused',
      ]);
    });

    test('Morning / Evening (afternoon + evening)', () async {
      expect(await names(HabitsScope.morning), ['Run']);
      expect(await names(HabitsScope.evening), ['Walk', 'Read']);
      expect(await names(HabitsScope.afternoon), ['Walk']);
    });

    test('Archived lists archived, never trashed', () async {
      expect(await names(HabitsScope.archived), ['Old']);
    });

    test('text filter matches name or category', () async {
      final list = await habits
          .watchDayStatuses(const HabitsQuery(text: 'wal'), today)
          .first;
      expect(list.single.habit.name, 'Walk');
    });

    test('reorder moves a habit between neighbours', () async {
      final all = await habits.watchHabits(const HabitsQuery()).first;
      final read = all.firstWhere((x) => x.name == 'Read');
      final water = all.firstWhere((x) => x.name == 'Water');
      await habits.reorder(read.id, beforeId: water.id);
      expect((await names(HabitsScope.today)).first, 'Read');
    });
  });

  group('log writes', () {
    test('increment / decrement never go below zero', () async {
      final id = await habits.save(draft('Water', target: 8));
      expect(await habits.increment(id, today), 1);
      expect(await habits.increment(id, today, by: 5), 6);
      expect(await habits.increment(id, today, by: -10), 0);
      final status = (await habits.watchTodayHabits(today).first).single;
      expect(status.count, 0);
      expect(status.progressLabel, '0 / 8 glasses');
    });

    test('toggleDone: build 0 ⇄ target, quit clean ⇄ slip', () async {
      final read = await habits.save(draft('Read'));
      final sugar = await habits.save(draft('Sugar', kind: HabitKind.quit));
      await habits.toggleDone(read, today);
      await habits.toggleDone(sugar, today);
      var list = await habits.watchTodayHabits(today).first;
      expect(list.map((s) => s.isDone), [true, false]);
      await habits.toggleDone(read, today);
      await habits.toggleDone(sugar, today);
      list = await habits.watchTodayHabits(today).first;
      expect(list.map((s) => s.isDone), [false, true]);
    });

    test('skip marks a rest day; clearLog removes it', () async {
      final id = await habits.save(draft('Read'));
      await habits.skip(id, today);
      var s = (await habits.watchTodayHabits(today).first).single;
      expect(s.isSkipped, isTrue);
      expect(s.progressLabel, 'Skipped');
      await habits.clearLog(id, today);
      s = (await habits.watchTodayHabits(today).first).single;
      expect(s.log, isNull);
    });

    test('streams update live after a check-in', () async {
      final id = await habits.save(draft('Read'));
      final stream = habits.watchTodayHabits(today);
      final expectation = expectLater(
        stream.map((l) => l.single.isDone),
        emitsThrough(true),
      );
      await habits.increment(id, today);
      await expectation;
    });
  });
}
