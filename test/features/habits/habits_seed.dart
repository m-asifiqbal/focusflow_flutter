/// Seeds the five habits of mockup 14 (Friday 12 June 2026): Drink Water
/// 6/8, Read 20 pages done (45-day streak), Meditate 5/10, Gym workout
/// Mon·Wed·Fri, No sugar (quit, day 9). "2 of 5 done today" → 40 %.
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

/// "Today" of the mockup: Friday 12 June 2026, 9:41.
final mockupNow = DateTime(2026, 6, 12, 9, 41);

/// Ids by habit name.
Future<Map<String, String>> seedMockupHabits(HabitsRepository repo) async {
  final today = DateUtilsX.dateOnly(mockupNow);
  DateTime ago(int days) => DateUtilsX.addDays(today, -days);
  final ids = <String, String>{};

  Future<String> add(
    String name, {
    required String icon,
    required String color,
    int target = 1,
    String unit = 'times',
    HabitKind kind = HabitKind.build,
    HabitFrequency frequency = const HabitFrequency.everyDay(),
    PartOfDay part = PartOfDay.anytime,
    int startDaysAgo = 120,
  }) async {
    final id = await repo.save(
      Habit.draft(
        startDate: ago(startDaysAgo),
        name: name,
        iconKey: icon,
        colorHex: color,
        kind: kind,
        targetCount: target,
        unit: unit,
        frequency: frequency,
        partOfDay: part,
      ),
    );
    return ids[name] = id;
  }

  final water = await add(
    'Drink Water',
    icon: 'droplet',
    color: HabitPalette.hexOf(HabitPalette.blue),
    target: 8,
    unit: 'glasses',
    part: PartOfDay.morning,
  );
  for (var d = 1; d <= 13; d++) {
    await repo.setLog(water, ago(d), count: 8, skipped: d == 3);
  }
  await repo.setLog(water, today, count: 6);

  final read = await add(
    'Read 20 pages',
    icon: 'book-open',
    color: HabitPalette.hexOf(HabitPalette.emerald),
    part: PartOfDay.evening,
  );
  for (var d = 0; d <= 45; d++) {
    if (d == 2) {
      await repo.skip(read, ago(d));
    } else {
      await repo.setLog(read, ago(d), count: 1);
    }
  }

  final meditate = await add(
    'Meditate',
    icon: 'spa',
    color: HabitPalette.hexOf(HabitPalette.amber),
    target: 10,
    unit: 'min',
    part: PartOfDay.morning,
  );
  for (var d = 1; d <= 9; d++) {
    await repo.setLog(meditate, ago(d), count: 10, skipped: d == 3);
  }
  await repo.setLog(meditate, today, count: 5);

  final gym = await add(
    'Gym workout',
    icon: 'dumbbell',
    color: HabitPalette.hexOf(HabitPalette.indigo),
    frequency: HabitFrequency.onWeekdays([
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ]),
    part: PartOfDay.afternoon,
  );
  for (var d = 1; d <= 49; d++) {
    final day = ago(d);
    if (day.weekday == DateTime.monday ||
        day.weekday == DateTime.wednesday ||
        day.weekday == DateTime.friday) {
      await repo.setLog(gym, day, count: 1);
    }
  }

  await add(
    'No sugar',
    icon: 'ban',
    color: HabitPalette.hexOf(HabitPalette.red),
    kind: HabitKind.quit,
    unit: 'slips',
    startDaysAgo: 8,
  );
  return ids;
}
