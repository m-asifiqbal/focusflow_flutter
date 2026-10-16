/// TasksRepository — due dates as floating days, scopes, and the task's own
/// "Remind me" reminder respecting the item lifecycle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late TasksRepository tasks;

  final now = DateTime(2026, 6, 13, 9);

  TaskItem draft(String title, {DateTime? due, int? time, int? remind}) =>
      TaskItem(
        id: '',
        title: title,
        dueDate: due,
        dueTimeMinutes: time,
        remindOffsetMinutes: remind,
        createdAt: now,
        updatedAt: now,
      );

  setUp(() async {
    h = await TestHarness.create(now: now);
    tasks = h.read(tasksRepositoryProvider);
  });

  tearDown(() => h.dispose());

  group('due dates', () {
    test('round-trip as the same calendar day', () async {
      final id = await tasks.save(
        draft('Pay rent', due: DateTime(2026, 6, 14)),
      );
      final t = await tasks.getTask(id);
      expect(t!.dueDate, DateTime(2026, 6, 14));
    });

    test('are stored as floating days (UTC midnight of the date)', () async {
      final id = await tasks.save(
        draft('Pay rent', due: DateTime(2026, 6, 14)),
      );
      final row = await (h.db.select(
        h.db.tasks,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.dueDate!.toUtc(), DateTime.utc(2026, 6, 14));
      expect(DateUtilsX.fromStoredDay(row.dueDate!), DateTime(2026, 6, 14));
    });

    test('scopes split today / overdue / upcoming by calendar day', () async {
      await tasks.save(draft('yesterday', due: DateTime(2026, 6, 12)));
      await tasks.save(draft('today', due: DateTime(2026, 6, 13), time: 600));
      await tasks.save(draft('tomorrow', due: DateTime(2026, 6, 14)));
      await tasks.save(draft('no date'));

      Future<List<String>> titles(TasksScope scope) async =>
          (await tasks.watchTasks(TasksQuery(scope: scope)).first)
              .map((t) => t.title)
              .toList();

      expect(await titles(TasksScope.overdue), ['yesterday']);
      expect(
        await titles(TasksScope.today),
        containsAll(['yesterday', 'today']),
      );
      expect(await titles(TasksScope.today), isNot(contains('tomorrow')));
      expect(await titles(TasksScope.upcoming), ['tomorrow']);
      expect(await titles(TasksScope.noDate), ['no date']);

      final stats = await tasks.watchStats(now).first;
      expect(stats.today, 1);
      expect(stats.overdue, 1);
      expect(stats.upcoming, 1);

      final day = await tasks.watchTasksForDay(DateTime(2026, 6, 14)).first;
      expect(day.map((t) => t.title), ['tomorrow']);
    });

    test('reschedule keeps the chosen calendar day', () async {
      final id = await tasks.save(draft('Move me', due: DateTime(2026, 6, 13)));
      await tasks.reschedule([id], DateTime(2026, 6, 20, 15, 30));
      expect((await tasks.getTask(id))!.dueDate, DateTime(2026, 6, 20));
    });

    test('library counts and summaries use the same day encoding', () async {
      await tasks.save(draft('today', due: DateTime(2026, 6, 13), time: 540));
      await tasks.save(draft('late', due: DateTime(2026, 6, 10)));
      final items = h.read(itemsRepositoryProvider);
      final counts = await items.watchLibraryCounts(now: now).first;
      expect(counts.tasksDueToday, 1);
      expect(counts.tasksOverdue, 1);

      final id = (await tasks.watchTasks(const TasksQuery()).first)
          .firstWhere((t) => t.title == 'today')
          .id;
      final summary = await items.get(ItemRef(ItemType.task, id));
      expect(summary!.scheduledAt, DateTime(2026, 6, 13, 9));
    });
  });

  group('"Remind me" reminder', () {
    Future<String> taskWithReminder() => tasks.save(
      draft('Call bank', due: DateTime(2026, 6, 13), time: 600, remind: 15),
    );

    test('is created at due time minus the offset', () async {
      final id = await taskWithReminder();
      final t = await tasks.getTask(id);
      final row = await (h.db.select(
        h.db.reminders,
      )..where((r) => r.id.equals(t!.reminderId!))).getSingle();
      expect(row.triggerAt, DateTime(2026, 6, 13, 9, 45));
      expect(row.linkedItemId, id);
    });

    test('a trashed reminder is not revived by the next save', () async {
      final id = await taskWithReminder();
      final reminderId = (await tasks.getTask(id))!.reminderId!;
      final items = h.read(itemsRepositoryProvider);
      await items.moveToTrash([ItemRef(ItemType.reminder, reminderId)]);

      final t = (await tasks.getTask(id))!;
      await tasks.save(t.copyWith(title: 'Call the bank'));

      final row = await (h.db.select(
        h.db.reminders,
      )..where((r) => r.id.equals(reminderId))).getSingle();
      expect(row.deletedAt, isNotNull, reason: 'stays in Recently Deleted');
      final after = (await tasks.getTask(id))!;
      expect(after.reminderId, isNull);
      expect(after.remindOffsetMinutes, isNull);
      expect(await h.db.select(h.db.reminders).get(), hasLength(1));
    });

    test('undoing the trash keeps the task linked', () async {
      final id = await taskWithReminder();
      final reminderId = (await tasks.getTask(id))!.reminderId!;
      final items = h.read(itemsRepositoryProvider);
      final ref = ItemRef(ItemType.reminder, reminderId);
      await items.moveToTrash([ref]);
      await items.restoreFromTrash([ref]);

      final t = (await tasks.getTask(id))!;
      await tasks.save(t.copyWith(title: 'Call the bank'));
      final after = (await tasks.getTask(id))!;
      expect(after.reminderId, reminderId);
      final row = await (h.db.select(
        h.db.reminders,
      )..where((r) => r.id.equals(reminderId))).getSingle();
      expect(row.title, 'Call the bank');
      expect(row.deletedAt, isNull);
    });

    test(
      'switching "Remind me" off deletes the reminder and its tags',
      () async {
        final id = await taskWithReminder();
        final reminderId = (await tasks.getTask(id))!.reminderId!;
        await h.read(itemsRepositoryProvider).setTags(
          ItemRef(ItemType.reminder, reminderId),
          ['bank'],
        );

        final t = (await tasks.getTask(id))!;
        await tasks.save(t.copyWith(clearRemindOffset: true));

        expect(await h.db.select(h.db.reminders).get(), isEmpty);
        expect(await h.db.select(h.db.itemTags).get(), isEmpty);
      },
    );
  });
}
