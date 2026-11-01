/// HijriDate: the tabular Islamic calendar — round trips, month lengths,
/// known anchors, the user day adjustment and the formatting.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';

/// Whole days from [a] to [b] (calendar dates, DST-proof).
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

void main() {
  test('Gregorian → Hijri → Gregorian, every day of 2020–2030', () {
    HijriDate? prev;
    for (var i = 0; ; i++) {
      final d = DateTime(2020, 1, 1 + i);
      if (d.year > 2030) break;
      final h = HijriDate.fromGregorian(d);
      expect(h.toGregorian(), d, reason: '$d → $h');
      final len = HijriDate.daysInMonth(h.year, h.month);
      expect(h.day, inInclusiveRange(1, len));
      if (prev != null && h.day != 1) {
        expect((h.year, h.month, h.day), (prev.year, prev.month, prev.day + 1));
      }
      prev = h;
    }
  });

  test('months are 29 or 30 days and years 354 or 355', () {
    for (var y = 1440; y <= 1460; y++) {
      var yearDays = 0;
      for (var m = 1; m <= 12; m++) {
        final next = m == 12 ? HijriDate(y + 1, 1, 1) : HijriDate(y, m + 1, 1);
        final len = _daysBetween(
          HijriDate(y, m, 1).toGregorian(),
          next.toGregorian(),
        );
        expect(len, anyOf(29, 30));
        expect(len, HijriDate.daysInMonth(y, m));
        yearDays += len;
      }
      expect(yearDays, HijriDate.isLeapYear(y) ? 355 : 354);
    }
  });

  test('leap years of the 30-year cycle and the epoch', () {
    final leaps = [
      for (var y = 1; y <= 30; y++)
        if (HijriDate.isLeapYear(y)) y,
    ];
    expect(leaps, [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]);
    // 16 July 622 Julian = 19 July 622 in the proleptic Gregorian calendar.
    expect(
      HijriDate.fromGregorian(DateTime(622, 7, 19)),
      const HijriDate(1, 1, 1),
    );
  });

  test('known anchors are within a day of the tabular calendar', () {
    void near(HijriDate h, DateTime g) {
      final got = h.toGregorian();
      expect(_daysBetween(g, got).abs(), lessThanOrEqualTo(1), reason: '$h');
    }

    near(const HijriDate(1446, 1, 1), DateTime(2024, 7, 7));
    near(const HijriDate(1447, 9, 1), DateTime(2026, 2, 18));
    near(const HijriDate(1446, 9, 1), DateTime(2025, 3, 1));
    near(const HijriDate(1445, 10, 1), DateTime(2024, 4, 10));
    expect(HijriDate.fromGregorian(DateTime(2026, 2, 18)).isRamadan, isTrue);
  });

  test('adjustDays shifts by exactly that many days (clamped to ±3)', () {
    final d = DateTime(2026, 11, 1);
    for (var n = -3; n <= 3; n++) {
      expect(
        HijriDate.fromGregorian(d, adjustDays: n),
        HijriDate.fromGregorian(DateTime(2026, 11, 1 + n)),
      );
    }
    expect(
      HijriDate.fromGregorian(d, adjustDays: 9),
      HijriDate.fromGregorian(d, adjustDays: 3),
    );
    expect(
      HijriDate.fromGregorian(d, adjustDays: -9),
      HijriDate.fromGregorian(d, adjustDays: -3),
    );
  });

  test('only the date counts, not the time of day', () {
    expect(
      HijriDate.fromGregorian(DateTime(2026, 3, 5, 23, 59)),
      HijriDate.fromGregorian(DateTime(2026, 3, 5)),
    );
  });

  test('format, month names and toString', () {
    expect(const HijriDate(1448, 5, 10).format(), '10 Jumada al-Ula 1448');
    expect(const HijriDate(1447, 9, 1).monthName, 'Ramadan');
    for (var m = 1; m <= 12; m++) {
      expect(hijriMonthName(m), isNotEmpty);
    }
    expect(hijriMonthName(13), '');
    expect(const HijriDate(1447, 9, 1).toString(), 'HijriDate(1447-09-01)');
  });
}
