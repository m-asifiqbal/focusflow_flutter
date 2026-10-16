/// HabitLogger (card button / "Log today" / amount sheet writes) and
/// reorderHabits (drag-to-reorder → repository order) over a real DB.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_logger_provider.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late HabitsRepository repo;
  late HabitLogger logger;
  final now = DateTime(2026, 6, 12, 9);

  Future<String> add(
    String name, {
    HabitKind kind = HabitKind.build,
    int target = 1,
  }) => repo.save(
    Habit.draft(
      startDate: DateTime(2026, 6, 1),
      name: name,
      kind: kind,
      targetCount: target,
    ),
  );

  Future<HabitDayStatus> status(String id) async =>
      (await repo.watchTodayHabits(logger.today).first).firstWhere(
        (s) => s.habit.id == id,
      );

  setUp(() async {
    h = await TestHarness.create(now: now);
    repo = h.read(habitsRepositoryProvider);
    logger = h.read(habitLoggerProvider);
  });

  tearDown(() => h.dispose());

  test('writes go to the habit day', () {
    expect(logger.today, DateTime(2026, 6, 12));
  });

  test('tap: counted habit +1 until done, then undoes one', () async {
    final id = await add('Water', target: 2);
    var s = await status(id);
    expect(await logger.tap(s), HabitLogOutcome.progressed);
    s = await status(id);
    expect(await logger.tap(s), HabitLogOutcome.progressed);
    s = await status(id);
    expect(s.isDone, isTrue);
    expect(await logger.tap(s), HabitLogOutcome.reverted);
    expect((await status(id)).count, 1);
  });

  test('tap on a clean quit habit logs a slip; undo restores', () async {
    final id = await add('No sugar', kind: HabitKind.quit);
    final s = await status(id);
    final before = s.log;
    expect(await logger.tap(s), HabitLogOutcome.slipped);
    expect((await status(id)).isDone, isFalse);
    await logger.undo(s.habit, before);
    expect((await status(id)).isDone, isTrue);
  });

  test('logToday never removes progress', () async {
    final id = await add('Read');
    expect(await logger.logToday(id), HabitLogOutcome.progressed);
    expect(await logger.logToday(id), HabitLogOutcome.unchanged);
    expect((await status(id)).isDone, isTrue);
    expect(await logger.logToday('missing'), HabitLogOutcome.unchanged);
  });

  test('amount sheet: set, skip, clear', () async {
    final id = await add('Water', target: 8);
    var s = await status(id);
    await logger.setAmount(s, 5);
    expect((await status(id)).count, 5);
    s = await status(id);
    await logger.skip(s);
    expect((await status(id)).isSkipped, isTrue);
    s = await status(id);
    await logger.clear(s);
    expect((await status(id)).log, isNull);
  });

  test('reorderHabits moves down and up by final index', () async {
    final a = await add('A');
    final b = await add('B');
    final c = await add('C');
    Future<List<String>> order() async => [
      for (final x in await repo.watchHabits(const HabitsQuery()).first) x.name,
    ];
    await reorderHabits(repo, [a, b, c], 0, 2);
    expect(await order(), ['B', 'C', 'A']);
    await reorderHabits(repo, [b, c, a], 2, 0);
    expect(await order(), ['A', 'B', 'C']);
    await reorderHabits(repo, [a, b, c], 1, 1);
    expect(await order(), ['A', 'B', 'C']);
  });
}
