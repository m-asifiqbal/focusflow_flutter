/// TaskCompletionController / TaskActions: completing a repeating task and
/// undoing (or reopening) it discards the spawned next occurrence; reorder
/// in smart sort writes the visible order; a completion that lands after
/// the task was completed elsewhere is a no-op (never reopens it); reschedule returns a working
/// Undo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

void main() {
  final now = DateTime(2026, 6, 13, 9);
  late TestHarness h;
  late TasksRepository repo;

  TaskItem draft(String title, {DateTime? due, String? rrule}) => TaskItem(
    id: '',
    title: title,
    dueDate: due,
    repeatRule: rrule,
    createdAt: now,
    updatedAt: now,
  );

  Future<List<TaskItem>> all() => repo.watchTasks(const TasksQuery()).first;

  setUp(() async {
    h = await TestHarness.create(now: now, overrides: isolatedNotifications());
    repo = h.read(tasksRepositoryProvider);
  });

  tearDown(() => h.dispose());

  test('undo of a repeating completion removes the next occurrence', () async {
    final id = await repo.save(
      draft('Water plants', due: DateTime(2026, 6, 13), rrule: 'FREQ=DAILY'),
    );
    final controller = h.read(taskCompletionProvider.notifier);
    controller.complete(id, after: Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var tasks = await all();
    expect(tasks, hasLength(2));
    expect(tasks.firstWhere((t) => t.id == id).isCompleted, isTrue);
    final next = tasks.firstWhere((t) => t.id != id);
    expect(next.dueDate, DateTime(2026, 6, 14));
    expect(h.read(taskCompletionProvider), isEmpty);

    await controller.undo(id);
    tasks = await all();
    expect(tasks, hasLength(1));
    expect(tasks.single.isCompleted, isFalse);
  });

  test('reopen after the snackbar also removes the next occurrence', () async {
    final id = await repo.save(
      draft('Water plants', due: DateTime(2026, 6, 13), rrule: 'FREQ=DAILY'),
    );
    final controller = h.read(taskCompletionProvider.notifier);
    controller.complete(id, after: Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await all(), hasLength(2));

    await controller.reopen(id);
    final tasks = await all();
    expect(tasks, hasLength(1));
    expect(tasks.single.id, id);
    expect(tasks.single.isCompleted, isFalse);
  });

  test('reopen keeps a next occurrence that was already completed', () async {
    final id = await repo.save(
      draft('Water plants', due: DateTime(2026, 6, 13), rrule: 'FREQ=DAILY'),
    );
    final controller = h.read(taskCompletionProvider.notifier);
    controller.complete(id, after: Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final next = (await all()).firstWhere((t) => t.id != id);
    await repo.toggleComplete(next.id);

    await controller.reopen(id);
    final tasks = await all();
    expect(tasks.firstWhere((t) => t.id == id).isCompleted, isFalse);
    expect(tasks.any((t) => t.id == next.id), isTrue);
  });

  test(
    'a task completed elsewhere before the timer fires stays done',
    () async {
      final id = await repo.save(
        draft('Water plants', due: DateTime(2026, 6, 13), rrule: 'FREQ=DAILY'),
      );
      final controller = h.read(taskCompletionProvider.notifier);
      controller.complete(id, after: const Duration(milliseconds: 40));
      // Another screen / device completes it first.
      await repo.complete(id);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      var tasks = await all();
      expect(tasks.firstWhere((t) => t.id == id).isCompleted, isTrue);
      // Only the one next occurrence from the first completion.
      expect(tasks.where((t) => t.id != id), hasLength(1));
      expect(h.read(taskCompletionProvider), isEmpty);

      // Undo of this tap changed nothing, so it must not reopen the task.
      await controller.undo(id);
      tasks = await all();
      expect(tasks.firstWhere((t) => t.id == id).isCompleted, isTrue);
      expect(tasks, hasLength(2));
    },
  );

  test('repository complete is idempotent', () async {
    final id = await repo.save(draft('Once'));
    expect((await repo.complete(id)).completed, isTrue);
    final again = await repo.complete(id);
    expect(again.completed, isFalse);
    expect((await repo.getTask(id))!.isCompleted, isTrue);
  });

  test('undo before the delay cancels the pending completion', () async {
    final id = await repo.save(draft('Call mom', due: DateTime(2026, 6, 13)));
    final controller = h.read(taskCompletionProvider.notifier);
    controller.complete(id);
    expect(controller.isPending(id), isTrue);
    await controller.undo(id);
    expect(controller.isPending(id), isFalse);
    await Future<void>.delayed(TaskCompletionController.delay * 1.2);
    expect((await repo.getTask(id))!.isCompleted, isFalse);
  });

  test('reorder in smart sort writes the visible order', () async {
    final a = await repo.save(draft('A'));
    final b = await repo.save(draft('B'));
    final c = await repo.save(draft('C'));
    final section = [
      for (final id in [a, b, c]) (await repo.getTask(id))!,
    ];
    final changed = await h
        .read(taskActionsProvider)
        .reorder(section, 2, 0, sort: TaskSort.smart);
    expect(changed, isTrue);
    final sections = await repo
        .watchSections(const TasksQuery(), manual: true)
        .first;
    expect(sections.noDate.map((t) => t.title), ['C', 'A', 'B']);
  });

  test('the first smart-sort drag keeps the other sections in place', () async {
    final today = DateTime(2026, 6, 13);
    // Today: smart order = High first, then Low (priority); their stored
    // sortOrder (creation) is the reverse.
    await repo.save(draft('Low', due: today));
    final high = await repo.save(draft('High', due: today));
    await repo.save(
      (await repo.getTask(high))!.copyWith(priority: TaskPriority.high),
    );
    final a = await repo.save(draft('A'));
    final b = await repo.save(draft('B'));
    final smart = await repo.watchSections(TasksQuery(day: today)).first;
    expect(smart.today.map((t) => t.title), ['High', 'Low']);
    final visible = [for (final (_, ts) in smart.nonEmpty) ...ts];
    await h
        .read(taskActionsProvider)
        .reorder(smart.noDate, 1, 0, sort: TaskSort.smart, visible: visible);
    final manual = await repo
        .watchSections(TasksQuery(day: today), manual: true)
        .first;
    expect(manual.noDate.map((t) => t.id), [b, a]);
    expect(manual.today.map((t) => t.title), ['High', 'Low']);
  });

  test('reschedule returns an undo that restores the dates', () async {
    final a = await repo.save(draft('A', due: DateTime(2026, 6, 10)));
    final b = await repo.save(draft('B', due: DateTime(2026, 6, 11)));
    final tasks = [(await repo.getTask(a))!, (await repo.getTask(b))!];
    final undo = await h
        .read(taskActionsProvider)
        .reschedule(tasks, DateTime(2026, 6, 13));
    expect((await repo.getTask(a))!.dueDate, DateTime(2026, 6, 13));
    await undo();
    expect((await repo.getTask(a))!.dueDate, DateTime(2026, 6, 10));
    expect((await repo.getTask(b))!.dueDate, DateTime(2026, 6, 11));
  });

  test('board Done → To do discards the spawned next occurrence', () async {
    final id = await repo.save(
      draft('Water plants', due: DateTime(2026, 6, 13), rrule: 'FREQ=DAILY'),
    );
    final actions = h.read(taskActionsProvider);
    await actions.moveOnBoard((await repo.getTask(id))!, 2);
    var tasks = await all();
    expect(tasks, hasLength(2));

    await actions.moveOnBoard((await repo.getTask(id))!, 0);
    tasks = await all();
    expect(tasks, hasLength(1));
    expect(tasks.single.id, id);
    expect(tasks.single.isCompleted, isFalse);
    expect(tasks.single.boardStatus, 0);
  });
}
