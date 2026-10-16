/// SearchRepository — FTS5 prefix matching, per-module counts, ranking,
/// filters, archived / trashed exclusion and title-only privacy rules.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/search/data/repository/search_repository_impl.dart';
import 'package:focusflow/features/search/domain/entities/search_query.dart';
import 'package:focusflow/features/search/domain/repository/search_repository.dart';
import 'package:focusflow/features/search/presentation/providers/search_providers.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../search_seed.dart';

void main() {
  late TestHarness h;
  late SearchRepository repo;
  late SearchSeed seed;

  setUp(() async {
    h = await TestHarness.create(now: searchNow);
    repo = h.read(searchRepositoryProvider);
    seed = await seedSearchMockup(h);
  });

  tearDown(() => h.dispose());

  Future<List<String>> titles(SearchQuery q) async =>
      (await repo.search(q)).hits.map((e) => e.title).toList();

  test('per-module counts match the mockup (All 14)', () async {
    final r = await repo.search(const SearchQuery(text: 'design'));
    expect(r.countOf(ItemType.note), 5);
    expect(r.countOf(ItemType.task), 4);
    expect(r.countOf(ItemType.reminder), 2);
    expect(r.countOf(ItemType.habit), 1);
    expect(r.countOf(ItemType.vault), 2);
    expect(r.total, 14);
    expect(r.hits, hasLength(14));
  });

  test('prefix matching: "des" finds design, "redes" finds redesign', () async {
    expect((await repo.search(const SearchQuery(text: 'des'))).total, 14);
    expect(await titles(const SearchQuery(text: 'redes')), ['Ideas backlog']);
  });

  test('FTS syntax in user input is harmless', () async {
    final r = await repo.search(const SearchQuery(text: '(design"*'));
    expect(r.total, 14);
    expect((await repo.search(const SearchQuery(text: '  ** '))).hits, isEmpty);
  });

  test('relevance: title matches first, newest title match on top', () async {
    final top = await titles(const SearchQuery(text: 'design'));
    expect(top.take(5), [
      'Mobile App Design Trends',
      'Design Home Screen v2',
      'Review design handoff',
      'Figma — design account',
      'Daily design sketch',
    ]);
  });

  test(
    'pinned boost lifts a body-only match above other body matches',
    () async {
      final notes = await titles(
        const SearchQuery(text: 'design', type: ItemType.note),
      );
      final last = notes.last;
      final id = (await repo.search(
        const SearchQuery(text: 'design', type: ItemType.note),
      )).hits.last.ref.id;
      await h.read(itemsRepositoryProvider).setPinned([
        ItemRef(ItemType.note, id),
      ], true);
      final after = await titles(
        const SearchQuery(text: 'design', type: ItemType.note),
      );
      expect(after[1], last);
    },
  );

  test('module chip limits hits but keeps every count', () async {
    final r = await repo.search(
      const SearchQuery(text: 'design', type: ItemType.task),
    );
    expect(r.hits.every((e) => e.type == ItemType.task), isTrue);
    expect(r.hits, hasLength(4));
    expect(r.total, 14);
  });

  test('task meta: floating due day decodes to the local day', () async {
    final r = await repo.search(
      const SearchQuery(text: 'home screen', type: ItemType.task),
    );
    expect(r.hits.single.dueDay, DateTime(2026, 6, 10));
    expect(r.hits.single.dueMinutes, 690);
  });

  test('vault: title only, locked, no snippet', () async {
    final r = await repo.search(
      const SearchQuery(text: 'figma', type: ItemType.vault),
    );
    final hit = r.hits.single;
    expect(hit.ref.id, seed.vault);
    expect(hit.isLocked, isTrue);
    expect(hit.snippet, isEmpty);
    expect(hit.detail, 'Login');
  });

  test('locked notes match on the title only', () async {
    final notes = h.read(notesRepositoryProvider);
    final id = await notes.createEmpty(
      title: 'Diary',
      initialText: 'secret zebra',
    );
    await notes.setLocked(id, true);
    expect((await repo.search(const SearchQuery(text: 'zebra'))).total, 0);
    final r = await repo.search(const SearchQuery(text: 'diary'));
    expect(r.hits.single.isLocked, isTrue);
    expect(r.hits.single.snippet, isEmpty);
  });

  test('archived excluded unless Include archived; trashed never', () async {
    await h.read(itemsRepositoryProvider).archive([
      ItemRef(ItemType.note, seed.note),
    ]);
    var r = await repo.search(const SearchQuery(text: 'design'));
    expect(r.countOf(ItemType.note), 4);
    expect(r.hits.any((e) => e.ref.id == seed.note), isFalse);

    r = await repo.search(
      const SearchQuery(
        text: 'design',
        filters: SearchFilters(includeArchived: true),
      ),
    );
    expect(r.countOf(ItemType.note), 5);
    expect(r.hits.firstWhere((e) => e.ref.id == seed.note).isArchived, isTrue);
    expect(r.hits.any((e) => e.title.contains('trashed')), isFalse);
  });

  test('tag filter', () async {
    await h.read(itemsRepositoryProvider).setTags(
      ItemRef(ItemType.task, seed.task),
      ['work'],
    );
    final tag = (await h.read(tagsRepositoryProvider).watchTags().first)
        .firstWhere((t) => t.name == 'work');
    final r = await repo.search(
      SearchQuery(
        text: 'design',
        filters: SearchFilters(tagId: tag.id),
      ),
    );
    expect(r.total, 1);
    expect(r.hits.single.ref.id, seed.task);
  });

  test('priority filter: tasks only, at least the given priority', () async {
    final tasks = h.read(tasksRepositoryProvider);
    final t = await tasks.getTask(seed.task);
    await tasks.save(t!.copyWith(priority: TaskPriority.high));
    final r = await repo.search(
      SearchQuery(
        text: 'design',
        filters: SearchFilters(minPriority: TaskPriority.medium.index),
      ),
    );
    expect(r.total, 1);
    expect(r.hits.single.ref.id, seed.task);
  });

  test('date range filter on last edit', () async {
    final r = await repo.search(
      SearchQuery(
        text: 'design',
        filters: SearchFilters(
          from: searchNow.subtract(const Duration(days: 2)),
          to: searchNow,
        ),
      ),
    );
    expect(r.hits.map((e) => e.ref.id), [seed.note, seed.task]);
  });

  test('sort by recent orders by last edit', () async {
    final r = await repo.search(
      const SearchQuery(text: 'design', sort: SearchSort.recent),
    );
    for (var i = 1; i < r.hits.length; i++) {
      expect(r.hits[i - 1].updatedAt.isBefore(r.hits[i].updatedAt), isFalse);
    }
  });

  // Live updates arrive after the write burst settles (refreshDelay), so
  // wait for that rather than a fixed sleep shorter than the debounce.
  Future<void> quietPeriod() => Future<void>.delayed(
    SearchRepositoryImpl.refreshDelay + const Duration(milliseconds: 150),
  );

  test('watch is live', () async {
    final stream = repo.watch(const SearchQuery(text: 'kiwi'));
    final values = <int>[];
    final sub = stream.listen((r) => values.add(r.total));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await h.read(notesRepositoryProvider).createEmpty(title: 'Kiwi jam');
    await quietPeriod();
    await sub.cancel();
    expect(values, [0, 1]);
  });

  test('a burst of writes re-runs the query once', () async {
    final values = <int>[];
    final sub = repo
        .watch(const SearchQuery(text: 'kiwi'))
        .listen((r) => values.add(r.total));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final notes = h.read(notesRepositoryProvider);
    for (var i = 0; i < 5; i++) {
      await notes.createEmpty(title: 'Kiwi $i');
    }
    await quietPeriod();
    await sub.cancel();
    expect(values, [0, 5]);
  });

  test('unrelated writes emit nothing new', () async {
    final values = <int>[];
    final sub = repo
        .watch(const SearchQuery(text: 'kiwi'))
        .listen((r) => values.add(r.total));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await h.read(notesRepositoryProvider).createEmpty(title: 'Banana bread');
    await quietPeriod();
    await sub.cancel();
    expect(values, [0]);
  });

  test('a priority filter re-runs on task writes only', () async {
    final values = <int>[];
    final sub = repo
        .watch(
          const SearchQuery(
            text: 'kiwi',
            filters: SearchFilters(minPriority: 0),
          ),
        )
        .listen((r) => values.add(r.total));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await h.read(notesRepositoryProvider).createEmpty(title: 'Kiwi note');
    await quietPeriod();
    expect(values, [0]);
    await h
        .read(tasksRepositoryProvider)
        .save(TaskItem.draft(now: searchNow, title: 'Kiwi task'));
    await quietPeriod();
    await sub.cancel();
    expect(values, [0, 1]);
  });

  test('titleMatchesAll matches word starts only', () {
    expect(
      SearchRepositoryImpl.titleMatchesAll('Mobile App Design', ['des']),
      isTrue,
    );
    expect(
      SearchRepositoryImpl.titleMatchesAll('Redesign', ['design']),
      isFalse,
    );
  });
}
