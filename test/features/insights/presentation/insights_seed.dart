/// Seeds a week of activity close to mockup 25 (Thursday 15 Oct 2026,
/// 18:00): tasks completed mostly in the morning (→ morning tip), focus
/// sessions, notes, a done reminder and three habit streaks (45 / 21 / 12
/// days). Run inside `tester.runAsync`.
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

final insightsNow = DateTime(2026, 10, 15, 18);
final insightsToday = DateTime(2026, 10, 15);

Future<void> seedInsights(TestHarness h) async {
  await _tasks(h);
  await _focus(h);
  await _notes(h);
  await _reminders(h);
  await _habits(h);
  h.clock.set(insightsNow);
}

Future<void> _tasks(TestHarness h) async {
  final repo = h.read(tasksRepositoryProvider);
  Future<void> add(DateTime due, {int? doneHour}) async {
    final id = await repo.save(
      TaskItem.draft(now: insightsNow, title: 'Task', dueDate: due),
    );
    if (doneHour == null) return;
    h.clock.set(DateTime(due.year, due.month, due.day, doneHour));
    await repo.complete(id);
  }

  // This week (Oct 9–15): completions per day, morning-heavy.
  const perDay = [2, 4, 3, 5, 6, 3, 4];
  for (var i = 0; i < 7; i++) {
    final day = DateTime(2026, 10, 9 + i);
    for (var k = 0; k < perDay[i]; k++) {
      await add(day, doneHour: k % 3 == 2 ? 15 : 8 + k ~/ 2);
    }
  }
  for (var i = 0; i < 5; i++) {
    await add(DateTime(2026, 10, 10 + i)); // still open
  }
  // Previous week (Oct 2–8).
  for (var i = 0; i < 7; i++) {
    final day = DateTime(2026, 10, 2 + i);
    await add(day, doneHour: 10);
    await add(day);
  }
}

Future<void> _focus(TestHarness h) async {
  final repo = h.read(focusSessionsRepositoryProvider);
  for (final (d, m) in [(10, 50), (12, 90), (14, 45), (15, 25)]) {
    await repo.add(startedAt: DateTime(2026, 10, d, 9), durationMinutes: m);
  }
  await repo.add(startedAt: DateTime(2026, 10, 5, 9), durationMinutes: 60);
}

Future<void> _notes(TestHarness h) async {
  final repo = h.read(notesRepositoryProvider);
  // 7 this week, 2 the week before, 1 only inside 30 days.
  for (final at in [
    for (var d = 9; d <= 15; d++) DateTime(2026, 10, d, 12),
    DateTime(2026, 10, 4, 12),
    DateTime(2026, 10, 6, 12),
    DateTime(2026, 9, 20, 12),
  ]) {
    h.clock.set(at);
    await repo.createEmpty(title: 'Note');
  }
}

Future<void> _reminders(TestHarness h) async {
  final repo = h.read(remindersRepositoryProvider);
  for (final d in [11, 13]) {
    final at = DateTime(2026, 10, d, 10);
    h.clock.set(at.subtract(const Duration(hours: 1)));
    final id = await repo.save(Reminder.draft(triggerAt: at, title: 'Call'));
    h.clock.set(at);
    await repo.markDone(id);
  }
}

Future<void> _habits(TestHarness h) async {
  final repo = h.read(habitsRepositoryProvider);
  for (final (name, icon, colors, days) in [
    ('Daily reading', 'book-open', HabitPalette.emerald, 45),
    ('Gym workout', 'dumbbell', HabitPalette.indigo, 21),
    ('Hydration', 'droplet', HabitPalette.blue, 12),
  ]) {
    final id = await repo.save(
      Habit.draft(
        startDate: DateTime(2026, 8, 1),
        name: name,
        iconKey: icon,
        colorHex: HabitPalette.hexOf(colors),
      ),
    );
    for (var i = 0; i < days; i++) {
      await repo.setLog(id, DateUtilsX.addDays(insightsToday, -i), count: 1);
    }
  }
}
