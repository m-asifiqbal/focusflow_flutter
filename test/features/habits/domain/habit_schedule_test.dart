// Unit tests for HabitSchedule: due-day rules per frequency kind, start date
// and pause handling, range listing and the shared day helpers.
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';

/// Saturday, 13 June 2026 — the fixed "today" of these tests.
final today = DateTime(2026, 6, 13);

/// A day relative to [today] (DST-safe).
DateTime day(int offset) => DateTime(2026, 6, 13 + offset);

Habit habit({
  HabitKind kind = HabitKind.build,
  int target = 1,
  HabitFrequency frequency = const HabitFrequency.everyDay(),
  DateTime? start,
  bool paused = false,
}) => Habit(
  id: 'h1',
  name: 'Test habit',
  kind: kind,
  targetCount: target,
  frequency: frequency,
  startDate: start ?? DateTime(2026, 6, 1),
  isPaused: paused,
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

HabitLog log(DateTime date, {int count = 1, bool skipped = false}) => HabitLog(
  id: 'l$date',
  habitId: 'h1',
  date: date,
  count: count,
  skipped: skipped,
  createdAt: date,
  updatedAt: date,
);

void main() {
  test('fixture sanity: 13 June 2026 is a Saturday', () {
    expect(today.weekday, DateTime.saturday);
    expect(DateTime(2026, 6, 1).weekday, DateTime.monday);
  });

  group('isScheduledOn', () {
    test('every day: due from the start date on, never before', () {
      final h = habit(start: DateTime(2026, 6, 5));
      expect(HabitSchedule.isScheduledOn(h, DateTime(2026, 6, 4)), isFalse);
      expect(HabitSchedule.isScheduledOn(h, DateTime(2026, 6, 5)), isTrue);
      expect(HabitSchedule.isScheduledOn(h, today), isTrue);
      expect(HabitSchedule.isScheduledOn(h, day(30)), isTrue);
    });

    test('time of day is ignored', () {
      final h = habit(start: DateTime(2026, 6, 13));
      expect(
        HabitSchedule.isScheduledOn(h, DateTime(2026, 6, 13, 23, 59)),
        isTrue,
      );
      expect(
        HabitSchedule.isScheduledOn(h, DateTime(2026, 6, 12, 23, 59)),
        isFalse,
      );
    });

    test('paused habit is not due unless the pause is ignored', () {
      final h = habit(paused: true);
      expect(HabitSchedule.isScheduledOn(h, today), isFalse);
      expect(HabitSchedule.isScheduledOn(h, today, ignorePause: true), isTrue);
      // ignorePause never makes days before the start due.
      expect(
        HabitSchedule.isScheduledOn(
          h,
          DateTime(2026, 5, 31),
          ignorePause: true,
        ),
        isFalse,
      );
    });

    test('weekdays only (0x1F)', () {
      final h = habit(frequency: HabitFrequency.weekdays);
      expect(HabitSchedule.isScheduledOn(h, day(-1)), isTrue); // Fri
      expect(HabitSchedule.isScheduledOn(h, today), isFalse); // Sat
      expect(HabitSchedule.isScheduledOn(h, day(1)), isFalse); // Sun
      expect(HabitSchedule.isScheduledOn(h, day(2)), isTrue); // Mon
    });

    test('Mon / Wed / Fri', () {
      final h = habit(
        frequency: HabitFrequency.onWeekdays(const [
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        ]),
      );
      final due = [
        for (var i = 1; i <= 7; i++)
          HabitSchedule.isScheduledOn(h, DateTime(2026, 6, i)),
      ];
      expect(due, [true, false, true, false, true, false, false]);
    });

    test('empty weekday mask is never due', () {
      final h = habit(frequency: const HabitFrequency.specificDays(0));
      expect(HabitSchedule.isScheduledOn(h, today), isFalse);
      expect(HabitSchedule.isScheduledOn(h, day(-1)), isFalse);
    });

    test('times per week: every day may count', () {
      final h = habit(frequency: const HabitFrequency.timesPerWeek(3));
      for (var i = -6; i <= 0; i++) {
        expect(HabitSchedule.isScheduledOn(h, day(i)), isTrue);
      }
    });

    test('every N days counts from the start date (modulo)', () {
      final h = habit(frequency: const HabitFrequency.everyNDays(3));
      final due = [
        for (var i = 1; i <= 10; i++)
          HabitSchedule.isScheduledOn(h, DateTime(2026, 6, i)),
      ];
      expect(due, [
        true, false, false, true, false, false, true, false, false, true, //
      ]);
      expect(HabitSchedule.isScheduledOn(h, today), isTrue); // offset 12
      expect(HabitSchedule.isScheduledOn(h, day(1)), isFalse); // offset 13
    });

    test('every N days with n <= 1 is every day', () {
      for (final n in [0, 1]) {
        final h = habit(frequency: HabitFrequency.everyNDays(n));
        expect(HabitSchedule.isScheduledOn(h, day(-1)), isTrue);
        expect(HabitSchedule.isScheduledOn(h, today), isTrue);
      }
    });

    test('quit habits are due every day regardless of frequency', () {
      final h = habit(kind: HabitKind.quit, frequency: HabitFrequency.weekdays);
      expect(HabitSchedule.isScheduledOn(h, today), isTrue); // Saturday
    });
  });

  group('scheduledDaysBetween', () {
    test('weekdays over two weeks, ascending local midnights', () {
      final h = habit(frequency: HabitFrequency.weekdays);
      final days = HabitSchedule.scheduledDaysBetween(h, day(-12), day(1));
      expect(days, [
        for (final d in [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]) DateTime(2026, 6, d),
      ]);
    });

    test('clipped to the start date', () {
      final h = habit(start: DateTime(2026, 6, 10));
      final days = HabitSchedule.scheduledDaysBetween(h, day(-30), today);
      expect(days.first, DateTime(2026, 6, 10));
      expect(days.last, today);
      expect(days, hasLength(4));
    });

    test('empty when to < from', () {
      final h = habit();
      expect(HabitSchedule.scheduledDaysBetween(h, today, day(-1)), isEmpty);
    });

    test('pause is ignored by default, honoured on request', () {
      final h = habit(paused: true);
      expect(
        HabitSchedule.scheduledDaysBetween(h, day(-2), today),
        hasLength(3),
      );
      expect(
        HabitSchedule.scheduledDaysBetween(
          h,
          day(-2),
          today,
          ignorePause: false,
        ),
        isEmpty,
      );
    });

    test('every N days keeps the modulo from the start date', () {
      final h = habit(frequency: const HabitFrequency.everyNDays(4));
      final days = HabitSchedule.scheduledDaysBetween(h, day(-6), today);
      expect(days, [DateTime(2026, 6, 9), DateTime(2026, 6, 13)]);
    });

    test('spans DST changes without skipping or repeating days', () {
      final h = habit(start: DateTime(2026, 1, 1));
      final days = HabitSchedule.scheduledDaysBetween(
        h,
        DateTime(2026, 3, 1),
        DateTime(2026, 11, 30),
      );
      expect(days, hasLength(275));
      expect(days.toSet(), hasLength(275));
    });
  });

  group('helpers', () {
    test('daysBetween counts calendar days', () {
      expect(
        HabitSchedule.daysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)),
        31,
      );
      expect(HabitSchedule.daysBetween(today, day(-3)), -3);
      expect(
        HabitSchedule.daysBetween(
          DateTime(2026, 6, 13, 23),
          DateTime(2026, 6, 14),
        ),
        1,
      );
    });

    test('isDone / isSlip / progress', () {
      final build = habit(target: 8);
      expect(HabitSchedule.isDone(build, log(today, count: 8)), isTrue);
      expect(
        HabitSchedule.isDone(build, log(today, count: 8, skipped: true)),
        isFalse,
      );
      expect(HabitSchedule.progress(build, log(today, count: 6)), 0.75);
      expect(HabitSchedule.isSlip(build, log(today, count: 3)), isFalse);

      final quit = habit(kind: HabitKind.quit);
      expect(HabitSchedule.isDone(quit, null), isTrue);
      expect(HabitSchedule.isDone(quit, log(today, count: 0)), isTrue);
      expect(HabitSchedule.isSlip(quit, log(today)), isTrue);
      expect(HabitSchedule.isDone(quit, log(today, skipped: true)), isTrue);
      expect(HabitSchedule.progress(quit, log(today)), 0);
      expect(HabitSchedule.progress(quit, null), 1);
    });

    test('indexByDay keys logs by yyyy-MM-dd', () {
      final index = HabitSchedule.indexByDay([log(today), log(day(-1))]);
      expect(index.keys, unorderedEquals(['2026-06-13', '2026-06-12']));
    });
  });
}
