/// ============================================================
/// HIJRI DATE — the tabular Islamic calendar, offline
/// ============================================================
///
/// What: converts Gregorian dates to and from the arithmetic ("tabular",
/// "Kuwaiti") Islamic calendar: 12 months alternating 30/29 days, a 30-year
/// cycle with 11 leap years (2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29) whose
/// last month has 30 days, epoch 1 Muharram 1 AH = Friday 16 July 622 CE
/// (Julian; JD 1948439.5). Valid from that epoch on.
/// Why tabular: it needs no tables or network and is never more than a day
/// or two from the moon-sighted calendar; [HijriDate.fromGregorian] takes
/// a user day adjustment (±3) for the local sighting.
/// Day math runs on integer Julian day numbers built from UTC dates, so
/// time zones and DST never shift a day.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// A day of the Islamic calendar.
@immutable
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  /// AH year (1 = the Hijra).
  final int year;

  /// 1 (Muharram) … 12 (Dhu al-Hijjah).
  final int month;

  /// 1 … 29/30.
  final int day;

  /// Julian day number of 1 Muharram 1 AH (the civil epoch).
  static const int _epoch = 1948440;

  /// Julian day number of 1970-01-01.
  static const int _unixEpoch = 2440588;

  /// The Hijri date of [date] (only its y/m/d count), shifted first by
  /// [adjustDays] Gregorian days (clamped to −3 … 3) for local moon
  /// sighting.
  static HijriDate fromGregorian(DateTime date, {int adjustDays = 0}) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final jdn =
        utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay +
        _unixEpoch +
        adjustDays.clamp(-3, 3);
    return _fromJdn(jdn);
  }

  /// The Gregorian date (local midnight) of this Hijri date, without any
  /// adjustment — the inverse of `fromGregorian(d)`.
  DateTime toGregorian() {
    final utc = DateTime.utc(1970).add(Duration(days: _jdn() - _unixEpoch));
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Whether [year] AH has 355 days (Dhu al-Hijjah has 30).
  static bool isLeapYear(int year) => (14 + 11 * year) % 30 < 11;

  /// Days in [month] of [year]: odd months 30, even 29, except a leap
  /// year's Dhu al-Hijjah (30).
  static int daysInMonth(int year, int month) =>
      month.isOdd || (month == 12 && isLeapYear(year)) ? 30 : 29;

  /// The month's name in the active language.
  String get monthName => hijriMonthName(month);

  /// "10 Jumada al-Ula 1448" — no "AH" suffix (the caller adds it if the
  /// context needs it).
  String format() => '$day $monthName $year';

  bool get isRamadan => month == 9;

  /// Julian day number of this date.
  int _jdn() => _jdnOf(year, month, day);

  static int _jdnOf(int year, int month, int day) =>
      _epoch -
      1 +
      (year - 1) * 354 +
      (3 + 11 * year) ~/ 30 + // leap days before [year]
      (59 * (month - 1) + 1) ~/ 2 + // = ceil(29.5 × (month − 1))
      day;

  static HijriDate _fromJdn(int jdn) {
    // Estimate the year from the mean year length, then correct it.
    var y = (30 * (jdn - _epoch) + 10646) ~/ 10631;
    if (y < 1) y = 1;
    while (y > 1 && jdn < _jdnOf(y, 1, 1)) {
      y--;
    }
    while (jdn >= _jdnOf(y + 1, 1, 1)) {
      y++;
    }
    var m = 12;
    while (m > 1 && jdn < _jdnOf(y, m, 1)) {
      m--;
    }
    return HijriDate(y, m, jdn - _jdnOf(y, m, 1) + 1);
  }

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      'HijriDate($year-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')})';
}

/// The name of Hijri [month] (1…12) in the active language; '' otherwise.
String hijriMonthName(int month) => switch (month) {
  1 => tr('Muharram'),
  2 => tr('Safar'),
  3 => tr('Rabi al-Awwal'),
  4 => tr('Rabi al-Thani'),
  5 => tr('Jumada al-Ula'),
  6 => tr('Jumada al-Akhirah'),
  7 => tr('Rajab'),
  8 => tr('Shaban'),
  9 => tr('Ramadan'),
  10 => tr('Shawwal'),
  11 => tr('Dhu al-Qadah'),
  12 => tr('Dhu al-Hijjah'),
  _ => '',
};
