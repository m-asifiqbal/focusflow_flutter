/// Home dashboard rules (screen 03): greeting boundaries, the two-week
/// strip from the week-start setting, "Today's Tasks" order, the hero's
/// percent / encouragement and the "Get started" checklist progress.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

final _now = DateTime(2026, 10, 14, 9); // a Wednesday

TaskItem _task(
  String title, {
  int? minutes,
  bool done = false,
  bool pinned = false,
  double order = 0,
}) => TaskItem.draft(
  now: _now,
  title: title,
  dueDate: _now,
  dueTimeMinutes: minutes,
).copyWith(completedAt: done ? _now : null, isPinned: pinned, sortOrder: order);

HomeFocus _focus({int done = 0, int due = 0, int goal = 7}) => HomeFocus(
  tasksDone: done,
  tasksDue: due,
  goal: goal,
  habitsDone: 0,
  habitsDue: 0,
  remindersLeft: 0,
);

void main() {
  group('greeting', () {
    String at(int h, int m) =>
        HomeRules.greeting(DateTime(2026, 10, 14, h, m), 'Asif Iqbal');

    test('boundaries: 5:00 morning, 12:00 afternoon, 17:00 evening', () {
      expect(at(4, 59), 'Good evening, Asif');
      expect(at(5, 0), 'Good morning, Asif');
      expect(at(11, 59), 'Good morning, Asif');
      expect(at(12, 0), 'Good afternoon, Asif');
      expect(at(16, 59), 'Good afternoon, Asif');
      expect(at(17, 0), 'Good evening, Asif');
      expect(at(0, 0), 'Good evening, Asif');
    });

    test('no name → no comma; first name only', () {
      expect(HomeRules.greeting(_now, '  '), 'Good morning');
      expect(HomeRules.firstName('  Asif   Iqbal '), 'Asif');
    });
  });

  group('weekDays', () {
    test('14 days from the Monday of this week', () {
      final days = HomeRules.weekDays(_now, DateTime.monday);
      expect(days, hasLength(14));
      expect(days.first, DateTime(2026, 10, 12));
      expect(days.last, DateTime(2026, 10, 25));
      expect(days.every((d) => d.hour == 0), isTrue);
    });

    test('follows a Sunday / Saturday week start', () {
      expect(
        HomeRules.weekDays(_now, DateTime.sunday).first,
        DateTime(2026, 10, 11),
      );
      expect(
        HomeRules.weekDays(_now, DateTime.saturday).first,
        DateTime(2026, 10, 10),
      );
    });

    test('today on the week start day begins the strip', () {
      final monday = DateTime(2026, 10, 12, 23, 30);
      expect(
        HomeRules.weekDays(monday, DateTime.monday).first,
        DateTime(2026, 10, 12),
      );
    });

    test('consecutive calendar days across a DST change', () {
      // Europe/US DST ends late Oct / early Nov; days stay midnight-based.
      final days = HomeRules.weekDays(DateTime(2026, 10, 26), DateTime.monday);
      for (var i = 1; i < days.length; i++) {
        expect(days[i].day != days[i - 1].day, isTrue);
        expect(days[i].hour, 0);
      }
    });
  });

  group('orderTasks', () {
    test('open by time, untimed after timed, completed last', () {
      final ordered = HomeRules.orderTasks([
        _task('done early', minutes: 6 * 60, done: true),
        _task('untimed'),
        _task('11:30', minutes: 11 * 60 + 30),
        _task('9:00', minutes: 9 * 60),
      ]);
      expect(ordered.map((t) => t.title), [
        '9:00',
        '11:30',
        'untimed',
        'done early',
      ]);
    });

    test('pinned first within the same time, then manual order', () {
      final ordered = HomeRules.orderTasks([
        _task('b', minutes: 600, order: 2),
        _task('a', minutes: 600, order: 1),
        _task('pinned', minutes: 600, pinned: true, order: 3),
      ]);
      expect(ordered.map((t) => t.title), ['pinned', 'a', 'b']);
    });

    test('does not mutate the input', () {
      final input = [_task('late', minutes: 900), _task('early', minutes: 60)];
      HomeRules.orderTasks(input);
      expect(input.first.title, 'late');
    });
  });

  group('HomeFocus', () {
    test('percent against the goal, clamped to 100', () {
      expect(_focus(done: 4, goal: 7).percent, 57);
      expect(_focus(done: 9, goal: 7).percent, 100);
      expect(_focus(done: 3, goal: 0).percent, 0);
    });

    test('tasks target: due today, else the goal', () {
      expect(_focus(due: 5).tasksTarget, 5);
      expect(_focus(due: 0, goal: 6).tasksTarget, 6);
    });

    test('encouragement thresholds', () {
      expect(_focus().encouragement, "Let's make today count.");
      expect(
        _focus(done: 1, goal: 7).encouragement,
        'Nice start — keep the momentum!',
      );
      expect(
        _focus(done: 4, goal: 8).encouragement,
        "You're doing great — keep it up!",
      );
      expect(
        _focus(done: 7, goal: 7).encouragement,
        'Goal reached — amazing work!',
      );
    });
  });

  group('HomeGetStarted', () {
    test('steps tick off from the library totals', () {
      final none = HomeGetStarted.of(LibraryCounts.empty);
      expect(none.doneCount, 0);
      expect(none.isComplete, isFalse);

      final some = HomeGetStarted.of(
        const LibraryCounts(notesTotal: 1, habitsTotal: 2),
      );
      expect(some.hasNote, isTrue);
      expect(some.hasTask, isFalse);
      expect(some.hasRoutine, isTrue);
      expect(some.doneCount, 2);

      final all = HomeGetStarted.of(
        const LibraryCounts(notesTotal: 1, tasksTotal: 1, remindersTotal: 1),
      );
      expect(all.isComplete, isTrue);
    });
  });
}
