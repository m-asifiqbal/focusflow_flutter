/// NotesQuery.light — the calendar's view of notes: same rows, same order,
/// titles and dates intact, but no body (the full Delta of every note must
/// not be pulled into memory just to put a dot on a day).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;

  setUp(() async => h = await TestHarness.create(now: DateTime(2026, 10, 15)));
  tearDown(() => h.dispose());

  final body = 'First line of the body\n${'long text ' * 400}';
  final delta = '[{"insert":${_json(body)}}]';

  Future<String> note({String title = '', DateTime? at}) async {
    if (at != null) h.clock.set(at);
    final repo = h.read(notesRepositoryProvider);
    final id = await repo.createEmpty(title: title);
    await repo.saveContent(
      id,
      title: title,
      deltaJson: delta,
      plainText: body,
      wordCount: 801,
    );
    return id;
  }

  test('light rows keep the identity and drop the body', () async {
    final repo = h.read(notesRepositoryProvider);
    final id = await note(title: 'Plan', at: DateTime(2026, 10, 14, 9));

    final full = (await repo.watchNotes(const NotesQuery()).first).single;
    final light =
        (await repo.watchNotes(const NotesQuery(light: true)).first).single;

    expect(full.contentDelta, delta);
    expect(full.plainText, body);

    expect(light.id, id);
    expect(light.title, 'Plan');
    expect(light.createdAt, full.createdAt);
    expect(light.wordCount, 801);
    expect(light.contentDelta, '[]', reason: 'the Delta is not loaded');
    expect(light.plainText.length, lessThanOrEqualTo(160));
    expect(light.plainText, startsWith('First line of the body'));
  });

  test('an untitled note still gets its title from the first line', () async {
    final repo = h.read(notesRepositoryProvider);
    await note();
    final light =
        (await repo.watchNotes(const NotesQuery(light: true)).first).single;
    expect(light.displayTitle, 'First line of the body');
  });

  test('light and full lists agree on order and membership', () async {
    final repo = h.read(notesRepositoryProvider);
    await note(title: 'B', at: DateTime(2026, 10, 10));
    await note(title: 'A', at: DateTime(2026, 10, 12));
    await note(title: 'C', at: DateTime(2026, 10, 11));
    const sort = NotesSort.created;
    final full = await repo.watchNotes(const NotesQuery(sort: sort)).first;
    final light = await repo
        .watchNotes(const NotesQuery(sort: sort, light: true))
        .first;
    expect(light.map((n) => n.id), full.map((n) => n.id));
    expect(light.map((n) => n.title), ['A', 'C', 'B']);
  });

  test('light is part of the query identity', () {
    expect(const NotesQuery(light: true), isNot(const NotesQuery()));
    expect(
      const NotesQuery(light: true).hashCode,
      isNot(const NotesQuery().hashCode),
    );
    expect(const NotesQuery().copyWith(light: true).light, isTrue);
  });
}

String _json(String s) =>
    '"${s.replaceAll(r'\', r'\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
