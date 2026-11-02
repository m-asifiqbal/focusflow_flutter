/// ============================================================
/// HEBREW CALENDAR — dates, fast days, the Omer, Rosh Chodesh, Yom Tov
/// ============================================================
///
/// What: Gregorian ⇄ Hebrew date (the arithmetic calendar of Dershowitz &
/// Reingold, *Calendrical Calculations*, fixed days counted from 1 Jan 1
/// CE), the six fast days with their Shabbat shifts (Tzom Gedaliah and 17
/// Tammuz and Tisha B'Av move to Sunday, the Fast of Esther back to Thursday,
/// 10 Tevet and Yom Kippur never move), Rosh Chodesh, the days of the Omer,
/// Chanukah, and the days of Yom Tov (Diaspora or Israel).
/// Why: exact and offline — the Hebrew calendar is arithmetic, not
/// observation. A Hebrew day begins at the previous sunset: a civil date's
/// evening already belongs to the next Hebrew date ([HebrewCalendar.atTime]).
/// Numbers checked against Hebcal (Rosh Hashanah 5787 = 12 Sep 2026,
/// Pesach 5786 = 2 Apr 2026, 13 Adar II 5787 = 22 Mar 2027).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// A Hebrew date. [month] counts from Nisan (1) — Tishrei is 7, Adar 12 and
/// Adar II 13 (leap years only), the numbering of the arithmetic.
@immutable
class HebrewDate {
  const HebrewDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const int nisan = 1;
  static const int iyar = 2;
  static const int sivan = 3;
  static const int tammuz = 4;
  static const int av = 5;
  static const int elul = 6;
  static const int tishrei = 7;
  static const int cheshvan = 8;
  static const int kislev = 9;
  static const int tevet = 10;
  static const int shevat = 11;
  static const int adar = 12;
  static const int adarII = 13;

  bool get isLeapYear => HebrewCalendar.isLeapYear(year);

  /// "Cheshvan", "Adar II" …
  String get monthName => switch (month) {
    nisan => tr('Nisan'),
    iyar => tr('Iyar'),
    sivan => tr('Sivan'),
    tammuz => tr('Tammuz'),
    av => tr('Av'),
    elul => tr('Elul'),
    tishrei => tr('Tishrei'),
    cheshvan => tr('Cheshvan'),
    kislev => tr('Kislev'),
    tevet => tr('Tevet'),
    shevat => tr('Shevat'),
    adar => isLeapYear ? tr('Adar I') : tr('Adar'),
    _ => tr('Adar II'),
  };

  /// "13 Cheshvan 5787".
  String format() => '$day $monthName $year';

  @override
  bool operator ==(Object other) =>
      other is HebrewDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'HebrewDate($year-$month-$day)';
}

abstract final class HebrewCalendar {
  /// R.D. of 1 Tishrei of year 1 (7 Oct 3761 BCE, Julian).
  static const int _epoch = -1373427;

  static final DateTime _rd1 = DateTime.utc(1, 1, 1);

  // The month numbers, at hand.
  static const int nisan = HebrewDate.nisan;
  static const int iyar = HebrewDate.iyar;
  static const int sivan = HebrewDate.sivan;
  static const int tammuz = HebrewDate.tammuz;
  static const int av = HebrewDate.av;
  static const int elul = HebrewDate.elul;
  static const int tishrei = HebrewDate.tishrei;
  static const int cheshvan = HebrewDate.cheshvan;
  static const int kislev = HebrewDate.kislev;
  static const int tevet = HebrewDate.tevet;
  static const int shevat = HebrewDate.shevat;
  static const int adar = HebrewDate.adar;
  static const int adarII = HebrewDate.adarII;

  /// Fixed day number of a civil date (1 Jan 1 CE = 1).
  static int fixedFromCivil(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).difference(_rd1).inDays + 1;

  /// The civil date (local midnight) of a fixed day number.
  static DateTime civilFromFixed(int rd) {
    final d = _rd1.add(Duration(days: rd - 1));
    return DateTime(d.year, d.month, d.day);
  }

  static bool isLeapYear(int y) => (7 * y + 1) % 19 < 7;

  static int lastMonth(int y) => isLeapYear(y) ? 13 : 12;

  static int _elapsedDays(int y) {
    final months = ((235 * y - 234) / 19).floor();
    final parts = 12084 + 13753 * months;
    final days = 29 * months + (parts / 25920).floor();
    return (3 * (days + 1)) % 7 < 3 ? days + 1 : days;
  }

  static int _yearCorrection(int y) {
    final ny0 = _elapsedDays(y - 1);
    final ny1 = _elapsedDays(y);
    final ny2 = _elapsedDays(y + 1);
    if (ny2 - ny1 == 356) return 2;
    if (ny1 - ny0 == 382) return 1;
    return 0;
  }

  /// Fixed day of 1 Tishrei of [y] (Rosh Hashanah).
  static int newYear(int y) => _epoch + _elapsedDays(y) + _yearCorrection(y);

  static int daysInYear(int y) => newYear(y + 1) - newYear(y);

  /// Days of [month] in [year] (29 or 30).
  static int daysInMonth(int month, int year) {
    final len = daysInYear(year);
    final shortKislev = len == 353 || len == 383;
    final longCheshvan = len == 355 || len == 385;
    if (month == iyar ||
        month == tammuz ||
        month == elul ||
        month == tevet ||
        month == adarII) {
      return 29;
    }
    if (month == adar && !isLeapYear(year)) return 29;
    if (month == cheshvan && !longCheshvan) return 29;
    if (month == kislev && shortKislev) return 29;
    return 30;
  }

  /// Fixed day of a Hebrew date.
  static int fixedFromHebrew(HebrewDate d) {
    var days = newYear(d.year) + d.day - 1;
    if (d.month < tishrei) {
      for (var m = tishrei; m <= lastMonth(d.year); m++) {
        days += daysInMonth(m, d.year);
      }
      for (var m = nisan; m < d.month; m++) {
        days += daysInMonth(m, d.year);
      }
    } else {
      for (var m = tishrei; m < d.month; m++) {
        days += daysInMonth(m, d.year);
      }
    }
    return days;
  }

  static HebrewDate hebrewFromFixed(int rd) {
    var year = ((rd - _epoch) / (35975351 / 98496)).floor() + 1;
    while (newYear(year) > rd) {
      year--;
    }
    while (newYear(year + 1) <= rd) {
      year++;
    }
    var month = rd < fixedFromHebrew(HebrewDate(year, nisan, 1))
        ? tishrei
        : nisan;
    while (rd >
        fixedFromHebrew(HebrewDate(year, month, daysInMonth(month, year)))) {
      month++;
    }
    final day = rd - fixedFromHebrew(HebrewDate(year, month, 1)) + 1;
    return HebrewDate(year, month, day);
  }

  /// The Hebrew date of a civil [day] (its daytime).
  static HebrewDate fromCivil(DateTime day) =>
      hebrewFromFixed(fixedFromCivil(day));

  /// The civil date of a Hebrew date.
  static DateTime toCivil(HebrewDate d) => civilFromFixed(fixedFromHebrew(d));

  /// The Hebrew date at [now]: after [sunset] the next Hebrew day has begun.
  static HebrewDate atTime(DateTime now, DateTime? sunset) {
    final today = fromCivil(now);
    if (sunset == null || now.isBefore(sunset)) return today;
    return hebrewFromFixed(fixedFromCivil(now) + 1);
  }

  // ---- the days that matter to the Prayer module ---------------------

  /// The fast days (a Tzom Gedaliah …), by id.
  static const List<String> fastIds = [
    'gedaliah',
    'tevet',
    'esther',
    'tammuz',
    'tishabav',
    'yomkippur',
  ];

  /// The civil date of fast [id] in Hebrew year [year], Shabbat shifts
  /// applied.
  static DateTime fastDay(String id, int year) {
    final leap = lastMonth(year);
    final (month, day) = switch (id) {
      'gedaliah' => (tishrei, 3),
      'yomkippur' => (tishrei, 10),
      'tevet' => (tevet, 10),
      'esther' => (leap, 13),
      'tammuz' => (tammuz, 17),
      'tishabav' => (av, 9),
      _ => throw ArgumentError('fast $id'),
    };
    var date = toCivil(HebrewDate(year, month, day));
    if (date.weekday == DateTime.saturday) {
      date = switch (id) {
        // Postponed to Sunday.
        'gedaliah' ||
        'tammuz' ||
        'tishabav' => date.add(const Duration(days: 1)),
        // Brought back to Thursday.
        'esther' => date.subtract(const Duration(days: 2)),
        _ => date,
      };
    }
    return DateTime(date.year, date.month, date.day);
  }

  /// Whether [civil] is a day of fast [id].
  static bool isFast(String id, DateTime civil) {
    final y = fromCivil(civil).year;
    final d = DateTime(civil.year, civil.month, civil.day);
    // A date around the new year may belong to a neighbouring year's list.
    return [y, y + 1, y - 1].any((year) => fastDay(id, year) == d);
  }

  /// Rosh Chodesh: the 1st of a month (not Tishrei) and the 30th.
  static bool isRoshChodesh(DateTime civil) {
    final h = fromCivil(civil);
    return h.day == 30 || (h.day == 1 && h.month != tishrei);
  }

  /// The night of the Omer counted this evening (1 – 49), or null: the
  /// evening of 15 Nisan counts 1, the evening of 4 Sivan counts 49.
  static int? omerTonight(DateTime civil) {
    final y = fromCivil(civil).year;
    final first = fixedFromHebrew(HebrewDate(y, nisan, 15));
    final n = fixedFromCivil(civil) - first + 1;
    return n >= 1 && n <= 49 ? n : null;
  }

  /// The candle (1 – 8) to light this evening for Chanukah, or null: the
  /// evening of 24 Kislev lights the first.
  static int? chanukahTonight(DateTime civil) {
    final y = fromCivil(civil).year;
    final first = fixedFromHebrew(HebrewDate(y, kislev, 24));
    final n = fixedFromCivil(civil) - first + 1;
    return n >= 1 && n <= 8 ? n : null;
  }

  /// Yom Tov (work-forbidden festival days): Rosh Hashanah, Yom Kippur,
  /// Sukkot and Shemini Atzeret / Simchat Torah, Pesach, Shavuot. In the
  /// Diaspora most are two days.
  static bool isYomTov(DateTime civil, {required bool inIsrael}) {
    final h = fromCivil(civil);
    final days = switch (h.month) {
      tishrei =>
        inIsrael ? const {1, 2, 10, 15, 22} : const {1, 2, 10, 15, 16, 22, 23},
      nisan => inIsrael ? const {15, 21} : const {15, 16, 21, 22},
      sivan => inIsrael ? const {6} : const {6, 7},
      _ => const <int>{},
    };
    return days.contains(h.day);
  }
}
