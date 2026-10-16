/// TasksRepository.watchCompletedInRange — completion instants in
/// [from, to), active tasks only, oldest first, live.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  final now = DateTime(2026, 10, 15, 9);

  setUp(() async => h = await TestHarness.create(now: now));
  tearDown(() => h.dispose());

  Future<String> completeAt(String title, DateTime at) async {
    final tasks = h.read(tasksRepositoryProvider);
    final id = await tasks.save(
      TaskItem.draft(now: now, title: title, dueDate: DateTime(2026, 10, 1)),
    );
    h.clock.set(at);
    await tasks.complete(id);
    return id;
  }

  test('returns active tasks completed in [from, to), oldest first', () async {
    final from = DateTime(2026, 10, 9);
    final to = DateTime(2026, 10, 16);
    await completeAt('before', DateTime(2026, 10, 8, 23, 59));
    await completeAt('second', DateTime(2026, 10, 12, 18));
    await completeAt('first', from);
    await completeAt('at end', to);
    final archived = await completeAt('archived', DateTime(2026, 10, 13));
    await h.read(itemsRepositoryProvider).archive([
      ItemRef(ItemType.task, archived),
    ]);
    await h
        .read(tasksRepositoryProvider)
        .save(
          TaskItem.draft(
            now: now,
            title: 'open',
            dueDate: DateTime(2026, 10, 12),
          ),
        );

    final list = await h
        .read(tasksRepositoryProvider)
        .watchCompletedInRange(from, to)
        .first;
    expect(list.map((t) => t.title), ['first', 'second']);
    expect(list.first.completedAt, from);
  });

  test('updates live when a task is completed or reopened', () async {
    final repo = h.read(tasksRepositoryProvider);
    final from = DateTime(2026, 10, 15);
    final to = DateTime(2026, 10, 16);
    final seen = <List<String>>[];
    final sub = repo
        .watchCompletedInRange(from, to)
        .listen((l) => seen.add([for (final t in l) t.title]));
    addTearDown(sub.cancel);
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));
    final id = await repo.save(TaskItem.draft(now: now, title: 'Live'));
    await settle();
    expect(seen.last, isEmpty);
    await repo.complete(id);
    await settle();
    expect(seen.last, ['Live']);
    await repo.uncomplete(id);
    await settle();
    expect(seen.last, isEmpty);
  });
}
