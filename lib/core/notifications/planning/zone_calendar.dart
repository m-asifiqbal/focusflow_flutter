/// ============================================================
/// ZONE CALENDAR — local wall times in one IANA time zone
/// ============================================================
///
/// What: converts between instants and *wall times* ("08:00 on Tue 14 Oct")
/// in a `package:timezone` [tz.Location] — the device zone, or the
/// override from Settings (`AppSettings.timeZone`).
///
/// Why: digests, habit check-ins and quiet hours are defined as wall times.
/// Adding `Duration(days: 1)` to an instant drifts by an hour across a DST
/// change, so every "same time tomorrow" is rebuilt from calendar fields.
/// Wall times that do not exist (the skipped hour of a spring-forward
/// night) resolve to the first valid instant after the gap; ambiguous ones
/// (the repeated hour in autumn) resolve to the first of the two.
///
/// Day markers are plain `DateTime(y, m, d)` values: only their calendar
/// fields matter (same convention as `DateUtilsX.dateOnly`).
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class ZoneCalendar {
  const ZoneCalendar(this.location);

  final tz.Location location;

  /// [instant] seen on a wall clock in [location].
  tz.TZDateTime wall(DateTime instant) => tz.TZDateTime.from(instant, location);

  /// Calendar day of [instant] in [location] (a `DateTime(y, m, d)` marker).
  DateTime dayOf(DateTime instant) {
    final w = wall(instant);
    return DateTime(w.year, w.month, w.day);
  }

  /// [DateUtilsX.dayNumber] of the calendar day of [instant] in [location]
  /// — [dayOf] without building a `DateTime` marker, for lookups keyed by
  /// day.
  int dayNumberOf(DateTime instant) {
    final w = wall(instant);
    return DateUtilsX.daysFromCivil(w.year, w.month, w.day);
  }

  /// Minutes after midnight of [instant] on the wall clock (0…1439).
  int minuteOfDay(DateTime instant) {
    final w = wall(instant);
    return w.hour * 60 + w.minute;
  }

  /// The instant of wall time [minutes] after midnight on [day].
  /// Returned as a plain [DateTime] instant (device-local representation).
  DateTime at(DateTime day, int minutes) {
    final m = minutes.clamp(0, 24 * 60 - 1);
    final t = tz.TZDateTime(
      location,
      day.year,
      day.month,
      day.day,
      m ~/ 60,
      m % 60,
    );
    return DateTime.fromMicrosecondsSinceEpoch(t.microsecondsSinceEpoch);
  }

  /// [day] moved by [days] calendar days (DST-safe).
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  /// `yyyy-MM-dd` key of a day marker (stable notification keys).
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
