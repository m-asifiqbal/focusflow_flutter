/// Shared fixtures for the core/sync tests: a representative database
/// (every synced table has rows, incl. a tombstone, files and vault
/// ciphertext), raw-snapshot editing and a [BackupEngine] over a harness.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

/// Before the real wall clock, so SQL trigger tombstones ("now") are
/// always newer than anything the fake clock writes.
final syncNow = DateTime(2026, 1, 10, 9);

/// Unix seconds (how Drift stores DateTimes in raw rows).
int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// A temp-dir [AppFiles] deleted with the test.
AppFiles tempFiles(void Function(void Function()) addTearDown) {
  final dir = Directory.systemTemp.createTempSync('ff_files');
  addTearDown(() => dir.deleteSync(recursive: true));
  return AppFiles.at(dir);
}

/// Vault bridge with a fixed answer for [acceptKeyEnvelope].
class FakeVaultBridge extends NoVaultBackupBridge {
  const FakeVaultBridge({this.accept = true, this.envelope});

  final bool accept;
  final Map<String, Object?>? envelope;

  @override
  Future<Map<String, Object?>?> exportKeyEnvelope() async => envelope;

  @override
  Future<bool> acceptKeyEnvelope(Map<String, Object?>? envelope) async =>
      accept;
}

BackupEngine engineFor(
  TestHarness h,
  AppFiles files, {
  VaultBackupBridge vault = const FakeVaultBridge(),
}) => BackupEngine(
  db: h.db,
  items: h.read(itemsRepositoryProvider),
  files: files,
  deviceId: TestHarness.deviceId,
  vault: vault,
  clock: h.clock,
);

/// Ids of the rows [seedSample] created.
typedef SampleIds = ({String note, String task, String habit, String folder});

/// Fills every synced table: folder, tag, note (+ attachment + cover file),
/// task (+ subtask), habit (+ log), reminder, vault item (+ history),
/// focus session and one permanently deleted note (tombstone).
Future<SampleIds> seedSample(TestHarness h, AppFiles files) async {
  final db = h.db;
  final now = h.clock.now();
  final folder = await h
      .read(foldersRepositoryProvider)
      .create(ItemType.note, 'Ideas');
  final notes = h.read(notesRepositoryProvider);
  final note = await notes.createEmpty(
    folderId: folder,
    title: 'Design trends',
    initialText: 'Minimalism and organic shapes',
    tagNames: const ['work'],
  );
  await files.write('attachments/a1.txt', utf8.encode('hello attachment'));
  await notes.addAttachment(
    note,
    localPath: 'attachments/a1.txt',
    fileName: 'a1.txt',
    mimeType: 'text/plain',
    sizeBytes: 16,
  );
  await files.write('covers/c1.jpg', [1, 2, 3, 4]);
  await notes.setCover(note, 'covers/c1.jpg');

  final tasks = h.read(tasksRepositoryProvider);
  final task = await tasks.save(
    TaskItem(id: '', title: 'Ship backup', createdAt: now, updatedAt: now),
  );
  await tasks.addSubtask(task, 'Write tests');

  final habits = h.read(habitsRepositoryProvider);
  final habit = await habits.save(Habit.draft(startDate: now, name: 'Read'));
  await habits.toggleDone(habit, now);

  final gone = await notes.createEmpty(title: 'Gone for good');
  await h.read(itemsRepositoryProvider).deleteForever([
    ItemRef(ItemType.note, gone),
  ]);

  await db
      .into(db.reminders)
      .insert(
        RemindersCompanion.insert(
          id: 'r1',
          createdAt: now,
          updatedAt: now,
          title: const Value('Call mom'),
          triggerAt: now.add(const Duration(hours: 2)),
          notificationId: 4242,
        ),
      );
  await db
      .into(db.vaultItems)
      .insert(
        VaultItemsCompanion.insert(
          id: 'v1',
          createdAt: now,
          updatedAt: now,
          title: const Value('Bank'),
          encryptedPayload: Uint8List.fromList([9, 8, 7, 6]),
        ),
      );
  await db
      .into(db.vaultHistory)
      .insert(
        VaultHistoryCompanion.insert(
          id: 'vh1',
          itemId: 'v1',
          encryptedPassword: Uint8List.fromList([1, 1]),
          changedAt: now,
        ),
      );
  await db
      .into(db.focusSessions)
      .insert(
        FocusSessionsCompanion.insert(
          id: 'f1',
          taskId: Value(task),
          startedAt: now,
          durationMinutes: 25,
        ),
      );
  return (note: note, task: task, habit: habit, folder: folder);
}

/// A mutable deep copy of [s] edited by [edit].
DbSnapshot mutate(
  DbSnapshot s,
  void Function(Map<String, List<RawRow>> t) edit,
) {
  final t = {
    for (final e in s.tables.entries)
      e.key: [for (final r in e.value) Map<String, Object?>.of(r)],
  };
  edit(t);
  return DbSnapshot(t);
}

/// The row of [table] with [id] (mutable inside [mutate]).
RawRow rowOf(Map<String, List<RawRow>> t, String table, String id) =>
    t[table]!.firstWhere((r) => r['id'] == id);

/// Full-text hits in notes for [query].
Future<List<String>> searchNotes(AppDatabase db, String query) async {
  final rows = await db
      .customSelect(
        'SELECT n.id FROM notes_fts f JOIN notes n ON n.rowid = f.rowid '
        'WHERE notes_fts MATCH ?',
        variables: [Variable.withString(query)],
      )
      .get();
  return [for (final r in rows) r.read<String>('id')];
}
