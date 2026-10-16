/// Seeds the data of mockup 26 (Tuesday 13 June 2023): on the 13th the
/// "Review FocusFlow Q3 Strategy" (09:00, high) and "Design Home Screen
/// v2" (11:30) tasks, the "Call the bank about card" reminder (10:00) and
/// the "Read 20 pages" habit checked in — plus scattered tasks, reminders
/// and notes on other June days for the grid dots. Run inside
/// `tester.runAsync`.
library;

import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';

/// "Now" of the mockup: Tuesday 13 June 2023, 8:30.
final calendarNow = DateTime(2023, 6, 13, 8, 30);
final calendarToday = DateTime(2023, 6, 13);

/// Ids of the seeded rows the tests act on.
class CalendarSeed {
  CalendarSeed(this.reviewTaskId, this.designTaskId);

  final String reviewTaskId;
  final String designTaskId;
}

Future<CalendarSeed> seedCalendarMockup(TestHarness h) async {
  await h.updateSettings(
    (s) => s.copyWith(weekStartsOn: DateTime.sunday, use24HourTime: true),
  );
  h.clock.set(calendarNow);
  final tasks = h.read(tasksRepositoryProvider);
  Future<String> task(
    String title,
    DateTime day, {
    int? minutes,
    TaskPriority priority = TaskPriority.none,
  }) => tasks.save(
    TaskItem.draft(
      now: calendarNow,
      title: title,
      dueDate: day,
      dueTimeMinutes: minutes,
      priority: priority,
    ),
  );

  final review = await task(
    'Review FocusFlow Q3 Strategy',
    calendarToday,
    minutes: 9 * 60,
    priority: TaskPriority.high,
  );
  final design = await task(
    'Design Home Screen v2',
    calendarToday,
    minutes: 11 * 60 + 30,
  );
  for (final d in [2, 5, 12, 16, 23, 30]) {
    await task('Task on $d', DateTime(2023, 6, d), minutes: 15 * 60);
  }

  final reminders = h.read(remindersRepositoryProvider);
  for (final (title, at) in [
    ('Call the bank about card', DateTime(2023, 6, 13, 10)),
    ('Pay rent', DateTime(2023, 6, 5, 18)),
    ('Dentist', DateTime(2023, 6, 14, 9)),
    ('Renew passport', DateTime(2023, 6, 27, 12)),
  ]) {
    await reminders.save(Reminder.draft(triggerAt: at, title: title));
  }

  final habits = h.read(habitsRepositoryProvider);
  final habitId = await habits.save(
    Habit.draft(
      startDate: DateTime(2023, 6, 13),
      name: 'Read 20 pages',
      iconKey: 'book-open',
      colorHex: HabitPalette.hexOf(HabitPalette.indigo),
    ),
  );
  await habits.setLog(habitId, calendarToday, count: 1);

  final notes = h.read(notesRepositoryProvider);
  for (final d in [8, 27]) {
    h.clock.set(DateTime(2023, 6, d, 7));
    await notes.createEmpty(title: 'Note on $d');
  }
  h.clock.set(calendarNow);
  return CalendarSeed(review, design);
}
