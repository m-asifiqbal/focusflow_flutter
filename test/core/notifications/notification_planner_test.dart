/// NotificationPlanner — pure planning rules (screens 11, 12, 13, 15, 27, 31):
/// lifecycle filtering, categories, repeats, snooze, quiet hours across
/// midnight, DST, digests, badge, rolling window and unique ids.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/quiet_hours.dart';
import 'package:focusflow/core/notifications/planning/reminder_planner.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

import 'planner_test_data.dart';

void main() {
  final utc = zone('UTC');
  final now = DateTime.utc(2026, 10, 13, 9); // Tue
  final today = DateTime(2026, 10, 13);
  final reminders = quiet.copyWith(notifyReminders: true);

  List<PlannedNotification> plan(
    List<Reminder> rs, {
    AppSettings? settings,
    int? maxCount = NotificationPlanner.defaultMaxCount,
  }) => NotificationPlanner.plan(
    input(now: now, reminders: rs, settings: settings ?? reminders),
    maxCount: maxCount,
  );

  group('reminders', () {
    test('a future one-time reminder keeps its stored id', () {
      final at = DateTime.utc(2026, 10, 13, 15);
      final out = plan([reminder('r1', at: at, notificationId: 4242)]);
      expect(out, hasLength(1));
      final n = out.single;
      expect(n.id, 4242);
      expect(n.fireAt, at);
      expect(n.category, NotificationCategory.reminder);
      // Screen 13: Done, Snooze (default), Open.
      expect(n.buttons, [
        NotificationButton.done,
        NotificationButton.snooze,
        NotificationButton.open,
      ]);
      expect(n.reminderId, 'r1');
      expect(n.key, ReminderPlanner.keyFor('r1', at));
      final p = NotificationPayload.decode(n.payload.encode())!;
      expect(p.target, const ItemRef(ItemType.reminder, 'r1'));
      expect(p.snoozeMinutes, 10);
    });

    test('past, disabled, completed, archived and deleted never notify', () {
      final at = DateTime.utc(2026, 10, 13, 15);
      final out = plan([
        reminder('past', at: DateTime.utc(2026, 10, 13, 8)),
        reminder('off', at: at, enabled: false),
        reminder('done', at: at, completedAt: now),
        reminder('arch', at: at, archivedAt: now),
        reminder('del', at: at, deletedAt: now),
      ]);
      expect(out, isEmpty);
    });

    test('master switch and the Reminders switch silence reminders', () {
      final r = reminder('r', at: DateTime.utc(2026, 10, 13, 15));
      expect(plan([r], settings: quiet), isEmpty);
      expect(
        plan([r], settings: reminders.copyWith(notificationsEnabled: false)),
        isEmpty,
      );
    });

    test('task-linked reminders obey the Tasks switch and task state', () {
      final at = DateTime.utc(2026, 10, 13, 15);
      final link = const ItemRef(ItemType.task, 't1');
      final r = reminder('r', at: at, linked: link);
      List<PlannedNotification> withTask(TaskItem t) =>
          NotificationPlanner.plan(
            input(
              now: now,
              reminders: [r],
              tasks: [t],
              settings: quiet.copyWith(notifyTasks: true),
            ),
          );
      final open = withTask(task('t1', title: 'Pay rent'));
      expect(open.single.category, NotificationCategory.task);
      expect(open.single.payload.open, link);
      expect(open.single.inboxRef, link);
      expect(withTask(task('t1', completedAt: now)), isEmpty);
      expect(withTask(task('t1', archivedAt: now)), isEmpty);
      // Reminders switch alone does not cover task alerts.
      expect(plan([r]), isEmpty);
    });

    test('alarm-style reminders use the alarm category', () {
      final out = plan([
        reminder(
          'a',
          at: DateTime.utc(2026, 10, 13, 15),
          style: AlertStyle.alarm,
        ),
      ]);
      expect(out.single.category, NotificationCategory.alarm);
      expect(out.single.category.channel, NotificationChannelId.alarms);
    });

    test('a snoozed reminder fires at snoozedUntil', () {
      final out = plan([
        reminder(
          's',
          at: DateTime.utc(2026, 10, 13, 8, 50),
          snoozedUntil: DateTime.utc(2026, 10, 13, 9, 5),
          notificationId: 7,
        ),
      ]);
      expect(out.single.fireAt.toUtc(), DateTime.utc(2026, 10, 13, 9, 5));
      expect(out.single.id, 7);
      // Identity stays the rule time (dedupes the inbox entry).
      expect(
        out.single.key,
        contains(
          '${DateTime.utc(2026, 10, 13, 8, 50).millisecondsSinceEpoch ~/ 1000}',
        ),
      );
    });

    test('a daily repeat expands over the window with unique ids', () {
      final out = plan([
        reminder(
          'd',
          at: DateTime.utc(2026, 10, 13, 18),
          repeat: 'FREQ=DAILY',
          notificationId: 99,
        ),
      ]);
      expect(out, hasLength(14));
      expect(out.first.id, 99);
      expect(out.map((n) => n.id).toSet(), hasLength(14));
      expect(out.map((n) => n.key).toSet(), hasLength(14));
      expect(out[1].fireAt.toUtc(), DateTime.utc(2026, 10, 14, 18));
    });

    test('rolling window keeps the soonest maxCount', () {
      final rs = [
        for (var i = 0; i < 100; i++)
          reminder(
            'r$i',
            at: DateTime.utc(2026, 10, 13, 10).add(Duration(minutes: i * 30)),
          ),
      ];
      final out = plan(rs);
      expect(out, hasLength(NotificationPlanner.defaultMaxCount));
      expect(
        out.last.fireAt.toUtc(),
        DateTime.utc(2026, 10, 13, 10).add(const Duration(minutes: 59 * 30)),
      );
      expect(plan(rs, maxCount: null), hasLength(100));
    });

    test('derived ids step aside from a fixed reminder id', () {
      final a = reminder(
        'a',
        at: DateTime.utc(2026, 10, 13, 18),
        repeat: 'FREQ=DAILY',
      );
      final keyB = ReminderPlanner.keyFor('a', DateTime.utc(2026, 10, 14, 18));
      final b = reminder(
        'b',
        at: DateTime.utc(2026, 10, 13, 12),
        notificationId: notificationIdForKey(keyB) + 0, // forced clash
      );
      final out = plan([a, b]);
      final ids = out.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(out.firstWhere((n) => n.reminderId == 'b').id, b.notificationId);
    });
  });

  group('quiet hours', () {
    const q = QuietHours(startMinutes: 22 * 60, endMinutes: 7 * 60);
    final s = reminders.copyWith(quietHours: true);

    test('window wraps midnight', () {
      expect(q.wraps, isTrue);
      expect(q.containsMinute(23 * 60), isTrue);
      expect(q.containsMinute(3 * 60), isTrue);
      expect(q.containsMinute(7 * 60), isFalse);
      expect(q.containsMinute(21 * 60 + 59), isFalse);
      expect(
        const QuietHours(startMinutes: 60, endMinutes: 60).isEmpty,
        isTrue,
      );
    });

    test('late evening moves to next morning, early morning to 07:00', () {
      final out = plan([
        reminder('late', at: DateTime.utc(2026, 10, 13, 23, 30)),
        reminder('early', at: DateTime.utc(2026, 10, 14, 5)),
        reminder('ok', at: DateTime.utc(2026, 10, 13, 7)),
      ], settings: s);
      final byId = {for (final n in out) n.reminderId: n.fireAt.toUtc()};
      expect(byId['late'], DateTime.utc(2026, 10, 14, 7));
      expect(byId['early'], DateTime.utc(2026, 10, 14, 7));
      expect(byId.containsKey('ok'), isFalse); // 07:00 today is past
    });

    test('alarms ignore quiet hours', () {
      final out = plan([
        reminder(
          'a',
          at: DateTime.utc(2026, 10, 13, 23, 30),
          style: AlertStyle.alarm,
        ),
      ], settings: s);
      expect(out.single.fireAt.toUtc(), DateTime.utc(2026, 10, 13, 23, 30));
    });

    test('a window end inside a DST gap never moves earlier', () {
      final ny = zone('America/New_York');
      // 2027-03-14: 02:00 → 03:00. Window 22:00 → 02:30 (does not exist).
      const gap = QuietHours(startMinutes: 22 * 60, endMinutes: 150);
      final fire = ny.at(DateTime(2027, 3, 13), 23 * 60);
      final moved = gap.delay(fire, ny);
      expect(moved.isAfter(fire), isTrue);
      expect(ny.wall(moved).hour, 3);
    });
  });

  group('digests, habits, badge', () {
    test('morning briefing stays at 08:00 wall time across DST', () {
      final ny = zone('America/New_York');
      final out = NotificationPlanner.plan(
        input(
          now: DateTime.utc(2026, 10, 30, 20),
          calendar: ny,
          settings: quiet.copyWith(morningBriefing: true),
          horizonDays: 4,
        ),
      );
      expect(out, hasLength(3)); // Oct 31, Nov 1, Nov 2
      for (final n in out) {
        expect(ny.wall(n.fireAt).hour, 8);
        expect(n.category, NotificationCategory.digest);
      }
      expect(out[0].fireAt.toUtc(), DateTime.utc(2026, 10, 31, 12)); // EDT
      expect(out[1].fireAt.toUtc(), DateTime.utc(2026, 11, 1, 13)); // EST
    });

    test('weekly report only on its weekday; disabled digests skipped', () {
      final out = NotificationPlanner.plan(
        input(
          now: now,
          calendar: utc,
          settings: quiet.copyWith(weeklyReport: true),
          horizonDays: 7,
        ),
      );
      expect(
        out.single.fireAt.toUtc(),
        DateTime.utc(2026, 10, 18, 18),
      ); // Sunday
      expect(out.single.payload.route, isNotNull);
    });

    test('habit check-ins skip today once done; quit habits get no button', () {
      final s = quiet.copyWith(notifyHabits: true);
      final out = NotificationPlanner.plan(
        input(
          now: now,
          settings: s,
          horizonDays: 2,
          habits: [
            habit(
              'water',
              today,
              times: ['10:00', '15:00'],
              count: 6,
              streak: 4,
            ),
            habit('read', today, times: ['20:00'], done: true),
            habit(
              'smoke',
              today,
              kind: HabitKind.quit,
              times: ['21:00'],
              target: 1,
            ),
            habit('mute', today, remind: false),
          ],
        ),
      );
      final keys = out.map((n) => n.key).toList();
      expect(
        keys.where((k) => k.startsWith('hab:water:2026-10-13')),
        hasLength(2),
      );
      expect(keys.where((k) => k.startsWith('hab:read:2026-10-13')), isEmpty);
      expect(
        keys.where((k) => k.startsWith('hab:read:2026-10-14')),
        hasLength(1),
      );
      expect(keys.where((k) => k.contains('mute')), isEmpty);
      final water = out.firstWhere(
        (n) => n.key.startsWith('hab:water:2026-10-13'),
      );
      expect(water.title, 'Drink water — 6/8');
      expect(water.body, contains('2 glasses to go'));
      expect(water.buttons, [NotificationButton.checkIn]);
      expect(out.firstWhere((n) => n.key.contains('smoke')).buttons, isEmpty);
      expect(
        NotificationPlanner.plan(
          input(now: now, settings: quiet, habits: [habit('w', today)]),
        ),
        isEmpty,
      );
    });

    test('streak at risk at 20:00 for an unfinished 2+ day streak', () {
      final out = NotificationPlanner.plan(
        input(
          now: now,
          settings: quiet.copyWith(notifyStreakRisk: true),
          habits: [habit('w', today, streak: 5), habit('x', today, streak: 1)],
        ),
      );
      final first = out.first;
      expect(first.key, 'stk:2026-10-13');
      expect(first.category, NotificationCategory.streak);
      expect(first.fireAt.toUtc(), DateTime.utc(2026, 10, 13, 20));
      expect(first.title, contains('5-day'));
      // Planned ahead (fires even if the app is not opened that day), with
      // the streak projected as if every day in between is checked in.
      final next = out.firstWhere((n) => n.key == 'stk:2026-10-14');
      expect(next.fireAt.toUtc(), DateTime.utc(2026, 10, 14, 20));
      expect(next.title, '2 streaks at risk');
      final later = out.firstWhere((n) => n.key == 'stk:2026-10-15');
      expect(later.fireAt.toUtc(), DateTime.utc(2026, 10, 15, 20));
      expect(
        out.every((n) => n.category == NotificationCategory.streak),
        isTrue,
      );
    });

    test('overdue summary and badge per mode', () {
      final tasks = [
        task('a', title: 'Submit tax documents', due: DateTime(2026, 10, 10)),
        task('b', title: 'Renew gym', due: DateTime(2026, 10, 12)),
        task('c', due: DateTime(2026, 10, 14)),
        task('d', due: DateTime(2026, 10, 1), completedAt: now),
      ];
      final out = NotificationPlanner.plan(
        input(
          now: DateTime.utc(2026, 10, 13, 6),
          tasks: tasks,
          settings: quiet.copyWith(
            notifyTasks: true,
            badgeMode: BadgeMode.overdue,
          ),
          horizonDays: 1,
        ),
      );
      final ovd = out.single;
      expect(ovd.title, '2 tasks are overdue');
      expect(ovd.body, 'Submit tax documents, Renew gym');
      expect(ovd.badge, 2);
      final today = NotificationPlanner.plan(
        input(
          now: DateTime.utc(2026, 10, 13, 6),
          tasks: tasks,
          settings: quiet.copyWith(
            notifyTasks: true,
            badgeMode: BadgeMode.today,
          ),
          horizonDays: 2,
        ),
      );
      // Tomorrow (Oct 14): a, b, c overdue/due.
      expect(today.last.badge, 3);
      final none = NotificationPlanner.plan(
        input(
          now: DateTime.utc(2026, 10, 13, 6),
          tasks: tasks,
          settings: quiet.copyWith(notifyTasks: true),
          horizonDays: 1,
        ),
      );
      expect(none.single.badge, isNull);
    });
  });

  test('a silent reminder is planned silent (and re-scheduled on change)', () {
    final at = DateTime.utc(2026, 10, 13, 10);
    PlannedNotification one(String sound) => NotificationPlanner.plan(
      input(
        now: now,
        settings: quiet.copyWith(notifyReminders: true),
        reminders: [reminder('a', at: at).copyWith(sound: sound)],
      ),
    ).single;
    expect(one('silent').isSilent, isTrue);
    expect(one('chime').isSilent, isFalse);
    expect(one('silent').fingerprint, isNot(one('chime').fingerprint));
  });

  test('stillWanted: due requests of done / switched-off sources', () {
    final at = DateTime.utc(2026, 10, 13, 8, 30);
    final key = ReminderPlanner.keyFor('a', at);
    final on = quiet.copyWith(notifyReminders: true, notifyHabits: true);
    bool wanted(
      String k, {
      AppSettings? s,
      List<Reminder>? r,
      List<HabitDayStatus>? h,
    }) => NotificationPlanner.stillWanted(
      input(
        now: now,
        settings: s ?? on,
        reminders: r ?? [reminder('a', at: at)],
        habits: h ?? [habit('w', today)],
      ),
      k,
    );
    expect(wanted(key), isTrue);
    expect(wanted(key, r: const []), isFalse);
    expect(wanted(key, r: [reminder('a', at: at, enabled: false)]), isFalse);
    expect(wanted(key, s: quiet), isFalse);
    expect(wanted('hab:w:2026-10-13:480'), isTrue);
    expect(
      wanted('hab:w:2026-10-13:480', h: [habit('w', today, done: true)]),
      isFalse,
    );
    expect(wanted('dig:m:2026-10-13'), isTrue);
  });

  test('payload round-trips and ignores garbage', () {
    const p = NotificationPayload(
      key: 'rem:x:1',
      category: NotificationCategory.reminder,
      target: ItemRef(ItemType.reminder, 'x'),
      open: ItemRef(ItemType.task, 't'),
      snoozeMinutes: 15,
    );
    expect(NotificationPayload.decode(p.encode()), p);
    expect(NotificationPayload.decode('nope'), isNull);
    expect(NotificationPayload.decode('{"k":1}'), isNull);
  });
}
