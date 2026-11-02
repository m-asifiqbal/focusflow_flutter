/// ============================================================
/// CHRISTIAN CALENDAR — Easter, Lent, Advent and the Orthodox fasts
/// ============================================================
///
/// What: the date of Easter (the Western, Gregorian computus of Meeus /
/// Jones / Butcher) and of Orthodox Pascha (the Julian computus, shown in
/// Gregorian dates, valid 1900 – 2099); days counted from Easter (Ash
/// Wednesday −46, Palm Sunday −7, Good Friday −2, Ascension +39,
/// Pentecost +49); Advent (four Sundays before Christmas); and the liturgical
/// season of a day (Advent, Christmas, Lent, Holy Week, Eastertide,
/// ordinary time).
/// Why: exact and offline — the date of Easter is arithmetic. Fixed-date
/// fasts (the Nativity Fast 15 Nov – 24 Dec, the Dormition Fast 1 – 14 Aug of
/// the revised calendar) are plain month-day ranges in the rule model.
/// Western Lent counts 40 days *excluding Sundays*; Great Lent of the
/// Orthodox Church starts on Clean Monday, 48 days before Pascha.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';

enum LiturgicalSeason {
  advent,
  christmas,
  ordinary,
  lent,
  holyWeek,
  eastertide;

  String get label => switch (this) {
    advent => tr('Advent'),
    christmas => tr('Christmas season'),
    ordinary => tr('Ordinary time'),
    lent => tr('Lent'),
    holyWeek => tr('Holy Week'),
    eastertide => tr('Eastertide'),
  };
}

abstract final class ChristianCalendar {
  /// Easter Sunday of [year], Gregorian (Western churches).
  static DateTime easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    return DateTime(year, month, day);
  }

  /// Orthodox Pascha of [year], in Gregorian dates (1900 – 2099: the Julian
  /// date plus 13 days).
  static DateTime pascha(int year) {
    final a = year % 4;
    final b = year % 7;
    final c = year % 19;
    final d = (19 * c + 15) % 30;
    final e = (2 * a + 4 * b - d + 34) % 7;
    final month = (d + e + 114) ~/ 31;
    final day = (d + e + 114) % 31 + 1;
    return DateTime(year, month, day + 13);
  }

  /// First Sunday of Advent of [year]: the Sunday 21 days before the Sunday
  /// on or before 24 December.
  static DateTime advent(int year) {
    final eve = DateTime(year, 12, 24);
    final sundayBefore = eve.subtract(Duration(days: eve.weekday % 7));
    return sundayBefore.subtract(const Duration(days: 21));
  }

  /// [day] counted from Easter of its own year (negative before).
  static int fromEaster(DateTime day, {bool orthodox = false}) {
    final e = orthodox ? pascha(day.year) : easter(day.year);
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(e.year, e.month, e.day)).inDays;
  }

  /// The liturgical season of a Western [day].
  static LiturgicalSeason season(DateTime day) {
    final n = fromEaster(day);
    if (n >= -46 && n <= -8) return LiturgicalSeason.lent;
    if (n >= -7 && n <= -1) return LiturgicalSeason.holyWeek;
    if (n >= 0 && n <= 49) return LiturgicalSeason.eastertide;
    final d = DateTime(day.year, day.month, day.day);
    if (!d.isBefore(advent(day.year)) &&
        d.isBefore(DateTime(day.year, 12, 25))) {
      return LiturgicalSeason.advent;
    }
    // Christmas to the Baptism of the Lord, about the first Sunday after
    // Epiphany: kept simple as 25 Dec – 6 Jan.
    if ((day.month == 12 && day.day >= 25) ||
        (day.month == 1 && day.day <= 6)) {
      return LiturgicalSeason.christmas;
    }
    return LiturgicalSeason.ordinary;
  }

  /// The week (1-based) of Advent or Lent that [day] is in, null elsewhere.
  static int? seasonWeek(DateTime day) {
    switch (season(day)) {
      case LiturgicalSeason.advent:
        final start = advent(day.year);
        return DateTime.utc(day.year, day.month, day.day)
                    .difference(
                      DateTime.utc(start.year, start.month, start.day),
                    )
                    .inDays ~/
                7 +
            1;
      case LiturgicalSeason.lent:
        // The days after Ash Wednesday belong to no numbered week; the first
        // Sunday of Lent (−42) starts week 1 and Palm Sunday (−7) week 6.
        final n = fromEaster(day);
        return n < -42 ? null : (n + 42) ~/ 7 + 1;
      default:
        return null;
    }
  }
}
