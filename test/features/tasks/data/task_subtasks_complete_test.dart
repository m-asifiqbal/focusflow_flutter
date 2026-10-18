/// Completing a task completes its subtasks; Undo gives back exactly what the
/// completion ticked (a subtask finished earlier stays finished).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late TasksRepository tasks;
  final now = DateTime(2026, 6, 13, 9);

  setUp(() async {
    h = await TestHarness.create(now: now);
    tasks = h.read(tasksRepositoryProvider);
  });
  tearDown(() => h.dispose());

  Future<String> withSubtasks({String? repeat}) => tasks.save(
    TaskItem(
      id: '',
      title: 'Trip',
      repeatRule: repeat,
      dueDate: repeat == null ? null : DateTime(2026, 6, 13),
      subtasks: const [
        Subtask.draft('Passport', done: true),
        Subtask.draft('Tickets'),
        Subtask.draft('Pack'),
      ],
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<List<bool>> done(String id) async => [
    for (final s in (await tasks.getTask(id))!.subtasks) s.done,
  ];

  test('completing the task ticks every open subtask', () async {
    final id = await withSubtasks();
    expect(await done(id), [true, false, false]);

    final result = await tasks.complete(id);

    expect(result.completed, isTrue);
    expect(await done(id), [true, true, true]);
    expect(
      result.completedSubtaskIds,
      hasLength(2),
      reason: 'only the open ones',
    );
  });

  test('Undo un-ticks only what the completion ticked', () async {
    final id = await withSubtasks();
    final result = await tasks.complete(id);

    await tasks.uncomplete(id, reopenSubtaskIds: result.completedSubtaskIds);

    expect((await tasks.getTask(id))!.isCompleted, isFalse);
    expect(await done(id), [true, false, false]);
  });

  test('reopening without Undo data leaves the subtasks as they are', () async {
    final id = await withSubtasks();
    await tasks.complete(id);
    await tasks.uncomplete(id);
    expect(await done(id), [true, true, true]);
  });

  test(
    'a repeating task: the next occurrence starts with open subtasks',
    () async {
      final id = await withSubtasks(repeat: 'FREQ=DAILY');
      final result = await tasks.complete(id);

      expect(await done(id), [true, true, true]);
      final next = (await tasks.getTask(result.nextOccurrenceId!))!;
      expect(next.subtasks.map((s) => s.done), [false, false, false]);
    },
  );

  test('a task without subtasks completes as before', () async {
    final id = await tasks.save(
      TaskItem(id: '', title: 'Plain', createdAt: now, updatedAt: now),
    );
    final result = await tasks.complete(id);
    expect(result.completed, isTrue);
    expect(result.completedSubtaskIds, isEmpty);
  });

  test('toggleSubtask flips one subtask only', () async {
    final id = await withSubtasks();
    final t = (await tasks.getTask(id))!;
    await tasks.toggleSubtask(t.subtasks[1].id);
    expect(await done(id), [true, true, false]);
    expect((await tasks.getTask(id))!.isCompleted, isFalse);
  });
}
