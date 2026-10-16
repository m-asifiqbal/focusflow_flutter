/// InboxRepository — entries of archived / trashed items are hidden from the
/// list and the unread count, and come back when the item is restored.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/domain/repository/inbox_repository.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late InboxRepository inbox;
  final now = DateTime(2026, 10, 12, 9);

  setUp(() async {
    h = await TestHarness.create(now: now);
    inbox = h.read(inboxRepositoryProvider);
  });

  tearDown(() => h.dispose());

  Future<ItemRef> task(String title) async {
    final id = await h
        .read(tasksRepositoryProvider)
        .save(TaskItem(id: '', title: title, createdAt: now, updatedAt: now));
    return ItemRef(ItemType.task, id);
  }

  test('lists entries newest first and counts unread', () async {
    await inbox.add(kind: InboxKind.system, title: 'Old', at: now);
    final id = await inbox.add(
      kind: InboxKind.sync,
      title: 'New',
      at: now.add(const Duration(minutes: 5)),
    );
    expect((await inbox.watch().first).map((e) => e.title), ['New', 'Old']);
    expect(await inbox.watchUnreadCount().first, 2);
    await inbox.markRead(id);
    expect(await inbox.watchUnreadCount().first, 1);
    await inbox.dismiss(id);
    expect((await inbox.watch().first).map((e) => e.title), ['Old']);
  });

  test('hides entries of archived and trashed items, restores them', () async {
    final items = h.read(itemsRepositoryProvider);
    final a = await task('Archived soon');
    final b = await task('Trashed soon');
    final c = await task('Stays');
    for (final (ref, title) in [(a, 'A'), (b, 'B'), (c, 'C')]) {
      await inbox.add(kind: InboxKind.task, title: title, ref: ref, at: now);
    }
    await inbox.add(kind: InboxKind.system, title: 'No item', at: now);
    expect(await inbox.watchUnreadCount().first, 4);

    await items.archive([a]);
    await items.moveToTrash([b]);
    final titles = (await inbox.watch().first).map((e) => e.title).toSet();
    expect(titles, {'C', 'No item'});
    expect(await inbox.watchUnreadCount().first, 2);
    expect(
      (await inbox.watch(kind: InboxKind.task).first).map((e) => e.title),
      ['C'],
    );

    await items.unarchive([a]);
    await items.restoreFromTrash([b]);
    expect((await inbox.watch().first).length, 4);
  });

  test('the live stream re-emits when an item is archived', () async {
    final a = await task('Live');
    await inbox.add(kind: InboxKind.task, title: 'A', ref: a, at: now);
    final emissions = <int>[];
    final sub = inbox.watch().listen((l) => emissions.add(l.length));
    await pumpEventQueue();
    await h.read(itemsRepositoryProvider).archive([a]);
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions.first, 1);
    expect(emissions.last, 0);
  });
}
