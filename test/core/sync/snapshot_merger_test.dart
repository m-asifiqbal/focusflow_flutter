/// SnapshotMerger — Merge restore / sync: last-write-wins per item keeping
/// syncVersion, children follow parents, habit logs per (habit, day),
/// folders / tags by updatedAt, vault history union, tombstones (newer
/// re-creations win) and the conflict count.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';
import 'package:focusflow/core/sync/snapshot_merger.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'sync_fixtures.dart';

void main() {
  late TestHarness h;
  late SampleIds ids;
  late SnapshotIo io;
  late SnapshotMerger merger;
  late DbSnapshot base;
  final t0 = secs(syncNow);

  setUp(() async {
    h = await TestHarness.create(now: syncNow);
    ids = await seedSample(h, tempFiles(addTearDown));
    io = SnapshotIo(h.db, deviceId: TestHarness.deviceId);
    merger = SnapshotMerger(
      db: h.db,
      io: io,
      items: h.read(itemsRepositoryProvider),
    );
    base = await io.read();
  });

  tearDown(() => h.dispose());

  Future<String> noteTitle(String id) async => (await (h.db.select(
    h.db.notes,
  )..where((n) => n.id.equals(id))).getSingle()).title;

  test('merging an identical snapshot changes nothing', () async {
    final r = await merger.merge(base);
    expect(r.changes, 0);
    expect(r.conflicts, 0);
    expect((await io.read()).sameContentAs(base), isTrue);
  });

  test('newer updatedAt wins either way, keeping syncVersion', () async {
    final b = await h
        .read(notesRepositoryProvider)
        .createEmpty(title: 'Local B');
    final local = await io.read();
    final incoming = mutate(local, (t) {
      rowOf(t, 'notes', ids.note)
        ..['title'] = 'Remote title'
        ..['plain_text'] = 'remote words'
        ..['updated_at'] = t0 + 60
        ..['sync_version'] = 7
        ..['device_id'] = 'other';
      rowOf(t, 'notes', b)
        ..['title'] = 'Stale B'
        ..['updated_at'] = t0 - 60;
    });
    final r = await merger.merge(incoming);
    expect(r.updated, 1);
    expect(r.keptLocal, 1);
    expect(r.conflicts, 2);
    final note = await (h.db.select(
      h.db.notes,
    )..where((n) => n.id.equals(ids.note))).getSingle();
    expect(note.title, 'Remote title');
    expect(note.syncVersion, 7);
    expect(note.deviceId, 'other');
    expect(await noteTitle(b), 'Local B');
    // FTS follows the merge.
    expect(await searchNotes(h.db, 'remote'), [ids.note]);
    expect(await searchNotes(h.db, 'organic'), isEmpty);
  });

  test('folders and tags merge by updatedAt', () async {
    final tagColor = base.rows('tags').single['color_hex'];
    final incoming = mutate(base, (t) {
      rowOf(t, 'folders', ids.folder)
        ..['name'] = 'Ideas 2'
        ..['updated_at'] = t0 + 60;
      t['tags']!.single
        ..['color_hex'] = 'FF0000'
        ..['updated_at'] = t0 - 60;
    });
    await merger.merge(incoming);
    final folder = await (h.db.select(
      h.db.folders,
    )..where((f) => f.id.equals(ids.folder))).getSingle();
    expect(folder.name, 'Ideas 2');
    expect((await h.db.select(h.db.tags).getSingle()).colorHex, tagColor);
  });

  test('new items arrive with children; same-name tags are one tag', () async {
    final localWork = base.rows('tags').single['id'];
    final incoming = mutate(base, (t) {
      t['tasks']!.add({
        ...rowOf(t, 'tasks', ids.task),
        'id': 't2',
        'title': 'Remote task',
      });
      t['subtasks']!.add({
        ...t['subtasks']!.single,
        'id': 's2',
        'task_id': 't2',
        'title': 'Remote sub',
      });
      for (final (id, name) in [('tag-w', 'work'), ('tag-h', 'home')]) {
        t['tags']!.add({
          'id': id,
          'name': name,
          'color_hex': null,
          'created_at': t0,
          'updated_at': t0,
        });
        t['item_tags']!.add({
          'item_id': 't2',
          'item_type': 'task',
          'tag_id': id,
        });
      }
    });
    final r = await merger.merge(incoming);
    expect(r.added, 1);
    expect(r.conflicts, 0);
    final subs = await (h.db.select(
      h.db.subtasks,
    )..where((s) => s.taskId.equals('t2'))).get();
    expect(subs.map((s) => s.title), ['Remote sub']);
    final tags = await h.db.select(h.db.tags).get();
    expect(tags.map((t) => t.name).toSet(), {'work', 'home'});
    final links = await (h.db.select(
      h.db.itemTags,
    )..where((l) => l.itemId.equals('t2'))).get();
    expect(links.map((l) => l.tagId).toSet(), {localWork, 'tag-h'});
  });

  group('children follow their parent', () {
    DbSnapshot withRemoteSubtask(int updatedAt) => mutate(base, (t) {
      rowOf(t, 'tasks', ids.task)
        ..['title'] = 'Remote'
        ..['updated_at'] = updatedAt;
      t['subtasks'] = [
        {...t['subtasks']!.single, 'id': 's-remote', 'title': 'Remote sub'},
      ];
    });

    Future<List<String>> subtaskIds() async => [
      for (final s in await h.db.select(h.db.subtasks).get()) s.id,
    ];

    test('winning task brings its subtasks', () async {
      await merger.merge(withRemoteSubtask(t0 + 60));
      expect(await subtaskIds(), ['s-remote']);
    });

    test('losing task keeps the local subtasks', () async {
      final before = await subtaskIds();
      await merger.merge(withRemoteSubtask(t0 - 60));
      expect(await subtaskIds(), before);
    });
  });

  test('habit logs merge per (habit, day), keeping the local id', () async {
    final local = base.rows('habit_logs').single;
    final incoming = mutate(base, (t) {
      final log = t['habit_logs']!.single
        ..['id'] = 'log-remote'
        ..['count'] = 3
        ..['updated_at'] = t0 + 60;
      t['habit_logs']!.add({
        ...log,
        'id': 'log-remote-2',
        'date': '2026-01-09',
      });
    });
    await merger.merge(incoming);
    final logs = await h.db.select(h.db.habitLogs).get();
    expect(logs, hasLength(2));
    final today = logs.firstWhere((l) => l.date == local['date']);
    expect(today.id, local['id']);
    expect(today.count, 3);
    expect(logs.map((l) => l.date), contains('2026-01-09'));
  });

  group('tombstones', () {
    test('a newer incoming deletion removes the item and travels on', () async {
      final incoming = mutate(base, (t) {
        t['notes']!.removeWhere((r) => r['id'] == ids.note);
        t['tombstones']!.add({
          'entity': 'note',
          'entity_id': ids.note,
          'deleted_at': t0 + 60,
          'device_id': 'other',
        });
      });
      final r = await merger.merge(incoming);
      expect(r.deleted, 1);
      expect(await h.db.select(h.db.notes).get(), isEmpty);
      expect(await h.db.select(h.db.attachments).get(), isEmpty);
      final tomb = await (h.db.select(
        h.db.tombstones,
      )..where((t) => t.entityId.equals(ids.note))).getSingle();
      expect(tomb.deviceId, 'other');
      expect(secs(tomb.deletedAt), t0 + 60);
    });

    test('a re-creation newer than the deletion wins', () async {
      h.clock.advance(const Duration(minutes: 2));
      await h.read(notesRepositoryProvider).setPinned(ids.note, true);
      final incoming = mutate(base, (t) {
        t['notes']!.removeWhere((r) => r['id'] == ids.note);
        t['tombstones']!.add({
          'entity': 'note',
          'entity_id': ids.note,
          'deleted_at': t0 + 60,
          'device_id': 'other',
        });
      });
      final r = await merger.merge(incoming);
      expect(r.deleted, 0);
      expect(await noteTitle(ids.note), 'Design trends');
      final tombs = await h.db.select(h.db.tombstones).get();
      expect(tombs.map((t) => t.entityId), isNot(contains(ids.note)));
    });

    test('an item deleted here later is not resurrected', () async {
      final incoming = mutate(base, (t) {
        rowOf(t, 'tasks', ids.task)['updated_at'] = t0 + 60;
      });
      await h.read(itemsRepositoryProvider).deleteForever([
        ItemRef(ItemType.task, ids.task),
      ]);
      final r = await merger.merge(incoming);
      expect(r.skipped, 1);
      expect(await h.db.select(h.db.tasks).get(), isEmpty);
      expect(await h.db.select(h.db.subtasks).get(), isEmpty);
    });
  });

  test('vault history is a union; mergeVault false leaves the vault', () async {
    final incoming = mutate(base, (t) {
      t['vault_history']!.add({...t['vault_history']!.single, 'id': 'vh2'});
      rowOf(t, 'vault_items', 'v1')
        ..['title'] = 'Remote bank'
        ..['updated_at'] = t0 + 60;
    });
    var r = await merger.merge(incoming, mergeVault: false);
    expect(r.vaultSkipped, 1);
    expect((await h.db.select(h.db.vaultItems).getSingle()).title, 'Bank');
    expect(await h.db.select(h.db.vaultHistory).get(), hasLength(1));

    r = await merger.merge(incoming);
    expect(r.updated, 1);
    expect(
      (await h.db.select(h.db.vaultItems).getSingle()).title,
      'Remote bank',
    );
    expect(await h.db.select(h.db.vaultHistory).get(), hasLength(2));
  });
}
