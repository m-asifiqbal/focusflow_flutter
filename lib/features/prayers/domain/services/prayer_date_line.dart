/// ============================================================
/// PRAYER DATE LINE — the date in the tradition's own calendar
/// ============================================================
///
/// What: [PrayerDateLine.of] gives the one line beside the date on the Prayer
/// page and Home: the Hijri date (Islam), the Hebrew date — rolled over at
/// sunset, as a Hebrew day begins then (Judaism), the liturgical season and
/// its week ("Lent · week 3", Christianity), the lunar day ("Shukla
/// Ekadashi", Hinduism) or the moon day on a new / quarter / full moon
/// (Buddhism). Null where there is nothing to say (a custom practice, an
/// ordinary week).
/// Why: each tradition keeps time differently; the date is half the
/// feel of the page. Pure, so it is tested without a widget.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/christian_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/hebrew_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/lunar_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';

abstract final class PrayerDateLine {
  /// The line for [tradition] at [now]; [sunset] (today's, or null without a
  /// location) moves the Hebrew date on in the evening.
  static String? of(
    PrayerTradition tradition,
    DateTime now, {
    DateTime? sunset,
    int hijriAdjust = 0,
  }) {
    final day = DateTime(now.year, now.month, now.day);
    switch (tradition) {
      case PrayerTradition.islam:
        return HijriDate.fromGregorian(day, adjustDays: hijriAdjust).format();
      case PrayerTradition.judaism:
        return HebrewCalendar.atTime(now, sunset).format();
      case PrayerTradition.christianity:
        return _season(day);
      case PrayerTradition.hinduism:
        return LunarCalendar.tithiName(LunarCalendar.tithiAt(now));
      case PrayerTradition.buddhism:
        final phase = LunarCalendar.phaseDay(day);
        return phase == null ? null : LunarCalendar.phaseName(phase);
      case PrayerTradition.custom:
        return null;
    }
  }

  static String? _season(DateTime day) {
    final season = ChristianCalendar.season(day);
    final week = ChristianCalendar.seasonWeek(day);
    final name = switch (season) {
      LiturgicalSeason.advent => tr('Advent'),
      LiturgicalSeason.christmas => tr('Christmastide'),
      LiturgicalSeason.lent => tr('Lent'),
      LiturgicalSeason.holyWeek => tr('Holy Week'),
      LiturgicalSeason.eastertide => tr('Eastertide'),
      LiturgicalSeason.ordinary => null,
    };
    if (name == null) return null;
    return week == null
        ? name
        : tr('{season} · week {n}', {'season': name, 'n': week});
  }
}
