/// ItemsRepository / TagsRepository — reminders whose linked task or note is
/// archived / trashed are hidden everywhere (rule 3): they must not count in
/// the Library hub, nor show up in Pinned, Favourites, by-tag lists or tag
/// usage counts. Restoring the owner brings the reminder back.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/items/tags_repository.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late ItemsRepository items;
  late NotesRepository notes;
  late RemindersRepository reminders;
  late TagsRepository tags;

  final now = DateTime(2026, 6, 13, 9);

  setUp(() async {
    h = await TestHarness.create(now: now);
    items = h.read(itemsRepositoryProvider);
    notes = h.read(notesRepositoryProvider);
    reminders = h.read(remindersRepositoryProvider);
    tags = h.read(tagsRepositoryProvider);
  });

  tearDown(() => h.dispose());

  /// A note with a linked reminder that is pinned, favourite and tagged
  /// `#work` — plus a free-standing control reminder with the same flags.
  Future<(ItemRef note, ItemRef linked, ItemRef free)> seed() async {
    final noteId = await notes.createEmpty(title: 'Roadmap');
    final note = ItemRef(ItemType.note, noteId);
    final linkedId = await reminders.upsertLinkedReminder(
      note,
      title: 'Review roadmap',
      at: now.add(const Duration(hours: 3)),
    );
    final linked = ItemRef(ItemType.reminder, linkedId);
    final free = ItemRef(
      ItemType.reminder,
      await reminders.upsertLinkedReminder(
        ItemRef(ItemType.note, await notes.createEmpty(title: 'Other')),
        title: 'Free',
        at: now.add(const Duration(hours: 4)),
      ),
    );
    for (final r in [linked, free]) {
      await items.setPinned([r], true);
      await items.setFavorite([r], true);
      await items.setTags(r, ['work']);
    }
    return (note, linked, free);
  }

  Future<int> workUsage() async {
    final all = await tags.watchTags().first;
    return all.firstWhere((t) => t.name == 'work').usageCount;
  }

  Future<String> workTagId() async =>
      (await tags.watchTags().first).firstWhere((t) => t.name == 'work').id;

  test('visible linked reminders count everywhere', () async {
    final (_, linked, _) = await seed();
    final counts = await items.watchLibraryCounts(now: now).first;
    expect(counts.remindersTotal, 2);
    expect(counts.pinned, 2);
    expect(counts.favourites, 2);
    final pinned = await items.watchPinned().first;
    expect(pinned.map((s) => s.ref), contains(linked));
    expect(await workUsage(), 2);
  });

  for (final action in ['archive', 'trash']) {
    test(
      'a reminder of an ${action == 'archive' ? 'archived' : 'trashed'} note is hidden from counts, '
      'collections and tag usage',
      () async {
        final (note, linked, free) = await seed();
        if (action == 'archive') {
          await items.archive([note]);
        } else {
          await items.moveToTrash([note]);
        }

        final counts = await items.watchLibraryCounts(now: now).first;
        expect(counts.remindersTotal, 1);
        expect(counts.pinned, 1);
        expect(counts.favourites, 1);

        final pinned = (await items.watchPinned().first).map((s) => s.ref);
        final favs = (await items.watchFavourites().first).map((s) => s.ref);
        final byTag = (await items.watchByTag(await workTagId()).first).map(
          (s) => s.ref,
        );
        for (final list in [pinned, favs, byTag]) {
          expect(list, isNot(contains(linked)));
          expect(list, contains(free));
        }
        expect(await workUsage(), 1);

        // The reminder itself is neither archived nor trashed.
        final summary = await items.get(linked);
        expect(summary!.isActive, isTrue);
      },
    );
  }

  test('restoring the owner brings the reminder back (live)', () async {
    final (note, linked, _) = await seed();
    await items.archive([note]);
    final emitted = <int>[];
    final sub = items
        .watchLibraryCounts(now: now)
        .listen((c) => emitted.add(c.remindersTotal));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await items.unarchive([note]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emitted.first, 1);
    expect(emitted.last, 2);
    final pinned = (await items.watchPinned().first).map((s) => s.ref);
    expect(pinned, contains(linked));
  });
}
