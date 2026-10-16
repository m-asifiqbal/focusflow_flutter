/// Acting on one *occurrence* of a reminder (the row the user tapped):
/// snooze and mark done on repeating reminders with a stale anchor, COUNT
/// rules and early completion; the list's MARK DONE and the notification's
/// Done share one function (a one-time task reminder completes its task,
/// Undo reopens it); task reminders follow a zone change unless moved by
/// hand; an unrelated task save keeps a rescheduled reminder's time.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/reminder_planner.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/reminders/data/repository/reminders_repository_impl.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_actions.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../isolated_notifications.dart';

void main() {
  // Tue 13 Oct 2026, 12:00.
  final now = DateTime(2026, 10, 13, 12);
  DateTime day(int d, [int h = 9]) => DateTime(2026, 10, d, h);

  late TestHarness h;
  late RemindersRepository repo;

  setUp(() async {
    h = await TestHarness.create(now: now, overrides: isolatedNotifications());
    repo = h.read(remindersRepositoryProvider);
  });
  tearDown(() => h.dispose());

  Future<String> add(DateTime at, {String? rrule, ItemRef? link}) => repo.save(
    Reminder.draft(
      triggerAt: at,
      title: 'Vitamins',
      repeatRule: rrule,
      linkedRef: link,
    ),
  );

  Future<Reminder> get(String id) async => (await repo.getReminder(id))!;

  group('snooze an occurrence', () {
    test('next-due card of a stale daily reminder snoozes that occurrence '
        'and it does not fire twice', () async {
      // Anchor Oct 10 never marked done; the next-due card is Oct 14 09:00.
      final id = await add(day(10), rrule: 'FREQ=DAILY');
      final next = ReminderSchedule.next(await get(id), now)!;
      expect(next.at, day(14));

      await h
          .read(reminderActionsProvider)
          .snooze(id, minutes: 10, occurrence: next.at);
      final r = await get(id);
      expect(r.snoozedUntil, DateTime(2026, 10, 14, 9, 10));
      expect(r.triggerAt, day(14)); // re-anchored at the snoozed one

      final fires = [
        for (final (_, at) in ReminderPlanner.slots(r, now, day(16, 0))) at,
      ];
      // Oct 14 fires once, at 09:10 — not also at 09:00.
      expect(fires, [DateTime(2026, 10, 14, 9, 10), day(15)]);
    });

    test('a past occurrence snoozes from now', () async {
      final id = await add(day(10), rrule: 'FREQ=DAILY');
      await h
          .read(reminderActionsProvider)
          .snooze(id, minutes: 10, occurrence: day(13));
      final r = await get(id);
      expect(r.snoozedUntil, now.add(const Duration(minutes: 10)));
      expect(r.triggerAt, day(13));
    });

    test('COUNT shrinks by the skipped occurrences', () async {
      // Oct 10 … Oct 14.
      final id = await add(day(10), rrule: 'FREQ=DAILY;COUNT=5');
      await repo.snoozeUntil(
        id,
        now.add(const Duration(minutes: 5)),
        occurrence: day(12),
      );
      final r = await get(id);
      expect(r.triggerAt, day(12));
      expect(r.recurrence!.count, 3); // Oct 12, 13, 14 remain
    });

    test('the pending occurrence is not re-anchored', () async {
      final id = await add(day(14), rrule: 'FREQ=DAILY');
      await repo.snoozeUntil(
        id,
        DateTime(2026, 10, 14, 9, 30),
        occurrence: day(14),
      );
      final r = await get(id);
      expect(r.triggerAt, day(14));
      expect(
        RemindersRepositoryImpl.laterOccurrence(r, r.snoozedUntil),
        isNull,
      );
      expect(RemindersRepositoryImpl.laterOccurrence(r, day(15)), day(15));
      expect(
        RemindersRepositoryImpl.laterOccurrence(r, DateTime(2026, 10, 15, 8)),
        isNull,
      );
    });
  });

  group('mark done an occurrence', () {
    test(
      'a future occurrence is the one acknowledged (stale anchor)',
      () async {
        final id = await add(day(10), rrule: 'FREQ=DAILY');
        final before = await repo.markDone(id, occurrence: day(14));
        expect(before, isNotNull);
        final r = await get(id);
        expect(r.lastDoneAt, day(14));
        expect(r.triggerAt, day(15));
      },
    );

    test('without an occurrence: the latest due one (old behaviour)', () async {
      final id = await add(day(10), rrule: 'FREQ=DAILY');
      await repo.markDone(id);
      final r = await get(id);
      expect(r.lastDoneAt, day(13));
      expect(r.triggerAt, day(14));
    });

    test('done early acknowledges the pending occurrence', () async {
      final id = await add(day(14), rrule: 'FREQ=DAILY');
      await repo.markDone(id, occurrence: day(14));
      final r = await get(id);
      expect(r.lastDoneAt, day(14));
      expect(r.triggerAt, day(15));
    });

    test('COUNT: the series ends after its last occurrence', () async {
      final id = await add(day(10), rrule: 'FREQ=DAILY;COUNT=5');
      await repo.markDone(id, occurrence: day(12));
      var r = await get(id);
      expect(r.triggerAt, day(13));
      expect(r.recurrence!.count, 2);
      await repo.markDone(id, occurrence: day(14));
      r = await get(id);
      expect(r.isRecurring, isFalse);
      expect(r.isCompleted, isTrue);
      expect(r.triggerAt, day(14));
    });

    test('an occurrence already behind the pending one is a no-op', () async {
      final id = await add(day(14), rrule: 'FREQ=DAILY');
      expect(await repo.markDone(id, occurrence: day(12)), isNull);
      expect((await get(id)).triggerAt, day(14));
    });
  });

  group('MARK DONE parity (list = notification Done)', () {
    Future<(String, String)> taskWithReminder() async {
      final taskId = await h
          .read(tasksRepositoryProvider)
          .save(TaskItem.draft(now: now, title: 'Pay rent'));
      final rid = await add(day(13, 11), link: ItemRef(ItemType.task, taskId));
      return (taskId, rid);
    }

    test(
      'list MARK DONE completes the linked one-time task; undo reopens',
      () async {
        final (taskId, rid) = await taskWithReminder();
        final actions = h.read(reminderActionsProvider);
        final done = await actions.complete(rid, occurrence: day(13, 11));
        expect(done, isNotNull);
        expect((await get(rid)).isCompleted, isTrue);
        final tasks = h.read(tasksRepositoryProvider);
        expect((await tasks.getTask(taskId))!.isCompleted, isTrue);

        await actions.undoComplete(done!);
        expect((await get(rid)).isCompleted, isFalse);
        expect((await tasks.getTask(taskId))!.isCompleted, isFalse);
      },
    );

    test('notification Done does exactly the same', () async {
      final (taskId, rid) = await taskWithReminder();
      final ok = await h
          .read(notificationActionsProvider)
          .markDone(ItemRef(ItemType.reminder, rid), occurrence: day(13, 11));
      expect(ok, isTrue);
      expect((await get(rid)).isCompleted, isTrue);
      final task = await h.read(tasksRepositoryProvider).getTask(taskId);
      expect(task!.isCompleted, isTrue);
    });
  });

  group('task reminders', () {
    Future<TaskItem> remindedTask() async {
      final tasks = h.read(tasksRepositoryProvider);
      final id = await tasks.save(
        TaskItem.draft(
          now: now,
          title: 'Report',
          dueDate: DateTime(2026, 10, 14),
          dueTimeMinutes: 10 * 60,
        ).copyWith(remindOffsetMinutes: 15),
      );
      return (await tasks.getTask(id))!;
    }

    test('follow a zone change unless moved by hand', () async {
      final task = await remindedTask();
      final rid = task.reminderId!;
      expect((await get(rid)).triggerAt, DateTime(2026, 10, 14, 9, 45));

      // A zone 3 h behind the device: the same wall time is 3 h later.
      DateTime west(DateTime d, int m) =>
          DateUtilsX.atMinutes(d, m).add(const Duration(hours: 3));
      expect(await repo.resyncTaskReminders(west), 1);
      expect((await get(rid)).triggerAt, DateTime(2026, 10, 14, 12, 45));
      expect(await repo.resyncTaskReminders(west), 0); // idempotent

      // Back from `west` to a zone 1 h ahead of the device.
      DateTime east(DateTime d, int m) =>
          DateUtilsX.atMinutes(d, m).subtract(const Duration(hours: 1));
      expect(await repo.resyncTaskReminders(east, from: [west]), 1);
      expect((await get(rid)).triggerAt, DateTime(2026, 10, 14, 8, 45));

      // Moved by hand: stays put.
      await repo.reschedule(rid, DateTime(2026, 10, 14, 7));
      expect(await repo.resyncTaskReminders(west, from: [east]), 0);
      expect((await get(rid)).triggerAt, DateTime(2026, 10, 14, 7));
    });

    test('an unrelated task save keeps a rescheduled reminder time', () async {
      final tasks = h.read(tasksRepositoryProvider);
      final task = await remindedTask();
      final rid = task.reminderId!;
      await repo.reschedule(rid, DateTime(2026, 10, 14, 11));

      await tasks.save(task.copyWith(title: 'Quarterly report'));
      var r = await get(rid);
      expect(r.triggerAt, DateTime(2026, 10, 14, 11));
      expect(r.title, 'Quarterly report');

      // Changing the schedule moves it again.
      final fresh = (await tasks.getTask(task.id))!;
      await tasks.save(fresh.copyWith(dueTimeMinutes: 16 * 60));
      r = await get(rid);
      expect(r.triggerAt, DateTime(2026, 10, 14, 15, 45));
    });
  });
}
