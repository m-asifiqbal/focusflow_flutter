/// HabitEditorController guards around existing history (screen 15):
/// build ⇄ quit is refused while the habit has logs (reset first), a new
/// goal / schedule / start date is flagged for confirmation, saving never
/// reverts pause / pin / favourite changed meanwhile, and Reset history's
/// Undo restores every log in one transaction — even after the editor
/// (an auto-disposed controller) is gone.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_editor_actions.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late HabitsRepository repo;
  final now = DateTime(2026, 6, 12, 9);

  setUp(() async {
    h = await TestHarness.create(now: now);
    repo = h.read(habitsRepositoryProvider);
  });

  tearDown(() => h.dispose());

  Future<HabitEditorController> open(HabitEditorArgs args) async {
    final p = habitEditorControllerProvider(args);
    h.container.listen(p, (_, _) {});
    await h.container.read(p.future);
    return h.container.read(p.notifier);
  }

  HabitEditorState state(HabitEditorArgs args) =>
      h.container.read(habitEditorControllerProvider(args)).valueOrNull!;

  Future<String> water({int logs = 3}) async {
    final id = await repo.save(
      Habit.draft(startDate: DateTime(2026, 6, 1), name: 'Water'),
    );
    for (var d = 1; d <= logs; d++) {
      await repo.setLog(id, DateTime(2026, 6, d), count: 1, note: 'n$d');
    }
    return id;
  }

  Future<int> logCount(String id) async =>
      (await repo.watchHabitWithLogs(id).first)!.logs.length;

  group('build ⇄ quit', () {
    test('refused while the habit has logs; save refuses too', () async {
      final id = await water();
      final args = (id: id, name: null);
      final c = await open(args);
      expect(state(args).hasHistory, isTrue);
      expect(c.setKind(HabitKind.quit), isFalse);
      expect(state(args).draft.kind, HabitKind.build);
      // Back to the stored type is always fine.
      expect(c.setKind(HabitKind.build), isTrue);
    });

    test('allowed for a habit without logs and for a new habit', () async {
      final id = await water(logs: 0);
      final args = (id: id, name: null);
      final c = await open(args);
      expect(state(args).hasHistory, isFalse);
      expect(c.setKind(HabitKind.quit), isTrue);
      expect(await c.save(), id);
      expect((await repo.getHabit(id))!.kind, HabitKind.quit);

      const fresh = (id: null, name: 'No sugar');
      final n = await open(fresh);
      expect(n.setKind(HabitKind.quit), isTrue);
    });

    test(
      'a log added while editing blocks the save of a type change',
      () async {
        final id = await water(logs: 0);
        final args = (id: id, name: null);
        final c = await open(args);
        expect(c.setKind(HabitKind.quit), isTrue);
        await repo.setLog(id, DateTime(2026, 6, 2), count: 1);
        expect(await c.save(), isNull);
        expect(state(args).kindChangeBlocked, isTrue);
        expect((await repo.getHabit(id))!.kind, HabitKind.build);
      },
    );

    test('reset history & change type, then save', () async {
      final id = await water();
      final args = (id: id, name: null);
      final c = await open(args);
      final removed = await c.resetHistoryAndSetKind(HabitKind.quit);
      expect(removed, hasLength(3));
      expect(await logCount(id), 0);
      expect(state(args).draft.kind, HabitKind.quit);
      expect(state(args).hasHistory, isFalse);
      expect(await c.save(), id);
      expect((await repo.getHabit(id))!.kind, HabitKind.quit);
    });

    test('dialog copy explains the reinterpretation', () {
      expect(
        habitKindChangeMessage('Water', HabitKind.quit),
        contains('check-ins of "Water" would turn into slips'),
      );
      expect(
        habitKindChangeMessage('Sugar', HabitKind.build),
        contains('slips of "Sugar" would turn into check-ins'),
      );
    });
  });

  group('goal / schedule changes', () {
    test('flagged only for a habit with history', () async {
      final id = await water();
      final args = (id: id, name: null);
      final c = await open(args);
      expect(state(args).needsScheduleConfirm, isFalse);
      c
        ..setTarget(4)
        ..setFrequencyKind(HabitFrequencyKind.timesPerWeek)
        ..setStartDate(DateTime(2026, 5, 1));
      expect(state(args).scheduleChanges, [
        'daily target',
        'schedule',
        'start date',
      ]);
      expect(state(args).needsScheduleConfirm, isTrue);
      expect(
        habitScheduleChangeMessage('Water', state(args).scheduleChanges),
        contains('the new daily target, schedule and start date'),
      );
      // Renaming alone is not a schedule change.
      final other = await water(logs: 0);
      final args2 = (id: other, name: null);
      final c2 = await open(args2);
      c2.setTarget(5);
      expect(state(args2).scheduleChanges, ['daily target']);
      expect(state(args2).needsScheduleConfirm, isFalse);
    });
  });

  test('save does not revert pause / pin / favourite set meanwhile', () async {
    final id = await water(logs: 0);
    final args = (id: id, name: null);
    final c = await open(args);
    // Changed elsewhere while the editor is open.
    await repo.setPaused(id, true);
    final ref = ItemRef(ItemType.habit, id);
    await h.read(itemsRepositoryProvider).setPinned([ref], true);
    await h.read(itemsRepositoryProvider).setFavorite([ref], true);

    c
      ..setName('Water 2L')
      ..setFrequencyKind(HabitFrequencyKind.specificDays);
    expect(await c.save(), id);
    final saved = (await repo.getHabit(id))!;
    expect(saved.name, 'Water 2L');
    expect(saved.frequency, HabitFrequency.weekdays);
    expect(saved.isPaused, isTrue);
    expect(saved.isPinned, isTrue);
    expect(saved.isFavorite, isTrue);
  });

  group('Reset history undo', () {
    test('restoreLogs writes every log back in one transaction', () async {
      final id = await water(logs: 5);
      final before = (await repo.watchHabitWithLogs(id).first)!.logs;
      await repo.resetHistory(id);

      final emissions = <int>[];
      final sub = repo
          .watchHabitWithLogs(id)
          .listen((d) => emissions.add(d!.logs.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.restoreLogs(before);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      final after = (await repo.watchHabitWithLogs(id).first)!.logs;
      expect(after.map((l) => l.note), ['n1', 'n2', 'n3', 'n4', 'n5']);
      expect(after.map((l) => l.id), before.map((l) => l.id));
      // No intermediate states (1, 2, 3 … logs) were ever visible.
      expect(emissions.where((n) => n > 0 && n < 5), isEmpty);
      expect(emissions.last, 5);
    });

    test('works after the editor controller is disposed', () async {
      final id = await water(logs: 4);
      final args = (id: id, name: null);
      final p = habitEditorControllerProvider(args);
      final sub = h.container.listen(p, (_, _) {});
      await h.container.read(p.future);
      final removed = await h.container.read(p.notifier).resetHistory();
      // What the Undo snackbar captures: the repository + the logs.
      final captured = h.read(habitsRepositoryProvider);
      sub.close(); // the editor closes → the auto-dispose controller dies
      await Future<void>.delayed(Duration.zero);
      expect(h.container.exists(p), isFalse);

      await captured.restoreLogs(removed);
      expect(await logCount(id), 4);
    });

    test('a day logged again before Undo takes the restored values', () async {
      final id = await water(logs: 2);
      final removed = (await repo.watchHabitWithLogs(id).first)!.logs;
      await repo.resetHistory(id);
      await repo.setLog(id, DateTime(2026, 6, 1), count: 7);
      await repo.restoreLogs(removed);
      final logs = (await repo.watchHabitWithLogs(id).first)!.logs;
      expect(logs, hasLength(2));
      expect(logs.first.count, 1);
      expect(logs.first.note, 'n1');
    });
  });
}
