/// watchComputed(shareKey): subscribers with the same key share one
/// computation (the latest value is replayed to a late one, a write re-runs
/// it once for everybody, the last one leaving stops it), different keys and
/// unkeyed calls stay independent, errors reach every listener.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late AppDatabase db;
  var calls = 0;

  setUp(() async {
    h = await TestHarness.create(now: DateTime(2026, 6, 13, 9));
    db = h.db;
    calls = 0;
  });

  tearDown(() => h.dispose());

  Future<void> addNote(String id) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: id,
          createdAt: DateTime(2026, 6, 13),
          updatedAt: DateTime(2026, 6, 13),
          title: Value(id),
        ),
      );

  Stream<int> notes({Object? key}) => db.watchComputed({db.notes}, () async {
    calls++;
    return (await db.select(db.notes).get()).length;
  }, shareKey: key);

  Future<void> pause() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  test('subscribers with the same key share one computation', () async {
    final a = <int>[];
    final b = <int>[];
    final sa = notes(key: 'n').listen(a.add);
    final sb = notes(key: 'n').listen(b.add);
    await pause();

    expect(calls, 1);
    expect(a, [0]);
    expect(b, [0]);
    await sa.cancel();
    await sb.cancel();
  });

  test('a late subscriber gets the latest value without a new query', () async {
    final a = <int>[];
    final sa = notes(key: 'n').listen(a.add);
    await pause();
    await addNote('one');
    await pause();
    expect(a, [0, 1]);
    final callsBefore = calls;

    final late = <int>[];
    final sb = notes(key: 'n').listen(late.add);
    await pause();

    expect(late, [1]);
    expect(calls, callsBefore);
    await sa.cancel();
    await sb.cancel();
  });

  test('a write re-runs the query once for every subscriber', () async {
    final a = <int>[];
    final b = <int>[];
    final sa = notes(key: 'n').listen(a.add);
    final sb = notes(key: 'n').listen(b.add);
    await pause();
    final before = calls;

    await addNote('one');
    await pause();

    expect(calls - before, 1);
    expect(a.last, 1);
    expect(b.last, 1);
    await sa.cancel();
    await sb.cancel();
  });

  test('one subscriber leaving keeps the query for the others', () async {
    final a = <int>[];
    final b = <int>[];
    final sa = notes(key: 'n').listen(a.add);
    final sb = notes(key: 'n').listen(b.add);
    await pause();
    await sa.cancel();

    await addNote('one');
    await pause();

    expect(b.last, 1);
    await sb.cancel();
  });

  test(
    'the last subscriber leaving stops it; the next one starts fresh',
    () async {
      final sa = notes(key: 'n').listen((_) {});
      await pause();
      await sa.cancel();
      final stopped = calls;
      await addNote('one');
      await pause();
      expect(calls, stopped, reason: 'nobody listens, nothing recomputes');

      final fresh = <int>[];
      final sb = notes(key: 'n').listen(fresh.add);
      await pause();

      expect(fresh, [1]);
      expect(calls, stopped + 1);
      await sb.cancel();
    },
  );

  test('different keys, and calls without a key, are independent', () async {
    final subs = [
      notes(key: 'a').listen((_) {}),
      notes(key: 'b').listen((_) {}),
      notes().listen((_) {}),
      notes().listen((_) {}),
    ];
    await pause();

    expect(calls, 4);
    for (final s in subs) {
      await s.cancel();
    }
  });

  test('errors reach every listener and the query keeps working', () async {
    var fail = true;
    Stream<int> flaky() => db.watchComputed({db.notes}, () async {
      if (fail) throw StateError('boom');
      return (await db.select(db.notes).get()).length;
    }, shareKey: 'flaky');
    final errorsA = <Object>[];
    final errorsB = <Object>[];
    final valuesA = <int>[];
    final sa = flaky().listen(valuesA.add, onError: errorsA.add);
    final sb = flaky().listen((_) {}, onError: errorsB.add);
    await pause();
    expect(errorsA.single, isA<StateError>());
    expect(errorsB.single, isA<StateError>());

    fail = false;
    await addNote('one');
    await pause();

    expect(valuesA, [1]);
    await sa.cancel();
    await sb.cancel();
  });

  test('today\'s habits: Home, the counts and the planner share one', () async {
    final habits = h.read(habitsRepositoryProvider);
    final today = DateTime(2026, 6, 13);
    final id = await habits.save(
      Habit.draft(startDate: DateTime(2026, 6, 1), name: 'Read'),
    );
    final first = <int>[];
    final second = <int>[];
    final sa = habits
        .watchTodayHabits(today)
        .listen((l) => first.add(l.single.count));
    final sb = habits
        .watchTodayHabits(today)
        .listen((l) => second.add(l.single.count));
    await pause();
    await habits.increment(id, today);
    await pause();

    expect(first.last, 1);
    expect(second.last, 1);
    expect(first, second);

    // A different week start is a different query.
    final other = await habits.watchTodayHabits(today, weekStartsOn: 7).first;
    expect(other.single.count, 1);
    await sa.cancel();
    await sb.cancel();
  });
  test(
    'todayHabitsNow ignores a live stream and includes the last write',
    () async {
      final habits = h.read(habitsRepositoryProvider);
      final today = DateTime(2026, 6, 13);
      final id = await habits.save(
        Habit.draft(startDate: DateTime(2026, 6, 1), name: 'Read'),
      );
      final seen = <int>[];
      final sub = habits
          .watchTodayHabits(today)
          .listen((l) => seen.add(l.single.count));
      await pause();
      expect(seen, [0]);

      await habits.increment(id, today);
      // No pause: the shared stream may not have caught up yet, the one-shot
      // read has to be right regardless.
      final fresh = await habits.todayHabitsNow(today);

      expect(fresh.single.count, 1);
      await sub.cancel();
    },
  );
}
