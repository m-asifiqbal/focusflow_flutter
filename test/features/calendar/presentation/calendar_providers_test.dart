/// Calendar providers over a real (keyed) database: the view controller
/// (initial day, select, month shift with clamping, week shift), the live
/// day agenda / month dots, and drag-reschedule with Undo.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/domain/services/calendar_rules.dart';
import 'package:focusflow/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../calendar_seed.dart';

void main() {
  late TestHarness h;
  late CalendarSeed seed;

  setUp(() async {
    h = await TestHarness.create(now: calendarNow);
    seed = await seedCalendarMockup(h);
  });
  tearDown(() => h.dispose());

  /// Waits until an `AsyncValue` provider has data.
  Future<T> valueOf<T>(ProviderListenable<AsyncValue<T>> p) async {
    final sub = h.container.listen(p, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 100; i++) {
      final v = sub.read();
      if (v.hasValue) return v.requireValue;
      if (v.hasError) throw v.error!;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw StateError('no value');
  }

  group('view controller', () {
    test('opens on the route day, or today', () {
      final p = calendarViewProvider(DateTime(2023, 2, 7, 15));
      final sub = h.container.listen(p, (_, _) {});
      addTearDown(sub.close);
      expect(sub.read().selectedDay, DateTime(2023, 2, 7));
      expect(sub.read().month, DateTime(2023, 2));
      expect(sub.read().mode, CalendarMode.month);

      final today = h.container.listen(calendarViewProvider(null), (_, _) {});
      addTearDown(today.close);
      expect(today.read().selectedDay, calendarToday);
    });

    test('select, shiftMonth (clamped / today), shiftWeek, setMode', () {
      final p = calendarViewProvider(DateTime(2023, 1, 31));
      final sub = h.container.listen(p, (_, _) {});
      addTearDown(sub.close);
      final c = h.read(p.notifier);

      c.shiftMonth(1);
      expect(sub.read().selectedDay, DateTime(2023, 2, 28));
      c.shiftMonth(4); // June 2023 contains today → today.
      expect(sub.read().selectedDay, calendarToday);
      c.select(DateTime(2023, 7, 1));
      expect(sub.read().month, DateTime(2023, 7));
      c.shiftWeek(-1);
      expect(sub.read().selectedDay, DateTime(2023, 6, 24));
      expect(sub.read().month, DateTime(2023, 6));
      c.setMode(CalendarMode.week);
      expect(sub.read().mode, CalendarMode.week);
      c.goToToday();
      expect(sub.read().selectedDay, calendarToday);
    });
  });

  test('day agenda lists the mockup rows in order', () async {
    final entries = await valueOf(calendarAgendaProvider(calendarToday));
    expect(entries.map((e) => e.title), [
      'Review FocusFlow Q3 Strategy',
      'Call the bank about card',
      'Design Home Screen v2',
      'Read 20 pages',
    ]);
    expect(entries.first.meta, 'Task · High');
    expect(entries.last.meta, 'Habit · done');
    expect(entries.last.isAllDay, isTrue);
  });

  test('month dots over the grid range', () async {
    final grid = CalendarRules.monthGrid(DateTime(2023, 6), DateTime.sunday);
    final dots = await valueOf(calendarDotsProvider(calendarRangeOf(grid)));
    expect(dots['2023-06-13'], [
      ItemType.task,
      ItemType.reminder,
      ItemType.habit,
    ]);
    expect(dots['2023-06-14'], [ItemType.reminder]);
    expect(dots['2023-06-08'], [ItemType.note]);
    expect(dots.containsKey('2023-06-01'), isFalse);
  });

  test('rescheduler moves a task and restores it', () async {
    final entries = await valueOf(calendarAgendaProvider(calendarToday));
    final review = entries.first;
    final r = h.read(calendarReschedulerProvider);
    final target = DateTime(2023, 6, 15);

    final previous = await r.move(review, target);
    expect(previous, calendarToday);
    var t = await h.read(tasksRepositoryProvider).getTask(seed.reviewTaskId);
    expect(t!.dueDate, target);
    expect(t.dueTimeMinutes, 9 * 60, reason: 'time of day is kept');

    // Same day / non-task rows are no-ops.
    expect(await r.move(review, target), isNull);
    final reminder = entries[1];
    expect(reminder.type, ItemType.reminder);
    expect(await r.move(reminder, target), isNull);

    await r.restore(review, previous!);
    t = await h.read(tasksRepositoryProvider).getTask(seed.reviewTaskId);
    expect(t!.dueDate, calendarToday);
  });
}
