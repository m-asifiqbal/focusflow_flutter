/// The calendar engines behind the calendar rules: the Hebrew calendar
/// (checked against known dates: Rosh Hashanah, Pesach, Yom Kippur, Purim,
/// Tisha B'Av, Chanukah, the Shabbat shifts of the fasts, the Omer), Easter
/// and Orthodox Pascha, Advent and the liturgical seasons, and the Moon's
/// elongation at the instants of the new and full moon, the tithi and the
/// day of a phase.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/christian_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/hebrew_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/lunar_calendar.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('Hebrew calendar', () {
    DateTime civil(int year, int month, int day) =>
        HebrewCalendar.toCivil(HebrewDate(year, month, day));

    test('known dates', () {
      expect(
        civil(5787, HebrewDate.tishrei, 1),
        d(2026, 9, 12),
      ); // Rosh Hashanah
      expect(civil(5786, HebrewDate.tishrei, 1), d(2025, 9, 23));
      expect(civil(5786, HebrewDate.tishrei, 10), d(2025, 10, 2)); // Yom Kippur
      expect(civil(5786, HebrewDate.nisan, 15), d(2026, 4, 2)); // Pesach
      expect(civil(5786, HebrewDate.adar, 14), d(2026, 3, 3)); // Purim
      expect(civil(5786, HebrewDate.av, 9), d(2026, 7, 23)); // Tisha B'Av
      expect(civil(5787, HebrewDate.kislev, 25), d(2026, 12, 5)); // Chanukah
      expect(civil(5787, HebrewDate.adarII, 13), d(2027, 3, 22));
    });

    test('leap years and year lengths', () {
      expect(HebrewCalendar.isLeapYear(5787), isTrue);
      expect(HebrewCalendar.isLeapYear(5786), isFalse);
      expect(HebrewCalendar.lastMonth(5787), 13);
      for (var y = 5700; y < 5900; y++) {
        expect(
          {353, 354, 355, 383, 384, 385},
          contains(HebrewCalendar.daysInYear(y)),
          reason: '$y',
        );
      }
    });

    test('every day round-trips, and the day count only steps by one', () {
      var day = d(2020, 1, 1);
      var prev = HebrewCalendar.fromCivil(day);
      for (var i = 0; i < 366 * 12; i++) {
        day = DateTime(day.year, day.month, day.day + 1);
        final h = HebrewCalendar.fromCivil(day);
        expect(HebrewCalendar.toCivil(h), day, reason: '$day $h');
        final stepped = h.day == prev.day + 1 && h.month == prev.month;
        final rolled = h.day == 1;
        expect(stepped || rolled, isTrue, reason: '$prev → $h');
        prev = h;
      }
    });

    test('the Hebrew day begins at sunset', () {
      final noon = DateTime(2026, 9, 11, 12);
      final sunset = DateTime(2026, 9, 11, 18);
      expect(HebrewCalendar.atTime(noon, sunset).day, 29); // 29 Elul
      expect(HebrewCalendar.atTime(DateTime(2026, 9, 11, 19), sunset).day, 1);
      expect(
        HebrewCalendar.atTime(DateTime(2026, 9, 11, 19), sunset).month,
        HebrewDate.tishrei,
      );
    });

    test('fast days and their Shabbat shifts', () {
      expect(HebrewCalendar.fastDay('gedaliah', 5787), d(2026, 9, 14));
      // 3 Tishrei 5775 was a Shabbat: Sunday 28 Sep 2014.
      expect(HebrewCalendar.fastDay('gedaliah', 5775), d(2014, 9, 28));
      // 9 Av 5785 was a Shabbat: Tisha B'Av was kept on Sunday 3 Aug 2025.
      expect(HebrewCalendar.fastDay('tishabav', 5785), d(2025, 8, 3));
      // 13 Adar 5774 was a Shabbat: Thursday 13 Mar 2014.
      expect(HebrewCalendar.fastDay('esther', 5774), d(2014, 3, 13));
      expect(HebrewCalendar.fastDay('esther', 5786), d(2026, 3, 2));
      expect(HebrewCalendar.fastDay('tammuz', 5786), d(2026, 7, 2));
      expect(HebrewCalendar.fastDay('yomkippur', 5787), d(2026, 9, 21));
      expect(HebrewCalendar.isFast('tishabav', d(2026, 7, 23)), isTrue);
      expect(HebrewCalendar.isFast('tishabav', d(2026, 7, 24)), isFalse);
      // No shifted fast day falls on a Shabbat (Yom Kippur may: 2024).
      for (var y = 5780; y < 5800; y++) {
        for (final id in HebrewCalendar.fastIds.where(
          (i) => i != 'yomkippur',
        )) {
          expect(
            HebrewCalendar.fastDay(id, y).weekday,
            isNot(DateTime.saturday),
            reason: '$id $y',
          );
        }
      }
    });

    test('Omer, Chanukah, Rosh Chodesh and Yom Tov', () {
      expect(HebrewCalendar.omerTonight(d(2026, 4, 2)), 1);
      expect(HebrewCalendar.omerTonight(d(2026, 5, 20)), 49);
      expect(HebrewCalendar.omerTonight(d(2026, 5, 21)), isNull);
      expect(HebrewCalendar.omerTonight(d(2026, 4, 1)), isNull);
      // Chanukah: the first candle on the evening of 24 Kislev (4 Dec 2026).
      expect(HebrewCalendar.chanukahTonight(d(2026, 12, 4)), 1);
      expect(HebrewCalendar.chanukahTonight(d(2026, 12, 11)), 8);
      expect(HebrewCalendar.chanukahTonight(d(2026, 12, 12)), isNull);
      expect(
        HebrewCalendar.isRoshChodesh(d(2026, 9, 12)),
        isFalse,
      ); // Rosh Hashanah
      expect(
        HebrewCalendar.isRoshChodesh(d(2026, 10, 12)),
        isTrue,
      ); // 1 Cheshvan
      expect(HebrewCalendar.isYomTov(d(2026, 4, 2), inIsrael: false), isTrue);
      expect(HebrewCalendar.isYomTov(d(2026, 4, 3), inIsrael: false), isTrue);
      expect(HebrewCalendar.isYomTov(d(2026, 4, 3), inIsrael: true), isFalse);
      expect(
        HebrewCalendar.isYomTov(d(2026, 4, 4), inIsrael: false),
        isFalse,
      ); // chol hamoed
    });
  });

  group('Christian calendar', () {
    test('Easter and Pascha', () {
      expect(ChristianCalendar.easter(2024), d(2024, 3, 31));
      expect(ChristianCalendar.easter(2025), d(2025, 4, 20));
      expect(ChristianCalendar.easter(2026), d(2026, 4, 5));
      expect(ChristianCalendar.easter(2027), d(2027, 3, 28));
      expect(ChristianCalendar.pascha(2024), d(2024, 5, 5));
      expect(ChristianCalendar.pascha(2025), d(2025, 4, 20));
      expect(ChristianCalendar.pascha(2026), d(2026, 4, 12));
      expect(ChristianCalendar.pascha(2027), d(2027, 5, 2));
    });

    test('Advent and the seasons', () {
      expect(ChristianCalendar.advent(2026), d(2026, 11, 29));
      expect(ChristianCalendar.advent(2027), d(2027, 11, 28));
      // 2026: Ash Wednesday 18 Feb, Palm Sunday 29 Mar, Pentecost 24 May.
      expect(
        ChristianCalendar.season(d(2026, 2, 17)),
        LiturgicalSeason.ordinary,
      );
      expect(ChristianCalendar.season(d(2026, 2, 18)), LiturgicalSeason.lent);
      expect(ChristianCalendar.season(d(2026, 3, 28)), LiturgicalSeason.lent);
      expect(
        ChristianCalendar.season(d(2026, 3, 29)),
        LiturgicalSeason.holyWeek,
      );
      expect(
        ChristianCalendar.season(d(2026, 4, 5)),
        LiturgicalSeason.eastertide,
      );
      expect(
        ChristianCalendar.season(d(2026, 5, 24)),
        LiturgicalSeason.eastertide,
      );
      expect(
        ChristianCalendar.season(d(2026, 5, 25)),
        LiturgicalSeason.ordinary,
      );
      expect(
        ChristianCalendar.season(d(2026, 12, 10)),
        LiturgicalSeason.advent,
      );
      expect(
        ChristianCalendar.season(d(2026, 12, 26)),
        LiturgicalSeason.christmas,
      );
      expect(ChristianCalendar.seasonWeek(d(2026, 12, 10)), 2);
      expect(
        ChristianCalendar.seasonWeek(d(2026, 2, 22)),
        1,
      ); // first Sunday of Lent
      expect(ChristianCalendar.seasonWeek(d(2026, 2, 19)), isNull);
      expect(ChristianCalendar.fromEaster(d(2026, 4, 3)), -2); // Good Friday
      expect(
        ChristianCalendar.fromEaster(d(2026, 2, 18)),
        -46,
      ); // Ash Wednesday
    });
  });

  group('Moon', () {
    double apart(double a, double b) {
      final x = (a - b).abs() % 360;
      return x > 180 ? 360 - x : x;
    }

    // Reference instants (UTC): the new moon of the total eclipse of 8 Apr
    // 2024, and the full, first-quarter and new moons around it.
    final newMoon = DateTime.utc(2024, 4, 8, 18, 21);
    final firstQuarter = DateTime.utc(2024, 4, 15, 19, 13);
    final fullMoon = DateTime.utc(2024, 4, 23, 23, 49);

    test('elongation at the new, quarter and full moon', () {
      expect(apart(LunarCalendar.elongation(newMoon), 0), lessThan(.5));
      expect(apart(LunarCalendar.elongation(firstQuarter), 90), lessThan(.5));
      expect(apart(LunarCalendar.elongation(fullMoon), 180), lessThan(.5));
      expect(
        apart(LunarCalendar.elongation(DateTime.utc(2025, 1, 29, 12, 36)), 0),
        lessThan(.5),
      );
      expect(
        apart(LunarCalendar.elongation(DateTime.utc(2025, 3, 14, 6, 55)), 180),
        lessThan(.5),
      );
    });

    test('the tithi', () {
      expect(
        LunarCalendar.tithiAt(DateTime.utc(2024, 4, 9)),
        1,
      ); // a few hours after new
      expect(
        LunarCalendar.tithiAt(DateTime.utc(2024, 4, 8, 12, 21)),
        30,
      ); // just before
      expect(
        LunarCalendar.tithiAt(DateTime.utc(2024, 4, 23, 12)),
        15,
      ); // just before full
      expect(
        LunarCalendar.tithiAt(DateTime.utc(2024, 4, 24, 12)),
        16,
      ); // half a day after
      expect(LunarCalendar.tithiName(11), 'Shukla Ekadashi');
      expect(LunarCalendar.tithiName(26), 'Krishna Ekadashi');
      expect(LunarCalendar.tithiName(15), 'Purnima');
      expect(LunarCalendar.tithiName(30), 'Amavasya');
    });

    test('the civil day of a phase', () {
      DateTime civilOf(DateTime utc) {
        final l = utc.toLocal();
        return DateTime(l.year, l.month, l.day);
      }

      expect(LunarCalendar.phaseDay(civilOf(newMoon)), 0);
      expect(LunarCalendar.phaseDay(civilOf(firstQuarter)), 1);
      expect(LunarCalendar.phaseDay(civilOf(fullMoon)), 2);
      // A month has four, and most days have none.
      var phases = 0;
      for (var i = 0; i < 30; i++) {
        if (LunarCalendar.phaseDay(d(2026, 11, 1 + i)) != null) phases++;
      }
      expect(phases, inInclusiveRange(3, 5));
    });
  });
}
