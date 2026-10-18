// The integer-based StreakCalculator / HabitSchedule must agree with the
// plain DateTime-per-day rules on every input: randomised habits (every
// frequency, build and quit, paused), messy logs (out of range, skipped,
// zero counts) and every week start — plus the day-number arithmetic they
// stand on.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

import 'reference_streak_calculator.dart';

HabitLog _log(String habit, DateTime day, int count, bool skipped) => HabitLog(
  id: '$habit-${DateUtilsX.dayKey(day)}',
  habitId: habit,
  date: day,
  count: count,
  skipped: skipped,
  createdAt: day,
  updatedAt: day,
);

void main() {
  group('day numbers', () {
    test('daysFromCivil matches the UTC epoch for 300 years of days', () {
      var day = DateTime.utc(1900);
      final end = DateTime.utc(2200);
      while (day.isBefore(end)) {
        final expected =
            day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
        expect(
          DateUtilsX.daysFromCivil(day.year, day.month, day.day),
          expected,
          reason: '$day',
        );
        day = day.add(const Duration(days: 1));
      }
    });

    test('weekdayOfNumber matches DateTime.weekday', () {
      var day = DateTime.utc(1969, 12, 20);
      for (var i = 0; i < 20000; i++) {
        expect(
          HabitSchedule.weekdayOfNumber(DateUtilsX.dayNumber(day)),
          day.weekday,
          reason: '$day',
        );
        day = DateTime.utc(day.year, day.month, day.day + 1);
      }
    });

    test('dayNumberOfKey reads dayKey, and tolerates other shapes', () {
      for (final d in [
        DateTime(2026, 6, 13),
        DateTime(2024, 2, 29),
        DateTime(1999, 12, 31),
        DateTime(2100, 1, 1),
      ]) {
        expect(
          DateUtilsX.dayNumberOfKey(DateUtilsX.dayKey(d)),
          DateUtilsX.dayNumber(d),
        );
      }
      expect(
        DateUtilsX.dayNumberOfKey('2026-6-13'),
        DateUtilsX.dayNumber(DateTime(2026, 6, 13)),
      );
      expect(() => DateUtilsX.dayNumberOfKey('nope'), throwsFormatException);
      expect(
        () => DateUtilsX.dayNumberOfKey('20x6-06-13'),
        throwsFormatException,
      );
    });

    test('daysBetween counts calendar days across DST changes', () {
      final r = Random(3);
      for (var i = 0; i < 2000; i++) {
        final a = DateTime(
          2020 + r.nextInt(8),
          1 + r.nextInt(12),
          1 + r.nextInt(28),
        );
        final b = DateTime(
          2020 + r.nextInt(8),
          1 + r.nextInt(12),
          1 + r.nextInt(28),
        );
        final expected = DateTime.utc(
          b.year,
          b.month,
          b.day,
        ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
        expect(HabitSchedule.daysBetween(a, b), expected, reason: '$a → $b');
      }
    });
  });

  group('HabitLog keyed', () {
    test('derives date and key on demand and equals the eager log', () {
      final eager = _log('h', DateTime(2026, 6, 13), 2, false);
      final keyed = HabitLog.keyed(
        id: eager.id,
        habitId: 'h',
        dayKey: '2026-06-13',
        count: 2,
        createdAt: eager.createdAt,
        updatedAt: eager.updatedAt,
      );
      expect(keyed.date, DateTime(2026, 6, 13));
      expect(keyed.dayKey, '2026-06-13');
      expect(keyed, eager);
      expect(keyed.hashCode, eager.hashCode);
      expect(keyed.copyWith(count: 3).dayKey, '2026-06-13');
      expect(keyed.copyWith(count: 3).date, DateTime(2026, 6, 13));
      expect(keyed.copyWith(count: 3), isNot(eager));
    });
  });

  group('StreakCalculator == reference', () {
    HabitFrequency frequency(Random r) => switch (r.nextInt(5)) {
      0 => const HabitFrequency.everyDay(),
      1 => HabitFrequency.specificDays(r.nextInt(128)),
      2 => HabitFrequency.timesPerWeek(1 + r.nextInt(9)),
      3 => HabitFrequency.everyNDays(r.nextInt(6)),
      _ => const HabitFrequency.everyDay(),
    };

    for (final weekStart in [1, 2, 3, 4, 5, 6, 7]) {
      test('week starting on $weekStart: 400 random habits', () {
        final r = Random(100 + weekStart);
        final fast = StreakCalculator(weekStartsOn: weekStart);
        final slow = ReferenceStreakCalculator(weekStartsOn: weekStart);
        for (var n = 0; n < 400; n++) {
          final start = DateTime(2025, 1 + r.nextInt(12), 1 + r.nextInt(28));
          final today = DateTime(
            start.year,
            start.month,
            start.day - 3 + r.nextInt(420),
          );
          final habit = Habit(
            id: 'h',
            name: 'H',
            kind: r.nextInt(4) == 0 ? HabitKind.quit : HabitKind.build,
            targetCount: 1 + r.nextInt(4),
            frequency: frequency(r),
            startDate: start,
            isPaused: r.nextInt(8) == 0,
            createdAt: start,
            updatedAt: start,
          );
          final logs = <HabitLog>[
            for (var i = -5; i <= 430; i++)
              if (r.nextInt(10) < 6)
                _log(
                  'h',
                  DateTime(start.year, start.month, start.day + i),
                  r.nextInt(6),
                  r.nextInt(7) == 0,
                ),
          ];
          final a = fast.calculate(habit, logs, today);
          final b = slow.calculate(habit, logs, today);
          expect(
            a,
            b,
            reason:
                '${habit.frequency.label} ${habit.kind.name} start=$start '
                'today=$today',
          );
        }
      });
    }

    test('a stored (keyed) history gives the same streak as an eager one', () {
      final habit = Habit(
        id: 'h',
        name: 'H',
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final eager = [
        for (var i = 0; i < 100; i++)
          _log('h', DateTime(2026, 1, 1 + i), 1, false),
      ];
      final keyed = [
        for (final l in eager)
          HabitLog.keyed(
            id: l.id,
            habitId: l.habitId,
            dayKey: l.dayKey,
            count: l.count,
            createdAt: l.createdAt,
            updatedAt: l.updatedAt,
          ),
      ];
      final today = DateTime(2026, 4, 10);
      expect(
        const StreakCalculator().calculate(habit, keyed, today),
        const StreakCalculator().calculate(habit, eager, today),
      );
    });
  });

  group('HabitSchedule == the plain rules', () {
    test('isScheduledOn and scheduledDaysBetween over random habits', () {
      final r = Random(77);
      for (var n = 0; n < 300; n++) {
        final start = DateTime(2025, 1 + r.nextInt(12), 1 + r.nextInt(28));
        final habit = Habit(
          id: 'h',
          name: 'H',
          kind: r.nextInt(5) == 0 ? HabitKind.quit : HabitKind.build,
          frequency: switch (r.nextInt(4)) {
            0 => const HabitFrequency.everyDay(),
            1 => HabitFrequency.specificDays(r.nextInt(128)),
            2 => HabitFrequency.timesPerWeek(1 + r.nextInt(7)),
            _ => HabitFrequency.everyNDays(r.nextInt(6)),
          },
          startDate: start,
          isPaused: r.nextInt(6) == 0,
          createdAt: start,
          updatedAt: start,
        );
        final from = DateTime(start.year, start.month, start.day - 4);
        final to = DateTime(start.year, start.month, start.day + 200);
        final days = HabitSchedule.scheduledDaysBetween(habit, from, to);
        final expected = <DateTime>[];
        for (
          var d = from;
          !d.isAfter(to);
          d = DateTime(d.year, d.month, d.day + 1)
        ) {
          final offset = HabitSchedule.daysBetween(start, d);
          if (offset < 0) continue;
          final due =
              habit.isQuit ||
              switch (habit.frequency) {
                EveryDayFrequency() => true,
                final SpecificDaysFrequency f => f.includes(d.weekday),
                TimesPerWeekFrequency() => true,
                EveryNDaysFrequency(:final days) =>
                  days <= 1 || offset % days == 0,
              };
          if (due) expected.add(d);
          expect(
            HabitSchedule.isScheduledOn(habit, d, ignorePause: true),
            due,
            reason: '${habit.frequency.label} $d',
          );
        }
        expect(days, expected, reason: habit.frequency.label);
      }
    });
  });
}
