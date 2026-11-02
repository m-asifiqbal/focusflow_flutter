/// ============================================================
/// PRAYER QUIET — Shabbat and Yom Tov without notifications
/// ============================================================
///
/// What: [PrayerQuiet.isQuiet] says whether an instant falls inside Shabbat
/// or a Yom Tov: from 18 minutes before sunset on the eve (the candle
/// lighting) to nightfall (42 minutes after sunset) when the day ends.
/// Consecutive holy days (Yom Tov into Shabbat) run on without a gap.
/// Why: an observant person does not use a phone then — a reminder would be
/// an intrusion, so the planner drops every Prayer notification inside it
/// (Settings › Prayer › Shabbat and Yom Tov). Without a saved location the
/// sun times fall back to 18:00 sunset.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/hebrew_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

abstract final class PrayerQuiet {
  /// Minutes before sunset the holy day begins.
  static const int candleLighting = 18;

  /// Minutes after sunset the holy day ends.
  static const int nightfall = 42;

  /// Whether [civil] is a holy day: Shabbat or Yom Tov.
  static bool isHolyDay(DateTime civil, {required bool inIsrael}) =>
      civil.weekday == DateTime.saturday ||
      HebrewCalendar.isYomTov(civil, inIsrael: inIsrael);

  /// Whether [t] is inside a Shabbat or Yom Tov. [sunFor] gives a day's sun
  /// times (null without a location).
  static bool isQuiet(
    DateTime t,
    SolarDay? Function(DateTime day) sunFor, {
    required bool inIsrael,
  }) {
    DateTime sunset(DateTime day) =>
        sunFor(day)?.at(SolarEvent.sunset) ??
        DateTime(day.year, day.month, day.day, 18);
    final today = DateUtilsX.dateOnly(t);
    // The holy day [c] runs from the eve's candle lighting to its own
    // nightfall; [t] can be in today's, or tomorrow's (the eve).
    for (final c in [today, DateUtilsX.addDays(today, 1)]) {
      if (!isHolyDay(c, inIsrael: inIsrael)) continue;
      final from = sunset(
        DateUtilsX.addDays(c, -1),
      ).subtract(const Duration(minutes: candleLighting));
      final to = sunset(c).add(const Duration(minutes: nightfall));
      if (!t.isBefore(from) && t.isBefore(to)) return true;
    }
    return false;
  }
}
