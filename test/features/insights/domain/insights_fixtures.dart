/// Plain-entity builders for the Insights domain tests (no database).
library;

import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/insights/domain/entities/focus_session.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

var _seq = 0;
String _id(String p) => '$p${_seq++}';

TaskItem task({DateTime? due, DateTime? completedAt, DateTime? archivedAt}) =>
    TaskItem(
      id: _id('t'),
      title: 'Task',
      dueDate: due,
      completedAt: completedAt,
      archivedAt: archivedAt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Habit habit({
  String? id,
  String name = 'Habit',
  DateTime? start,
  HabitKind kind = HabitKind.build,
  HabitFrequency frequency = const HabitFrequency.everyDay(),
  bool paused = false,
  DateTime? archivedAt,
}) => Habit.draft(
  startDate: start ?? DateTime(2026),
  name: name,
  kind: kind,
  frequency: frequency,
).copyWith(id: id ?? _id('h'), isPaused: paused, archivedAt: archivedAt);

HabitLog log(Habit h, DateTime day, {int count = 1, bool skipped = false}) =>
    HabitLog(
      id: _id('l'),
      habitId: h.id,
      date: DateTime(day.year, day.month, day.day),
      count: count,
      skipped: skipped,
      createdAt: day,
      updatedAt: day,
    );

FocusSession session(DateTime start, int minutes) =>
    FocusSession(id: _id('f'), startedAt: start, durationMinutes: minutes);

ReminderOccurrence occurrence(DateTime at, {bool done = true}) =>
    ReminderOccurrence(
      reminder: Reminder(
        id: _id('r'),
        title: 'Reminder',
        triggerAt: at,
        createdAt: at,
        updatedAt: at,
      ),
      at: at,
      isDone: done,
    );

HabitDayStatus status(Habit h, HabitStreak streak, DateTime day) =>
    HabitDayStatus(
      habit: h,
      day: day,
      log: null,
      progress: 0,
      isDone: false,
      isScheduled: true,
      streak: streak,
      week: const [],
    );
