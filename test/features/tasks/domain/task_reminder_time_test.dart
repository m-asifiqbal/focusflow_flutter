/// TaskItem.reminderAt / reminderWallTime: "N before" is calendar
/// arithmetic on wall times, so "1 day before" keeps its wall time across
/// a DST change (subtracting 1440 minutes would move it by an hour).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  final now = DateTime(2026, 3, 1);
  TaskItem task(DateTime due, int? minutes, int offset) => TaskItem.draft(
    now: now,
    title: 'Report',
    dueDate: due,
    dueTimeMinutes: minutes,
  ).copyWith(remindOffsetMinutes: offset);

  test('1 day before across the EU spring-forward night', () {
    // Clocks go forward on Sun 29 Mar 2026 in Europe.
    final t = task(DateTime(2026, 3, 29), 9 * 60, 24 * 60);
    final w = t.reminderWallTime!;
    expect(w.day, DateTime(2026, 3, 28));
    expect(w.minutes, 9 * 60);
    expect(t.reminderAt, DateTime(2026, 3, 28, 9));

    // In a DST zone the instant is 09:00 wall time, i.e. 23 h earlier.
    tzdata.initializeTimeZones();
    final berlin = ZoneCalendar(tz.getLocation('Europe/Berlin'));
    final due = berlin.at(DateTime(2026, 3, 29), 9 * 60);
    final remind = berlin.at(w.day, w.minutes);
    expect(due.difference(remind), const Duration(hours: 23));
    expect(berlin.minuteOfDay(remind), 9 * 60);
  });

  test('minutes before crossing midnight, and all-day tasks', () {
    final late = task(DateTime(2026, 5, 2), 10, 15).reminderWallTime!;
    expect(late.day, DateTime(2026, 5, 1));
    expect(late.minutes, 23 * 60 + 55);

    final allDay = task(DateTime(2026, 5, 2), null, 60).reminderWallTime!;
    expect(allDay.day, DateTime(2026, 5, 2));
    expect(allDay.minutes, 8 * 60); // 09:00 reference − 1 h

    final week = task(DateTime(2026, 5, 2), 600, 7 * 24 * 60);
    expect(week.reminderAt, DateTime(2026, 4, 25, 10));
    expect(task(DateTime(2026, 5, 2), 600, 0).reminderAt, isNotNull);
    expect(
      TaskItem.draft(
        now: now,
        title: 'x',
      ).copyWith(remindOffsetMinutes: 5).reminderAt,
      isNull,
    );
  });
}
