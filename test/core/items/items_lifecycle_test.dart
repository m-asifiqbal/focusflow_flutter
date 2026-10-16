/// Items kernel: permanent delete cascade (tags, attachments + files with a
/// shared-file refcount, owned reminders, subtasks, habit logs, vault
/// history), duplicate(), lifecycle dates kept by Undo (`at:`), restore
/// from trash back into the Archive, and the blank-note sweep.
library;

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/attachment_files.dart';
import 'package:focusflow/core/items/data/items_repository_impl.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

final DateTime _now = DateTime(2026, 6, 12, 9, 41);

class _RecordingFiles implements AttachmentFileStore {
  final deleted = <String>[];

  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
}

void main() {
  late TestHarness h;
  late _RecordingFiles files;
  late ItemsRepositoryImpl items;
  var seq = 0;

  setUp(() async {
    h = await TestHarness.create(now: _now);
    files = _RecordingFiles();
    items = ItemsRepositoryImpl(
      db: h.db,
      clock: h.clock,
      deviceId: TestHarness.deviceId,
      newId: () => 'x${seq++}',
      files: files,
    );
  });
  tearDown(() => h.dispose());

  ItemRef note(String id) => ItemRef(ItemType.note, id);

  Future<int> count(String sql) async =>
      (await h.db.customSelect(sql).getSingle()).read<int>('c');

  group('deleteForever', () {
    test(
      'note: tags, attachments (shared file kept), cover, reminder',
      () async {
        final notes = h.read(notesRepositoryProvider);
        final id = await notes.createEmpty(title: 'Trip', tagNames: ['travel']);
        await notes.addAttachment(
          id,
          localPath: 'attachments/a.jpg',
          fileName: 'a',
        );
        await notes.addAttachment(
          id,
          localPath: 'attachments/b.jpg',
          fileName: 'b',
        );
        await notes.setCover(id, 'attachments/a.jpg');
        await h
            .read(remindersRepositoryProvider)
            .upsertLinkedReminder(
              note(id),
              title: 'Trip',
              at: _now.add(const Duration(days: 1)),
            );
        // The copy shares b.jpg (duplicate copies attachment rows).
        final copy = await items.duplicate(note(id));
        await h.db.customStatement(
          "DELETE FROM attachments WHERE item_id = '$copy' "
          "AND local_path = 'attachments/a.jpg'",
        );
        await notes.setCover(copy, null); // only b.jpg is shared

        await items.moveToTrash([note(id)]);
        await items.deleteForever([note(id)]);

        expect(await notes.getNote(id), isNull);
        expect(
          await count("SELECT COUNT(*) c FROM item_tags WHERE item_id = '$id'"),
          0,
        );
        expect(
          await count(
            "SELECT COUNT(*) c FROM attachments WHERE item_id = '$id'",
          ),
          0,
        );
        expect(await count('SELECT COUNT(*) c FROM reminders'), 0);
        // a.jpg only belonged to the deleted note; b.jpg is still the copy's.
        expect(files.deleted, ['attachments/a.jpg']);
        expect(await notes.getNote(copy), isNotNull);
        expect((await notes.getNote(copy))!.tags.single.name, 'travel');
      },
    );

    test('task subtasks + reminder, habit logs, vault history', () async {
      final tasks = h.read(tasksRepositoryProvider);
      final task = await tasks.save(
        TaskItem(id: '', title: 'Ship', createdAt: _now, updatedAt: _now),
      );
      await tasks.addSubtask(task, 'one');
      await tasks.addSubtask(task, 'two');
      await h
          .read(remindersRepositoryProvider)
          .upsertLinkedReminder(
            ItemRef(ItemType.task, task),
            title: 'Ship',
            at: _now.add(const Duration(hours: 2)),
          );
      final habits = h.read(habitsRepositoryProvider);
      final habit = await habits.save(
        Habit.draft(startDate: DateTime(2026, 6, 1), name: 'Read'),
      );
      await habits.increment(habit, DateTime(2026, 6, 11));
      await habits.increment(habit, DateTime(2026, 6, 12));
      await h.db
          .into(h.db.vaultItems)
          .insert(
            VaultItemsCompanion.insert(
              id: 'v1',
              createdAt: _now,
              updatedAt: _now,
              encryptedPayload: Uint8List(4),
              title: const Value('Bank'),
            ),
          );
      await h.db
          .into(h.db.vaultHistory)
          .insert(
            VaultHistoryCompanion.insert(
              id: 'vh1',
              itemId: 'v1',
              encryptedPassword: Uint8List(4),
              changedAt: _now,
            ),
          );
      expect(await count('SELECT COUNT(*) c FROM subtasks'), 2);
      expect(await count('SELECT COUNT(*) c FROM habit_logs'), 2);

      await items.deleteForever([
        ItemRef(ItemType.task, task),
        ItemRef(ItemType.habit, habit),
        const ItemRef(ItemType.vault, 'v1'),
      ]);

      expect(await count('SELECT COUNT(*) c FROM tasks'), 0);
      expect(await count('SELECT COUNT(*) c FROM subtasks'), 0);
      expect(await count('SELECT COUNT(*) c FROM reminders'), 0);
      expect(await count('SELECT COUNT(*) c FROM habits'), 0);
      expect(await count('SELECT COUNT(*) c FROM habit_logs'), 0);
      expect(await count('SELECT COUNT(*) c FROM vault_items'), 0);
      expect(await count('SELECT COUNT(*) c FROM vault_history'), 0);
    });
  });

  test(
    'duplicate copies title, tags, attachments; resets pin / lifecycle',
    () async {
      final notes = h.read(notesRepositoryProvider);
      final id = await notes.createEmpty(title: 'Plan', tagNames: ['work']);
      await notes.addAttachment(
        id,
        localPath: 'attachments/p.png',
        fileName: 'p',
      );
      await notes.setPinned(id, true);
      await items.archive([note(id)]);

      final copy = await items.duplicate(note(id));
      final n = (await notes.getNote(copy))!;
      expect(n.title, 'Plan (copy)');
      expect(n.isPinned, isFalse);
      expect(n.isActive, isTrue);
      expect([for (final t in n.tags) t.name], ['work']);
      expect(
        await count(
          "SELECT COUNT(*) c FROM attachments WHERE item_id = '$copy'",
        ),
        1,
      );
      // The original is untouched.
      expect((await notes.getNote(id))!.isArchived, isTrue);
    },
  );

  test(
    'archive / moveToTrash keep an explicit date (Undo of restore)',
    () async {
      final notes = h.read(notesRepositoryProvider);
      final id = await notes.createEmpty(title: 'Old');
      final archivedAt = DateTime(2026, 3, 1, 10);
      final deletedAt = DateTime(2026, 6, 1, 10);
      await items.archive([note(id)], at: archivedAt);
      await items.moveToTrash([note(id)], at: deletedAt);
      final s = (await items.get(note(id)))!;
      expect(s.archivedAt, archivedAt);
      expect(s.deletedAt, deletedAt);
    },
  );

  test('restore from trash returns an archived item to the Archive', () async {
    final notes = h.read(notesRepositoryProvider);
    final id = await notes.createEmpty(title: 'Kept');
    await items.archive([note(id)]);
    await items.moveToTrash([note(id)]);
    expect(await items.watchArchived().first, isEmpty);

    await items.restoreFromTrash([note(id)]);
    final archived = await items.watchArchived().first;
    expect([for (final s in archived) s.ref], [note(id)]);
    expect(await items.watchTrash().first, isEmpty);
  });

  group('purgeBlankNotes', () {
    test('removes only old, blank, never-synced, untouched notes', () async {
      final notes = h.read(notesRepositoryProvider);
      final reminders = h.read(remindersRepositoryProvider);
      final blank = await notes.createEmpty();
      final titled = await notes.createEmpty(title: 'Real');
      final body = await notes.createEmpty(initialText: 'hello');
      final tagged = await notes.createEmpty(tagNames: ['x']);
      final withImage = await notes.createEmpty();
      await notes.addAttachment(
        withImage,
        localPath: 'attachments/i.png',
        fileName: 'i',
      );
      final withReminder = await notes.createEmpty();
      await reminders.upsertLinkedReminder(
        note(withReminder),
        title: 'Ping',
        at: _now.add(const Duration(days: 2)),
      );
      final pinned = await notes.createEmpty();
      await notes.setPinned(pinned, true);
      final archived = await notes.createEmpty();
      await items.archive([note(archived)]);
      final synced = await notes.createEmpty();
      await h.db.customStatement(
        "UPDATE notes SET last_synced_at = 1 WHERE id = '$synced'",
      );
      final embed = await notes.createEmpty();
      await notes.saveContent(
        embed,
        title: '',
        deltaJson: '[{"insert":{"divider":"hr"}},{"insert":"\\n"}]',
        plainText: '',
        wordCount: 0,
      );

      // Too young: nothing goes.
      expect(await items.purgeBlankNotes(), 0);

      h.clock.advance(const Duration(hours: 2));
      final fresh = await notes.createEmpty(); // just opened in an editor
      expect(await items.purgeBlankNotes(), 1);
      expect(await notes.getNote(blank), isNull);
      for (final id in [
        titled,
        body,
        tagged,
        withImage,
        withReminder,
        pinned,
        archived,
        synced,
        embed,
        fresh,
      ]) {
        expect(await notes.getNote(id), isNotNull, reason: id);
      }
    });
  });

  group('TagsRepository', () {
    test(
      'rename onto an existing name merges; delete + undo re-tags',
      () async {
        final notes = h.read(notesRepositoryProvider);
        final tags = h.read(tagsRepositoryProvider);
        final a = await notes.createEmpty(title: 'A', tagNames: ['ideas']);
        final b = await notes.createEmpty(
          title: 'B',
          tagNames: ['idea', 'ideas'],
        );
        final idea = await tags.findOrCreate('idea');
        final ideas = await tags.findOrCreate('ideas');

        await tags.rename(idea, 'Ideas');
        final all = await tags.watchTags().first;
        expect([for (final t in all) t.name], ['ideas']);
        expect(all.single.id, ideas);
        expect((await notes.getNote(b))!.tags.length, 1, reason: 'one copy');

        // Delete, then the Library's Undo: re-create + re-tag.
        final tagged = [note(a), note(b)];
        await tags.delete(ideas);
        expect(await tags.watchTags().first, isEmpty);
        expect((await notes.getNote(a))!.tags, isEmpty);
        await tags.findOrCreate('ideas');
        await h.read(itemsRepositoryProvider).addTags(tagged, ['ideas']);
        for (final id in [a, b]) {
          expect(
            [for (final t in (await notes.getNote(id))!.tags) t.name],
            ['ideas'],
          );
        }
      },
    );
  });
}
