/// Task editor controller (screen 11): route prefill parsing, form edits
/// stay in memory until Save, subtask add / reorder / remove / restore,
/// clearing the date clears what depends on it, and Save creates the
/// linked reminder (then removes it again when "Remind me" is cleared).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_editor_controller.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

void main() {
  final now = DateTime(2026, 6, 13, 9);
  final today = DateTime(2026, 6, 13);
  late TestHarness h;
  ProviderSubscription<AsyncValue<TaskEditorState>>? sub;

  Future<TaskEditorController> open(TaskEditorArgs args) async {
    final provider = taskEditorControllerProvider(args);
    sub = h.container.listen(provider, (_, _) {});
    await h.container.read(provider.future);
    return h.read(provider.notifier);
  }

  TaskEditorState form(TaskEditorArgs args) =>
      h.read(taskEditorControllerProvider(args)).requireValue;

  setUp(
    () async => h = await TestHarness.create(
      now: now,
      overrides: isolatedNotifications(),
    ),
  );
  tearDown(() async {
    sub?.close();
    sub = null;
    await h.dispose();
  });

  test('args parse the /tasks/new query', () {
    final args = TaskEditorArgs.fromRoute('new', {
      'title': ' Buy milk ',
      'date': '2026-06-20',
      'time': '540',
      'priority': '3',
      'tag': 'home',
      'rrule': 'FREQ=WEEKLY',
    });
    expect(args.isNew, isTrue);
    expect(args.title, 'Buy milk');
    expect(args.time, 540);
    expect(args.priority, 3);
    expect(TaskEditorArgs.fromRoute('abc', const {}).id, 'abc');
  });

  test('a repeat or time without a date anchors on today', () async {
    const args = TaskEditorArgs(time: 600, repeatRule: 'FREQ=DAILY');
    await open(args);
    final s = form(args);
    expect(s.draft.dueDate, today);
    expect(s.draft.dueTimeMinutes, 600);
    expect(s.draft.repeatRule, 'FREQ=DAILY');
    expect(s.canSave, isFalse);
    expect(s.isDirty, isFalse);
  });

  test('subtasks: add, reorder, remove and restore', () async {
    const args = TaskEditorArgs(title: 'Trip');
    final c = await open(args);
    final a = c.addSubtask(title: 'A');
    c.addSubtask(title: 'B');
    c.addSubtask(afterKey: a, title: 'A2');
    expect(form(args).subtasks.map((e) => e.title), ['A', 'A2', 'B']);

    c.moveSubtask(2, 0);
    expect(form(args).subtasks.map((e) => e.title), ['B', 'A', 'A2']);

    final row = form(args).subtasks[1];
    final index = c.removeSubtask(row.key);
    expect(form(args).subtasks.map((e) => e.title), ['B', 'A2']);
    c.restoreSubtask(index, row);
    expect(form(args).subtasks.map((e) => e.title), ['B', 'A', 'A2']);

    c.toggleSubtask(row.key);
    expect(form(args).subtaskDone, 1);
  });

  test('clearing the date clears time, repeat and reminder', () async {
    const args = TaskEditorArgs(title: 'Gym', date: '2026-06-14', time: 420);
    final c = await open(args);
    c.setRepeat('FREQ=DAILY', today: today);
    c.setRemind(15, today: today);
    c.setDate(null);
    final t = form(args).draft;
    expect(t.dueDate, isNull);
    expect(t.repeatRule, isNull);
    expect(t.remindOffsetMinutes, isNull);
  });

  test('Save writes the task with its reminder; edits reload', () async {
    const args = TaskEditorArgs(date: '2026-06-14', time: 540);
    final c = await open(args);
    c.setTitle('  Dentist  ');
    c.setRemind(30, today: today);
    c.setPriority(TaskPriority.high);
    c.addSubtask(title: 'Call first');
    c.addSubtask(); // blank rows are dropped
    expect(form(args).isDirty, isTrue);
    final id = (await c.save())!;
    sub?.close();

    final repo = h.read(tasksRepositoryProvider);
    var task = (await repo.getTask(id))!;
    expect(task.title, 'Dentist');
    expect(task.priority, TaskPriority.high);
    expect(task.subtasks.map((s) => s.title), ['Call first']);
    expect(task.reminderId, isNotNull);
    final reminder = await h
        .read(remindersRepositoryProvider)
        .getReminder(task.reminderId!);
    expect(reminder, isNotNull);

    final edit = TaskEditorArgs(id: id);
    final c2 = await open(edit);
    expect(form(edit).isDirty, isFalse);
    c2.setRemind(null, today: today);
    await c2.save();
    task = (await repo.getTask(id))!;
    expect(task.reminderId, isNull);
  });

  test('a missing task fails with TaskNotFoundException', () async {
    const args = TaskEditorArgs(id: 'missing');
    final provider = taskEditorControllerProvider(args);
    sub = h.container.listen(provider, (_, _) {});
    await expectLater(
      h.container.read(provider.future),
      throwsA(isA<TaskNotFoundException>()),
    );
  });
}
