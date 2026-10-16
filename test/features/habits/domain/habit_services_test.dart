// Unit tests for the small pure habit services: HabitDay (reset time),
// HabitsDaySummary (header + hero), HabitCheckIn (button / "Log today"),
// HabitCsv (export) and HabitHistory (detail history list).
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_check_in.dart';
import 'package:focusflow/features/habits/domain/services/habit_csv.dart';
import 'package:focusflow/features/habits/domain/services/habit_day.dart';
import 'package:focusflow/features/habits/domain/services/habit_day_status_builder.dart';
import 'package:focusflow/features/habits/domain/services/habit_history.dart';
import 'package:focusflow/features/habits/domain/services/habits_day_summary.dart';

final today = DateTime(2026, 6, 13);

Habit habit({
  String id = 'h1',
  String name = 'Drink water',
  HabitKind kind = HabitKind.build,
  int target = 1,
  String unit = 'times',
}) => Habit(
  id: id,
  name: name,
  kind: kind,
  targetCount: target,
  unit: unit,
  startDate: DateTime(2026, 1, 1),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

HabitLog log(
  DateTime date, {
  String habitId = 'h1',
  int count = 1,
  bool skipped = false,
  String? note,
}) => HabitLog(
  id: 'l$date',
  habitId: habitId,
  date: date,
  count: count,
  skipped: skipped,
  note: note,
  createdAt: date,
  updatedAt: date,
);

void main() {
  group('HabitDay', () {
    test('nextStart: the next midnight / reset time after now', () {
      expect(
        HabitDay.nextStart(DateTime(2026, 6, 12, 23, 59)),
        DateTime(2026, 6, 13),
      );
      // 01:00 with a 02:00 reset is still the 12th's habit day.
      expect(
        HabitDay.nextStart(DateTime(2026, 6, 13, 1), resetMinutes: 120),
        DateTime(2026, 6, 13, 2),
      );
      expect(
        HabitDay.nextStart(DateTime(2026, 6, 13, 2), resetMinutes: 120),
        DateTime(2026, 6, 14, 2),
      );
    });

    test('midnight reset: the calendar day', () {
      expect(HabitDay.of(DateTime(2026, 6, 13, 0, 5)), today);
    });

    test('before the reset time it is still yesterday', () {
      expect(
        HabitDay.of(DateTime(2026, 6, 13, 1, 59), resetMinutes: 120),
        DateTime(2026, 6, 12),
      );
      expect(HabitDay.of(DateTime(2026, 6, 13, 2), resetMinutes: 120), today);
    });

    test('out-of-range reset minutes are clamped', () {
      expect(HabitDay.of(DateTime(2026, 6, 13, 9), resetMinutes: -30), today);
      expect(
        HabitDay.of(DateTime(2026, 6, 13, 23, 58), resetMinutes: 99999),
        DateTime(2026, 6, 12),
      );
    });
  });

  group('HabitsDaySummary', () {
    test('counts only due, not skipped habits; quit clean = done', () {
      final water = habit(id: 'a', target: 8);
      final read = habit(id: 'b');
      final sugar = habit(id: 'c', kind: HabitKind.quit);
      final rest = habit(id: 'd');
      final statuses = [
        HabitDayStatusBuilder.build(water, [
          log(today, habitId: 'a', count: 6),
        ], today),
        HabitDayStatusBuilder.build(read, [
          for (var d = 1; d <= 13; d++) log(DateTime(2026, 6, d), habitId: 'b'),
        ], today),
        HabitDayStatusBuilder.build(sugar, const [], today),
        HabitDayStatusBuilder.build(rest, [
          log(today, habitId: 'd', count: 0, skipped: true),
        ], today),
      ];
      final s = HabitsDaySummary.of(statuses);
      expect(s.total, 4);
      expect(s.due, 3);
      expect(s.done, 2);
      expect(s.progress, closeTo(2 / 3, 1e-9));
      expect(s.isPerfect, isFalse);
      // The quit habit has been clean since 1 Jan, the longest streak.
      expect(s.longest!.habit.id, 'c');
    });

    test('empty list: zero progress, not perfect, no streak', () {
      final s = HabitsDaySummary.of(const []);
      expect(s, HabitsDaySummary.empty);
      expect(s.progress, 0);
      expect(s.isPerfect, isFalse);
      expect(s.longest, isNull);
    });

    test('every due habit done is a perfect day', () {
      final h = habit();
      final s = HabitsDaySummary.of([
        HabitDayStatusBuilder.build(h, [log(today)], today),
      ]);
      expect(s.isPerfect, isTrue);
      expect(s.progress, 1);
    });
  });

  group('HabitCheckIn', () {
    test('tap: counted habit increments until done, then decrements', () {
      final h = habit(target: 8);
      final partial = HabitDayStatusBuilder.build(h, [
        log(today, count: 6),
      ], today);
      final done = HabitDayStatusBuilder.build(h, [
        log(today, count: 8),
      ], today);
      expect(HabitCheckIn.tap(partial), HabitLogChange.increment);
      expect(HabitCheckIn.tap(done), HabitLogChange.decrement);
    });

    test('tap: yes/no and quit habits toggle', () {
      final yesNo = HabitDayStatusBuilder.build(habit(), const [], today);
      final quit = HabitDayStatusBuilder.build(
        habit(kind: HabitKind.quit),
        const [],
        today,
      );
      expect(HabitCheckIn.tap(yesNo), HabitLogChange.toggle);
      expect(HabitCheckIn.tap(quit), HabitLogChange.toggle);
    });

    test('logToday never removes progress', () {
      final yesNo = habit();
      expect(HabitCheckIn.logToday(yesNo, null), HabitLogChange.toggle);
      expect(HabitCheckIn.logToday(yesNo, log(today)), isNull);

      final counted = habit(target: 8);
      expect(
        HabitCheckIn.logToday(counted, log(today, count: 8)),
        HabitLogChange.increment,
      );

      final quit = habit(kind: HabitKind.quit);
      expect(HabitCheckIn.logToday(quit, null), isNull);
      expect(HabitCheckIn.logToday(quit, log(today)), HabitLogChange.toggle);
    });

    test('logsSlip only for quit habits going from clean to slip', () {
      final quit = habit(kind: HabitKind.quit);
      expect(HabitCheckIn.logsSlip(quit, null, HabitLogChange.toggle), isTrue);
      expect(
        HabitCheckIn.logsSlip(quit, log(today), HabitLogChange.toggle),
        isFalse,
      );
      expect(
        HabitCheckIn.logsSlip(quit, log(today), HabitLogChange.increment),
        isTrue,
      );
      expect(
        HabitCheckIn.logsSlip(habit(), null, HabitLogChange.toggle),
        isFalse,
      );
    });
  });

  group('HabitCsv', () {
    test('sorted rows with escaped fields', () {
      final h = habit(target: 8, unit: 'glasses, big');
      final csv = HabitCsv.export(h, [
        log(DateTime(2026, 6, 2), count: 3, note: 'said "hi"'),
        log(DateTime(2026, 6, 1), count: 8),
      ]);
      expect(
        csv,
        '${HabitCsv.header}\n'
        '2026-06-01,8,8,"glasses, big",yes,no,\n'
        '2026-06-02,3,8,"glasses, big",no,no,"said ""hi"""\n',
      );
    });

    test('formula-like fields are neutralised', () {
      expect(HabitCsv.escape('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
      expect(HabitCsv.escape('+1'), "'+1");
      expect(HabitCsv.escape('-2 glasses'), "'-2 glasses");
      expect(HabitCsv.escape('@cmd'), "'@cmd");
      expect(HabitCsv.escape('fine = ok'), 'fine = ok');
    });

    test('file name slug', () {
      expect(
        HabitCsv.fileName(habit(name: 'Drink Water!')),
        'drink-water-history.csv',
      );
      expect(HabitCsv.fileName(habit(name: '💧')), 'habit-history.csv');
    });
  });

  group('HabitHistory', () {
    test('newest first, kinds, empty logs dropped, future excluded', () {
      final h = habit(target: 8);
      final entries = HabitHistory.entries(h, [
        log(DateTime(2026, 6, 10), count: 8),
        log(DateTime(2026, 6, 11), count: 3),
        log(DateTime(2026, 6, 12), count: 0, skipped: true),
        log(DateTime(2026, 6, 9), count: 0),
        log(DateTime(2026, 6, 14), count: 8),
      ], today);
      expect(entries.map((e) => e.day.day), [12, 11, 10]);
      expect(entries.map((e) => e.kind), [
        HabitHistoryKind.skipped,
        HabitHistoryKind.partial,
        HabitHistoryKind.done,
      ]);
      expect(entries[1].progress, closeTo(3 / 8, 1e-9));
    });

    test('quit habits list slips and noted clean days; limit applies', () {
      final h = habit(kind: HabitKind.quit);
      final entries = HabitHistory.entries(
        h,
        [
          log(DateTime(2026, 6, 10)),
          log(DateTime(2026, 6, 11), count: 0, note: 'Tough day'),
          log(DateTime(2026, 6, 12), count: 0),
        ],
        today,
        limit: 1,
      );
      expect(entries, hasLength(1));
      expect(entries.single.kind, HabitHistoryKind.done);
      expect(entries.single.note, 'Tough day');
    });
  });
}
