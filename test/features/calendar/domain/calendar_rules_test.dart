/// CalendarRules — month grid for both week starts (incl. month
/// boundaries), weekday columns, `?date=` parsing, the dot cap and agenda
/// ordering.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/calendar/domain/services/calendar_rules.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

void main() {
  final now = DateTime(2023, 6, 13, 9);

  TaskItem task(String title, DateTime day, {int? minutes, String id = ''}) =>
      TaskItem.draft(
        now: now,
        title: title,
        dueDate: day,
        dueTimeMinutes: minutes,
      ).copyWith(id: id.isEmpty ? title : id);

  group('monthGrid', () {
    test('June 2023, Sunday start: 28 May … 1 Jul (5 rows)', () {
      final g = CalendarRules.monthGrid(DateTime(2023, 6), DateTime.sunday);
      expect(g.length, 35);
      expect(g.first, DateTime(2023, 5, 28));
      expect(g.last, DateTime(2023, 7, 1));
      expect(g.first.weekday, DateTime.sunday);
    });

    test('June 2023, Monday start: 29 May … 2 Jul', () {
      final g = CalendarRules.monthGrid(DateTime(2023, 6), DateTime.monday);
      expect(g.length, 35);
      expect(g.first, DateTime(2023, 5, 29));
      expect(g.last, DateTime(2023, 7, 2));
      expect(g.first.weekday, DateTime.monday);
    });

    test('month starting on the week start has no leading days', () {
      // 1 May 2023 is a Monday.
      final g = CalendarRules.monthGrid(DateTime(2023, 5, 17), DateTime.monday);
      expect(g.first, DateTime(2023, 5, 1));
      expect(g.length % 7, 0);
    });

    test('six-row month and Feb in a non-leap year', () {
      // 1 Jul 2023 is a Saturday → 6 rows with a Sunday start.
      final jul = CalendarRules.monthGrid(DateTime(2023, 7), DateTime.sunday);
      expect(jul.length, 42);
      expect(jul.last, DateTime(2023, 8, 5));
      // Feb 2026 starts on a Sunday and has 28 days → exactly 4 rows.
      final feb = CalendarRules.monthGrid(DateTime(2026, 2), DateTime.sunday);
      expect(feb.length, 28);
      expect(feb.first, DateTime(2026, 2, 1));
      expect(feb.last, DateTime(2026, 2, 28));
    });

    test('year boundary', () {
      final g = CalendarRules.monthGrid(DateTime(2024, 1), DateTime.sunday);
      expect(g.first, DateTime(2023, 12, 31));
      expect(CalendarRules.addMonths(DateTime(2023, 12), 1), DateTime(2024));
      expect(CalendarRules.addMonths(DateTime(2024), -1), DateTime(2023, 12));
    });
  });

  test('weekdayColumns follow the week start', () {
    expect(CalendarRules.weekdayColumns(DateTime.monday), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(CalendarRules.weekdayColumns(DateTime.sunday), [
      7,
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
    expect(CalendarRules.weekdayColumns(DateTime.saturday), [
      6, 7, 1, 2, 3, 4, 5, //
    ]);
  });

  test('tryParseDay accepts yyyy-MM-dd only', () {
    expect(CalendarRules.tryParseDay('2023-06-13'), DateTime(2023, 6, 13));
    expect(CalendarRules.tryParseDay(null), isNull);
    expect(CalendarRules.tryParseDay(''), isNull);
    expect(CalendarRules.tryParseDay('2023-6-13'), isNull);
    expect(CalendarRules.tryParseDay('2023-02-30'), isNull);
    expect(CalendarRules.tryParseDay('2023-13-01'), isNull);
    expect(CalendarRules.tryParseDay('nonsense'), isNull);
  });

  test('dots: module order, capped at 3, linked reminders skipped', () {
    final day = DateTime(2023, 6, 13);
    final dots = CalendarRules.dots(
      tasks: [task('A', day), task('B', day)],
      reminders: [
        ReminderOccurrence(
          reminder: Reminder.draft(triggerAt: day, title: 'R'),
          at: DateTime(2023, 6, 13, 10),
        ),
        // Linked to a task → the task row stands for it.
        ReminderOccurrence(
          reminder: Reminder.draft(
            triggerAt: day,
            title: 'Linked',
            linkedRef: const ItemRef(ItemType.task, 'A'),
          ),
          at: DateTime(2023, 6, 14, 10),
        ),
      ],
      habitLogs: [
        HabitLog(
          id: 'l',
          habitId: 'h',
          date: day,
          count: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      notes: [Note(id: 'n', createdAt: day, updatedAt: day)],
    );
    expect(dots['2023-06-13'], [
      ItemType.task,
      ItemType.reminder,
      ItemType.habit,
    ]);
    expect(dots['2023-06-13']!.length, CalendarRules.maxDots);
    expect(dots.containsKey('2023-06-14'), isFalse);
  });

  test(
    'agenda: timed rows by time, then all-day; module order breaks ties',
    () {
      final day = DateTime(2023, 6, 13);
      final entries = CalendarRules.agenda(
        tasks: [
          task('Design Home Screen v2', day, minutes: 11 * 60 + 30),
          task('Zz all day task', day),
          task('Review Q3', day, minutes: 9 * 60),
        ],
        reminders: [
          ReminderOccurrence(
            reminder: Reminder.draft(triggerAt: day, title: 'Call the bank'),
            at: DateTime(2023, 6, 13, 10),
          ),
          ReminderOccurrence(
            reminder: Reminder.draft(triggerAt: day, title: 'Same time'),
            at: DateTime(2023, 6, 13, 9),
          ),
        ],
      );
      expect(entries.map((e) => e.title), [
        'Review Q3',
        'Same time',
        'Call the bank',
        'Design Home Screen v2',
        'Zz all day task',
      ]);
      expect(entries.last.isAllDay, isTrue);
      expect(entries.first.meta, 'Task');
      expect(entries.first.canReschedule, isTrue);
      expect(entries[1].canReschedule, isFalse);
    },
  );
}
