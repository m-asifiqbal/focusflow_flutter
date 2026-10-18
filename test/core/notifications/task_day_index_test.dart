/// TaskDayIndex answers the planner's overdue / due-today questions in
/// O(log n): it must agree with the plain scan-and-sort definitions on any
/// mix of tasks, and the planner built on it must stay linear — a few hundred
/// tasks and reminders plan in milliseconds, not seconds.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/planning/digest_planner.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/task_day_index.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

import 'planner_test_data.dart';

/// The definitions the index replaces, written the slow, obvious way.
bool _open(TaskItem t) => t.isActive && !t.isCompleted;

List<TaskItem> _overdueOn(List<TaskItem> tasks, DateTime day) => [
  for (final t in tasks)
    if (_open(t) &&
        t.dueDate != null &&
        DateUtilsX.daysBetween(t.dueDate!, day) > 0)
      t,
];

List<TaskItem> _dueOn(List<TaskItem> tasks, DateTime day) => [
  for (final t in tasks)
    if (_open(t) &&
        t.dueDate != null &&
        DateUtilsX.daysBetween(t.dueDate!, day) == 0)
      t,
];

List<TaskItem> _randomTasks(Random r, int n) {
  final base = DateTime(2026, 6, 13);
  return [
    for (var i = 0; i < n; i++)
      TaskItem(
        id: 't$i',
        title: 'Task $i',
        dueDate: r.nextInt(6) == 0
            ? null
            : DateTime(base.year, base.month, base.day + r.nextInt(80) - 40),
        dueTimeMinutes: r.nextInt(3) == 0 ? r.nextInt(1440) : null,
        completedAt: r.nextInt(5) == 0 ? base : null,
        archivedAt: r.nextInt(9) == 0 ? base : null,
        deletedAt: r.nextInt(15) == 0 ? base : null,
        createdAt: base,
        updatedAt: base,
      ),
  ];
}

void main() {
  group('TaskDayIndex == the plain definitions', () {
    test('overdue / due counts and sets over random tasks', () {
      final r = Random(5);
      for (var round = 0; round < 40; round++) {
        final tasks = _randomTasks(r, 1 + r.nextInt(120));
        final index = TaskDayIndex(tasks);
        for (var offset = -45; offset <= 45; offset += 3) {
          final day = DateTime(2026, 6, 13 + offset);
          final no = DateUtilsX.dayNumber(day);
          final overdue = _overdueOn(tasks, day);
          final due = _dueOn(tasks, day);

          expect(index.overdueCount(no), overdue.length, reason: '$day');
          expect(index.dueCount(no), due.length, reason: '$day');
          expect(
            {for (final t in index.overdueOn(no)) t.id},
            {for (final t in overdue) t.id},
          );
          expect(
            {for (final t in index.dueOn(no)) t.id},
            {for (final t in due) t.id},
          );
          expect(index.badgeOn(no, BadgeMode.none), isNull);
          expect(index.badgeOn(no, BadgeMode.overdue), overdue.length);
          expect(
            index.badgeOn(no, BadgeMode.today),
            overdue.length + due.length,
          );
        }
      }
    });

    test('overdue tasks come oldest first, ties in the order given', () {
      final tasks = [
        task('b', due: DateTime(2026, 6, 10)),
        task('a', due: DateTime(2026, 6, 8)),
        task('c', due: DateTime(2026, 6, 10)),
        task('d', due: DateTime(2026, 6, 10)).copyWith(dueTimeMinutes: 480),
        task(
          'done',
          due: DateTime(2026, 6, 1),
          completedAt: DateTime(2026, 6, 2),
        ),
        task(
          'archived',
          due: DateTime(2026, 6, 1),
          archivedAt: DateTime(2026, 6, 2),
        ),
        task('nodate'),
      ];
      final index = TaskDayIndex(tasks);
      final day = DateUtilsX.dayNumber(DateTime(2026, 6, 13));

      expect(index.overdueOn(day).map((t) => t.id), ['a', 'b', 'c', 'd']);
      expect(
        DigestPlanner.overdueOn(tasks, DateTime(2026, 6, 13)).map((t) => t.id),
        ['a', 'b', 'c', 'd'],
      );
      expect(
        index.overdueOn(DateUtilsX.dayNumber(DateTime(2026, 6, 8))),
        isEmpty,
      );
      expect(
        index
            .dueOn(DateUtilsX.dayNumber(DateTime(2026, 6, 10)))
            .map((t) => t.id),
        ['b', 'c', 'd'],
      );
    });

    test('no tasks, no answers', () {
      final index = TaskDayIndex(const []);
      expect(index.overdueCount(20000), 0);
      expect(index.dueCount(20000), 0);
      expect(index.overdueOn(20000), isEmpty);
    });
  });

  group('planner scale', () {
    test('a heavy snapshot plans in milliseconds, and badges are right', () {
      final r = Random(11);
      final now = DateTime.utc(2026, 6, 13, 9);
      final tasks = _randomTasks(r, 400);
      final reminders = [
        for (var i = 0; i < 160; i++)
          reminder(
            'r$i',
            at: now.add(Duration(hours: 1 + r.nextInt(24 * 20))),
            repeat: i % 3 == 0
                ? 'FREQ=DAILY'
                : i % 7 == 0
                ? 'FREQ=WEEKLY;BYDAY=MO,WE'
                : null,
            notificationId: 1000 + i,
          ),
      ];
      final planInput = input(
        now: now,
        settings: quiet.copyWith(
          notifyReminders: true,
          notifyTasks: true,
          morningBriefing: true,
          badgeMode: BadgeMode.today,
        ),
        reminders: reminders,
        tasks: tasks,
        horizonDays: 14,
        vitalHorizonDays: 120,
        maxScheduled: 240,
      );

      final sw = Stopwatch()..start();
      final plan = NotificationPlanner.plan(planInput, maxCount: 240);
      sw.stop();

      expect(plan.length, lessThanOrEqualTo(240));
      expect(plan, isNotEmpty);
      // The quadratic version took seconds here; this has a wide margin.
      expect(sw.elapsedMilliseconds, lessThan(1500));

      final index = TaskDayIndex(tasks);
      for (final n in plan.take(30)) {
        final day = planInput.calendar.dayNumberOf(n.fireAt);
        expect(n.badge, index.badgeOn(day, BadgeMode.today), reason: n.key);
      }
    });
  });
}
