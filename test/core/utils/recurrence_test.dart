import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/recurrence.dart';

/// Local wall time helper (09:00 by default).
DateTime _t(int y, int m, int d, [int h = 9, int min = 0, int s = 0]) =>
    DateTime(y, m, d, h, min, s);

RecurrenceRule _r(String rrule) => RecurrenceRule.parse(rrule);

/// Whole calendar days between two local dates (DST-proof).
int _days(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Every occurrence of [rule] from [start] (inclusive) until [to].
List<DateTime> _all(RecurrenceRule rule, DateTime start, DateTime to) =>
    rule.occurrencesBetween(start, start, to);

void main() {
  group('parse / toRRule', () {
    test('canonical strings round-trip', () {
      const samples = [
        'FREQ=DAILY',
        'FREQ=DAILY;INTERVAL=2;COUNT=5',
        'FREQ=WEEKLY;BYDAY=TU',
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR',
        'FREQ=MONTHLY;BYMONTHDAY=14',
        'FREQ=MONTHLY;BYMONTHDAY=-1',
        'FREQ=MONTHLY;BYDAY=2TU',
        'FREQ=MONTHLY;BYDAY=-1FR',
        'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29',
        'FREQ=YEARLY;INTERVAL=2',
        'FREQ=WEEKLY;BYDAY=TU;UNTIL=20270630',
      ];
      for (final text in samples) {
        final rule = _r(text);
        expect(rule.toRRule(), text, reason: text);
        expect(_r(rule.toRRule()), rule, reason: text);
        expect(rule.toString(), text);
      }
    });

    test('accepts RRULE: prefix, lowercase, spaces and ignores WKST', () {
      final rule = _r(' rrule:freq=weekly; wkst=mo ;byday=tu,th; ');
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.byWeekdays, const [
        WeekdayRule(DateTime.tuesday),
        WeekdayRule(DateTime.thursday),
      ]);
      expect(rule.toRRule(), 'FREQ=WEEKLY;BYDAY=TU,TH');
    });

    test('writes parts in canonical order and omits INTERVAL=1', () {
      final rule = _r(
        'COUNT=4;BYMONTHDAY=1;BYMONTH=1,7;INTERVAL=1;FREQ=YEARLY',
      );
      expect(rule.toRRule(), 'FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=1;COUNT=4');
      expect(
        _r('UNTIL=20270101;BYDAY=+2MO;INTERVAL=3;FREQ=MONTHLY').toRRule(),
        'FREQ=MONTHLY;INTERVAL=3;BYDAY=2MO;UNTIL=20270101',
      );
    });

    test('parses BYDAY ordinals', () {
      expect(_r('FREQ=MONTHLY;BYDAY=2TU,-1FR,SU').byWeekdays, const [
        WeekdayRule(DateTime.tuesday, 2),
        WeekdayRule(DateTime.friday, -1),
        WeekdayRule(DateTime.sunday),
      ]);
    });

    test('UNTIL date form is local midnight (whole day)', () {
      final rule = _r('FREQ=DAILY;UNTIL=20270630');
      expect(rule.until, DateTime(2027, 6, 30));
      expect(rule.toRRule(), 'FREQ=DAILY;UNTIL=20270630');
    });

    test('UNTIL local date-time form is written back in UTC', () {
      final rule = _r('FREQ=DAILY;UNTIL=20270630T183015');
      final until = DateTime(2027, 6, 30, 18, 30, 15);
      expect(rule.until, until);
      final u = until.toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(
        rule.toRRule(),
        'FREQ=DAILY;UNTIL=${u.year}${two(u.month)}${two(u.day)}'
        'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z',
      );
      expect(_r(rule.toRRule()), rule);
    });

    test('UNTIL UTC form converts to local and round-trips', () {
      const text = 'FREQ=WEEKLY;BYDAY=MO;UNTIL=20270630T153045Z';
      final rule = _r(text);
      expect(rule.until!.isUtc, isFalse);
      expect(
        rule.until!.isAtSameMomentAs(DateTime.utc(2027, 6, 30, 15, 30, 45)),
        isTrue,
      );
      expect(rule.toRRule(), text);
      expect(_r(rule.toRRule()), rule);
    });

    test('invalid input: tryParse → null, parse → FormatException', () {
      const invalid = [
        '',
        '   ',
        'RRULE:',
        'FREQ',
        'FREQ=',
        'FREQ=HOURLY',
        'FREQ=SECONDLY',
        'INTERVAL=2',
        'BYDAY=MO',
        'FREQ=DAILY;INTERVAL=0',
        'FREQ=DAILY;INTERVAL=-1',
        'FREQ=DAILY;INTERVAL=two',
        'FREQ=DAILY;COUNT=0',
        'FREQ=WEEKLY;BYDAY=XX',
        'FREQ=WEEKLY;BYDAY=MO,',
        'FREQ=MONTHLY;BYDAY=0MO',
        'FREQ=MONTHLY;BYMONTHDAY=0',
        'FREQ=MONTHLY;BYMONTHDAY=32',
        'FREQ=YEARLY;BYMONTH=13',
        'FREQ=DAILY;UNTIL=tomorrow',
        'FREQ=DAILY;UNTIL=20271340',
        'FREQ=DAILY;UNTIL=20270230',
        'FREQ=DAILY;UNTIL=20270630T250000',
        'FREQ=DAILY;FREQ=WEEKLY',
        'FREQ=MONTHLY;BYDAY=MO;BYSETPOS=-1',
      ];
      expect(RecurrenceRule.tryParse(null), isNull);
      for (final text in invalid) {
        expect(RecurrenceRule.tryParse(text), isNull, reason: text);
        expect(() => RecurrenceRule.parse(text), throwsFormatException);
      }
    });
  });

  group('presets, equality, copyWith', () {
    test('presets produce the expected RRULEs', () {
      expect(RecurrenceRule.daily().toRRule(), 'FREQ=DAILY');
      expect(
        RecurrenceRule.daily(interval: 2).toRRule(),
        'FREQ=DAILY;INTERVAL=2',
      );
      expect(
        RecurrenceRule.weekdays().toRRule(),
        'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      );
      expect(
        RecurrenceRule.weekly(const [
          DateTime.friday,
          DateTime.monday,
          DateTime.friday,
        ]).toRRule(),
        'FREQ=WEEKLY;BYDAY=MO,FR',
      );
      expect(RecurrenceRule.weekly(const []).toRRule(), 'FREQ=WEEKLY');
      expect(
        RecurrenceRule.weekly(const [DateTime.tuesday], interval: 2).toRRule(),
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
      );
      expect(RecurrenceRule.monthly().toRRule(), 'FREQ=MONTHLY');
      expect(
        RecurrenceRule.monthly(dayOfMonth: 14).toRRule(),
        'FREQ=MONTHLY;BYMONTHDAY=14',
      );
      expect(RecurrenceRule.yearly().toRRule(), 'FREQ=YEARLY');
      expect(() => RecurrenceRule.weekly(const [8]), throwsArgumentError);
      expect(() => RecurrenceRule.monthly(dayOfMonth: 0), throwsArgumentError);
    });

    test('isWeekdays', () {
      expect(RecurrenceRule.weekdays().isWeekdays, isTrue);
      expect(_r('FREQ=DAILY;BYDAY=FR,TH,WE,TU,MO').isWeekdays, isTrue);
      expect(_r('FREQ=WEEKLY;BYDAY=MO,TU').isWeekdays, isFalse);
      expect(
        _r('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TU,WE,TH,FR').isWeekdays,
        isFalse,
      );
      expect(_r('FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR').isWeekdays, isFalse);
    });

    test('== / hashCode / WeekdayRule.toString', () {
      expect(_r('FREQ=WEEKLY;BYDAY=TU'), RecurrenceRule.weekly(const [2]));
      expect(
        _r('FREQ=WEEKLY;BYDAY=TU').hashCode,
        RecurrenceRule.weekly(const [2]).hashCode,
      );
      expect(_r('FREQ=WEEKLY;BYDAY=TU'), isNot(_r('FREQ=WEEKLY;BYDAY=WE')));
      expect(const WeekdayRule(DateTime.tuesday).toString(), 'TU');
      expect(const WeekdayRule(DateTime.tuesday, 2).toString(), '2TU');
      expect(const WeekdayRule(DateTime.friday, -1).toString(), '-1FR');
    });

    test('copyWith replaces and clears', () {
      final rule = _r('FREQ=DAILY;COUNT=5');
      expect(
        rule.copyWith(interval: 3).toRRule(),
        'FREQ=DAILY;INTERVAL=3;COUNT=5',
      );
      expect(rule.copyWith(clearCount: true).toRRule(), 'FREQ=DAILY');
      final until = rule.copyWith(
        until: DateTime(2027, 1, 31),
        clearCount: true,
      );
      expect(until.toRRule(), 'FREQ=DAILY;UNTIL=20270131');
      expect(until.copyWith(clearUntil: true), RecurrenceRule.daily());
      expect(rule.copyWith(), rule);
    });
  });

  group('nextAfter', () {
    test('daily and every 2 days', () {
      final start = _t(2026, 10, 1);
      expect(RecurrenceRule.daily().nextAfter(start, start), _t(2026, 10, 2));
      final every2 = RecurrenceRule.daily(interval: 2);
      expect(every2.nextAfter(start, start), _t(2026, 10, 3));
      expect(every2.nextAfter(start, _t(2026, 10, 3)), _t(2026, 10, 5));
      // Between occurrences (mid-day on an "off" day).
      expect(every2.nextAfter(start, _t(2026, 10, 4, 12)), _t(2026, 10, 5));
      // Earlier the same day as an occurrence → that occurrence.
      expect(every2.nextAfter(start, _t(2026, 10, 5, 8)), _t(2026, 10, 5));
    });

    test('before the start returns the start', () {
      final start = _t(2026, 10, 13);
      final rule = _r('FREQ=WEEKLY;BYDAY=MO');
      expect(rule.nextAfter(start, _t(2026, 10, 1)), start);
    });

    test('weekdays skip the weekend (Fri → Mon)', () {
      final friday = _t(2026, 10, 16);
      expect(friday.weekday, DateTime.friday);
      final next = RecurrenceRule.weekdays().nextAfter(friday, friday);
      expect(next, _t(2026, 10, 19));
      expect(next!.weekday, DateTime.monday);
    });

    test('weekly Tue from a Monday start: start is occurrence #1', () {
      final monday = _t(2026, 10, 12);
      expect(monday.weekday, DateTime.monday);
      final rule = _r('FREQ=WEEKLY;BYDAY=TU');
      expect(
        rule.nextAfter(monday, monday.subtract(const Duration(minutes: 1))),
        monday,
      );
      expect(rule.nextAfter(monday, monday), _t(2026, 10, 13));
      expect(rule.nextAfter(monday, _t(2026, 10, 13)), _t(2026, 10, 20));
      expect(_all(rule, monday, _t(2026, 10, 28)), [
        monday,
        _t(2026, 10, 13),
        _t(2026, 10, 20),
        _t(2026, 10, 27),
      ]);
    });

    test('weekly without BYDAY repeats on the start weekday', () {
      final start = _t(2026, 10, 14);
      expect(_r('FREQ=WEEKLY').nextAfter(start, start), _t(2026, 10, 21));
    });

    test('weekly on several days, start matching does not duplicate', () {
      final monday = _t(2026, 10, 12);
      final rule = _r('FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(_all(rule, monday, _t(2026, 10, 24)), [
        _t(2026, 10, 12),
        _t(2026, 10, 14),
        _t(2026, 10, 16),
        _t(2026, 10, 19),
        _t(2026, 10, 21),
        _t(2026, 10, 23),
      ]);
      expect(rule.nextAfter(monday, _t(2026, 10, 16, 10)), _t(2026, 10, 19));
    });

    test('every 2 weeks', () {
      final tuesday = _t(2026, 10, 13);
      final rule = _r('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
      expect(rule.nextAfter(tuesday, tuesday), _t(2026, 10, 27));
      expect(rule.nextAfter(tuesday, _t(2026, 10, 27)), _t(2026, 11, 10));

      final multi = _r('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH');
      expect(_all(multi, _t(2026, 10, 12), _t(2026, 11, 1)), [
        _t(2026, 10, 12),
        _t(2026, 10, 15),
        _t(2026, 10, 26),
        _t(2026, 10, 29),
      ]);
      // Jumping straight to a far week keeps the 2-week phase.
      final far = multi.nextAfter(_t(2026, 10, 12), _t(2030, 6, 1));
      expect(_days(_t(2026, 10, 12), far!) % 14, anyOf(0, 3));
    });

    test('monthly on the 14th', () {
      final start = _t(2026, 1, 14, 10);
      final rule = RecurrenceRule.monthly(dayOfMonth: 14);
      expect(rule.nextAfter(start, start), _t(2026, 2, 14, 10));
      expect(rule.nextAfter(start, _t(2026, 2, 20)), _t(2026, 3, 14, 10));
      // No BYMONTHDAY → the start's day.
      expect(_r('FREQ=MONTHLY').nextAfter(start, start), _t(2026, 2, 14, 10));
    });

    test('monthly on the 31st skips shorter months', () {
      final start = _t(2026, 1, 31);
      expect(_all(_r('FREQ=MONTHLY'), start, _t(2027, 1, 1)), [
        _t(2026, 1, 31),
        _t(2026, 3, 31),
        _t(2026, 5, 31),
        _t(2026, 7, 31),
        _t(2026, 8, 31),
        _t(2026, 10, 31),
        _t(2026, 12, 31),
      ]);
    });

    test('monthly last day (-1) handles leap and non-leap February', () {
      final rule = _r('FREQ=MONTHLY;BYMONTHDAY=-1');
      expect(_all(rule, _t(2024, 1, 31), _t(2024, 5, 1)), [
        _t(2024, 1, 31),
        _t(2024, 2, 29),
        _t(2024, 3, 31),
        _t(2024, 4, 30),
      ]);
      expect(rule.nextAfter(_t(2025, 1, 31), _t(2025, 1, 31)), _t(2025, 2, 28));
    });

    test('monthly 2nd Tue and last Fri', () {
      final start = _t(2026, 10, 1);
      final secondTue = _r('FREQ=MONTHLY;BYDAY=2TU');
      expect(secondTue.nextAfter(start, start), _t(2026, 10, 13));
      expect(secondTue.nextAfter(start, _t(2026, 10, 13)), _t(2026, 11, 10));

      final lastFri = _r('FREQ=MONTHLY;BYDAY=-1FR');
      expect(lastFri.nextAfter(start, start), _t(2026, 10, 30));
      expect(lastFri.nextAfter(start, _t(2026, 10, 30)), _t(2026, 11, 27));
      for (final d in _all(lastFri, start, _t(2027, 10, 1)).skip(1)) {
        expect(d.weekday, DateTime.friday);
        expect(DateTime(d.year, d.month, d.day + 7).month, isNot(d.month));
      }
    });

    test('yearly on Feb 29 → next leap year', () {
      final start = _t(2024, 2, 29);
      final rule = RecurrenceRule.yearly();
      expect(rule.nextAfter(start, start), _t(2028, 2, 29));
      expect(rule.nextAfter(start, _t(2028, 3, 1)), _t(2032, 2, 29));
    });

    test('yearly with BYMONTH + BYMONTHDAY', () {
      final start = _t(2026, 1, 1);
      final rule = _r('FREQ=YEARLY;BYMONTH=6;BYMONTHDAY=13');
      expect(rule.nextAfter(start, start), _t(2026, 6, 13));
      expect(rule.nextAfter(start, _t(2026, 6, 13)), _t(2027, 6, 13));
    });

    test('COUNT ends the series (start counts as #1)', () {
      final start = _t(2026, 1, 1);
      final rule = _r('FREQ=DAILY;COUNT=3');
      expect(rule.nextAfter(start, start), _t(2026, 1, 2));
      expect(rule.nextAfter(start, _t(2026, 1, 2)), _t(2026, 1, 3));
      expect(rule.nextAfter(start, _t(2026, 1, 3)), isNull);
      expect(_all(rule, start, _t(2027, 1, 1)).length, 3);

      // A non-matching start still counts.
      final weekly = _r('FREQ=WEEKLY;BYDAY=TU;COUNT=2');
      final monday = _t(2026, 10, 12);
      expect(_all(weekly, monday, _t(2027, 1, 1)), [monday, _t(2026, 10, 13)]);
      expect(_r('FREQ=DAILY;COUNT=1').nextAfter(start, start), isNull);
    });

    test('UNTIL date form includes that whole day', () {
      final start = _t(2026, 10, 6);
      final rule = _r('FREQ=WEEKLY;BYDAY=TU;UNTIL=20261020');
      expect(_all(rule, start, _t(2027, 1, 1)), [
        _t(2026, 10, 6),
        _t(2026, 10, 13),
        _t(2026, 10, 20),
      ]);
      expect(rule.nextAfter(start, _t(2026, 10, 13)), _t(2026, 10, 20));
      expect(rule.nextAfter(start, _t(2026, 10, 20)), isNull);
    });

    test('UNTIL date-time form is inclusive of that instant only', () {
      final start = _t(2026, 10, 1);
      final atNine = _r('FREQ=DAILY;UNTIL=20261003T090000');
      expect(atNine.nextAfter(start, _t(2026, 10, 2)), _t(2026, 10, 3));
      final atEight = _r('FREQ=DAILY;UNTIL=20261003T080000');
      expect(atEight.nextAfter(start, _t(2026, 10, 2)), isNull);
    });

    test('time of day is preserved', () {
      final start = _t(2026, 1, 15, 7, 45, 30);
      for (final rule in [
        _r('FREQ=DAILY;INTERVAL=5'),
        _r('FREQ=WEEKLY;BYDAY=MO,SA'),
        _r('FREQ=MONTHLY;BYDAY=-1SU'),
        _r('FREQ=YEARLY;BYMONTH=3,9'),
      ]) {
        final all = _all(rule, start, _t(2028, 1, 1));
        expect(all.length, greaterThan(2), reason: rule.toRRule());
        for (final d in all) {
          expect([d.hour, d.minute, d.second], [7, 45, 30]);
        }
      }
    });

    test('far-future lookups without COUNT are fast', () {
      final start = _t(2020, 1, 1);
      final daily = RecurrenceRule.daily();
      final every3 = RecurrenceRule.daily(interval: 3);
      final watch = Stopwatch()..start();
      expect(daily.nextAfter(start, _t(2030, 6, 15, 10)), _t(2030, 6, 16));
      final next = every3.nextAfter(start, _t(2030, 6, 15, 10))!;
      expect(_days(start, next) % 3, 0);
      expect(_days(_t(2030, 6, 15), next), inInclusiveRange(1, 3));
      expect(
        daily.occurrencesBetween(start, _t(2030, 6, 1), _t(2030, 7, 1)).length,
        30,
      );
      expect(
        _r('FREQ=WEEKLY;BYDAY=TU').nextAfter(start, _t(2099, 1, 1))!.weekday,
        DateTime.tuesday,
      );
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(100));
    });

    test('impossible rules return null/empty without hanging', () {
      final start = _t(2026, 1, 1);
      final watch = Stopwatch()..start();
      for (final text in [
        'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30',
        'FREQ=MONTHLY;BYMONTH=4;BYMONTHDAY=31',
        'FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30',
        'FREQ=MONTHLY;BYDAY=6MO',
      ]) {
        final rule = _r(text);
        expect(rule.nextAfter(start, start), isNull, reason: text);
        expect(
          rule.occurrencesBetween(start, _t(2026, 1, 2), _t(2100, 1, 1)),
          isEmpty,
          reason: text,
        );
      }
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('occurrencesBetween (calendar)', () {
    test('a month of Mon/Wed/Fri', () {
      final rule = _r('FREQ=WEEKLY;BYDAY=MO,WE,FR');
      final feb = rule.occurrencesBetween(
        _t(2026, 1, 5),
        DateTime(2026, 2),
        DateTime(2026, 3),
      );
      expect(feb.map((d) => d.day), [
        2,
        4,
        6,
        9,
        11,
        13,
        16,
        18,
        20,
        23,
        25,
        27,
      ]);
    });

    test('from is inclusive, to is exclusive', () {
      final start = DateTime(2026, 1, 1);
      final rule = RecurrenceRule.daily();
      final feb = rule.occurrencesBetween(
        start,
        DateTime(2026, 2),
        DateTime(2026, 3),
      );
      expect(feb.length, 28);
      expect(feb.first, DateTime(2026, 2, 1));
      expect(feb.last, DateTime(2026, 2, 28));
    });

    test('includes the start when it is in range, respects limit', () {
      final start = _t(2026, 2, 10);
      final rule = _r('FREQ=WEEKLY;BYDAY=FR');
      final feb = rule.occurrencesBetween(
        start,
        DateTime(2026, 2),
        DateTime(2026, 3),
      );
      expect(feb, [
        _t(2026, 2, 10),
        _t(2026, 2, 13),
        _t(2026, 2, 20),
        _t(2026, 2, 27),
      ]);
      expect(
        rule.occurrencesBetween(
          start,
          DateTime(2026, 2),
          DateTime(2026, 3),
          limit: 2,
        ),
        [_t(2026, 2, 10), _t(2026, 2, 13)],
      );
      expect(
        rule.occurrencesBetween(start, DateTime(2026, 3), DateTime(2026, 2)),
        isEmpty,
      );
    });

    test('nothing before the start', () {
      final rule = RecurrenceRule.daily();
      expect(
        rule.occurrencesBetween(
          _t(2026, 3, 1),
          DateTime(2026, 2),
          DateTime(2026, 3),
        ),
        isEmpty,
      );
    });
  });

  group('DST safety', () {
    // EU switches on the last Sundays of March/October, the US on the second
    // Sunday of March / first Sunday of November. Whatever zone runs the tests,
    // a 09:00 series must stay at 09:00 on consecutive calendar days.
    final windows = [
      (DateTime(2026, 3, 1, 9), DateTime(2026, 5, 1)),
      (DateTime(2026, 10, 1, 9), DateTime(2026, 12, 1)),
    ];

    test('daily 09:00 stays at 09:00 local', () {
      for (final (start, end) in windows) {
        final all = _all(RecurrenceRule.daily(), start, end);
        expect(all.length, _days(start, end));
        for (var i = 0; i < all.length; i++) {
          expect([all[i].hour, all[i].minute], [9, 0], reason: '${all[i]}');
          if (i > 0) expect(_days(all[i - 1], all[i]), 1);
        }
      }
    });

    test('nextAfter steps day by day across the switch', () {
      for (final (start, end) in windows) {
        final rule = RecurrenceRule.daily();
        var current = start;
        while (current.isBefore(end)) {
          final next = rule.nextAfter(start, current)!;
          expect([next.hour, next.minute], [9, 0]);
          expect(_days(current, next), 1);
          current = next;
        }
      }
    });

    test('weekly and monthly keep the wall time', () {
      for (final (start, end) in windows) {
        for (final rule in [
          _r('FREQ=WEEKLY;BYDAY=SU,MO'),
          _r('FREQ=MONTHLY;BYDAY=1SU,2SU,-1SU'),
        ]) {
          for (final d in _all(rule, start, end)) {
            expect([d.hour, d.minute], [9, 0], reason: '${rule.toRRule()} $d');
          }
        }
      }
    });
  });

  group('labels', () {
    String label(String rrule, {DateTime? start}) =>
        _r(rrule).label(start: start);

    test('daily', () {
      expect(label('FREQ=DAILY'), 'Daily');
      expect(label('FREQ=DAILY;INTERVAL=3'), 'Every 3 days');
      expect(label('FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'), 'Weekdays');
      expect(label('FREQ=DAILY;BYDAY=SA,SU'), 'Weekends');
    });

    test('weekly', () {
      expect(label('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'), 'Weekdays');
      expect(label('FREQ=WEEKLY;BYDAY=SA,SU'), 'Weekends');
      expect(label('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU'), 'Daily');
      expect(label('FREQ=WEEKLY;BYDAY=TU'), 'Weekly · Tue');
      expect(label('FREQ=WEEKLY;BYDAY=MO,WE,FR'), 'Weekly · Mon, Wed, Fri');
      expect(label('FREQ=WEEKLY'), 'Weekly');
      expect(label('FREQ=WEEKLY', start: _t(2026, 10, 13)), 'Weekly · Tue');
      expect(label('FREQ=WEEKLY;INTERVAL=2'), 'Every 2 weeks');
      expect(
        label('FREQ=WEEKLY;INTERVAL=2', start: _t(2026, 10, 13)),
        'Every 2 weeks · Tue',
      );
      expect(label('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU'), 'Every 2 weeks · Tue');
      expect(
        label('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE'),
        'Every 2 weeks · Mon, Wed',
      );
    });

    test('monthly', () {
      expect(label('FREQ=MONTHLY'), 'Monthly');
      expect(label('FREQ=MONTHLY', start: _t(2026, 1, 14)), 'Monthly · 14th');
      expect(label('FREQ=MONTHLY;BYMONTHDAY=14'), 'Monthly · 14th');
      expect(label('FREQ=MONTHLY;BYMONTHDAY=-1'), 'Monthly · last day');
      expect(label('FREQ=MONTHLY;BYDAY=2TU'), 'Monthly · 2nd Tue');
      expect(label('FREQ=MONTHLY;BYDAY=-1FR'), 'Monthly · last Fri');
      expect(
        label('FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=14'),
        'Every 3 months · 14th',
      );
    });

    test('ordinal suffixes', () {
      const expected = {
        1: '1st',
        2: '2nd',
        3: '3rd',
        4: '4th',
        11: '11th',
        12: '12th',
        13: '13th',
        21: '21st',
        22: '22nd',
        23: '23rd',
        31: '31st',
      };
      expected.forEach((day, text) {
        expect(label('FREQ=MONTHLY;BYMONTHDAY=$day'), 'Monthly · $text');
      });
    });

    test('yearly', () {
      expect(label('FREQ=YEARLY'), 'Yearly');
      expect(label('FREQ=YEARLY', start: _t(2026, 6, 13)), 'Yearly · Jun 13');
      expect(label('FREQ=YEARLY;BYMONTH=6;BYMONTHDAY=13'), 'Yearly · Jun 13');
      expect(label('FREQ=YEARLY;INTERVAL=2'), 'Every 2 years');
    });

    test('COUNT and UNTIL suffixes', () {
      expect(label('FREQ=DAILY;COUNT=5'), 'Daily · 5 times');
      expect(
        label('FREQ=WEEKLY;BYDAY=TU;UNTIL=20270630'),
        'Weekly · Tue · until Jun 30',
      );
    });

    test('Recurrence.label', () {
      expect(Recurrence.label(null), 'Once');
      expect(Recurrence.label(''), 'Once');
      expect(Recurrence.label('FREQ=HOURLY'), 'Once');
      expect(Recurrence.label('FREQ=WEEKLY;BYDAY=TU'), 'Weekly · Tue');
      expect(
        Recurrence.label('FREQ=MONTHLY', start: _t(2026, 1, 1)),
        'Monthly · 1st',
      );
    });
  });

  group('Recurrence (string helpers)', () {
    test('nextAfter', () {
      final start = _t(2026, 10, 12);
      expect(Recurrence.nextAfter(null, start, start), isNull);
      expect(Recurrence.nextAfter('nonsense', start, start), isNull);
      expect(
        Recurrence.nextAfter('RRULE:FREQ=WEEKLY;BYDAY=TU', start, start),
        _t(2026, 10, 13),
      );
    });

    test('occurrencesBetween without a rule is the single start', () {
      final start = _t(2026, 2, 10);
      expect(
        Recurrence.occurrencesBetween(
          null,
          start,
          DateTime(2026, 2),
          DateTime(2026, 3),
        ),
        [start],
      );
      expect(
        Recurrence.occurrencesBetween(
          null,
          start,
          DateTime(2026, 3),
          DateTime(2026, 4),
        ),
        isEmpty,
      );
      expect(
        Recurrence.occurrencesBetween(
          'FREQ=DAILY',
          start,
          DateTime(2026, 2),
          DateTime(2026, 3),
        ).length,
        19,
      );
    });

    test('isRepeating', () {
      expect(Recurrence.isRepeating('FREQ=DAILY'), isTrue);
      expect(Recurrence.isRepeating(null), isFalse);
      expect(Recurrence.isRepeating('FREQ=HOURLY'), isFalse);
    });
  });
}
