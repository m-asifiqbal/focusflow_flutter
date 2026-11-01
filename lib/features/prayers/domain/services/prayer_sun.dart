/// ============================================================
/// PRAYER SUN — the saved prayer settings as sun times per day
/// ============================================================
///
/// What: turns [PrayerPrefs] (location, method, Asr school, high-latitude
/// rule — stored as names) into [PrayerCalcSettings], and gives a cached
/// "sun times of a day" function the schedule, planner and screens share.
/// Why: the calculation is cheap but runs for every prayer of every day in
/// a 14-day notification window; one memo per settings value keeps it to
/// one calculation per day. No location = null (rules use their fallback
/// times).
/// ============================================================
library;

import 'package:focusflow/core/settings/prayer_prefs.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

abstract final class PrayerSun {
  /// The calculation settings, or null without a saved location.
  static PrayerCalcSettings? settingsOf(PrayerPrefs prefs) {
    final lat = prefs.latitude;
    final lng = prefs.longitude;
    if (lat == null || lng == null) return null;
    final at = GeoPoint(lat, lng);
    return PrayerCalcSettings(
      location: at,
      method: methodOf(prefs),
      asrSchool:
          AsrSchool.values.asNameMap()[prefs.asrSchool] ?? AsrSchool.standard,
      highLatitudeRule:
          HighLatitudeRule.values.asNameMap()[prefs.highLatitudeRule] ??
          HighLatitudeRule.angleBased,
    );
  }

  /// The chosen method, else the one suggested for the location.
  static PrayerCalcMethod methodOf(PrayerPrefs prefs) {
    final chosen = PrayerCalcMethod.values.asNameMap()[prefs.method];
    if (chosen != null) return chosen;
    final lat = prefs.latitude;
    final lng = prefs.longitude;
    return lat == null || lng == null
        ? PrayerCalcMethod.muslimWorldLeague
        : PrayerCalcMethod.suggestedFor(GeoPoint(lat, lng));
  }

  /// A memoised "sun times of a day" for [prefs] (always null without a
  /// location).
  static SolarDay? Function(DateTime day) dayFn(PrayerPrefs prefs) {
    final settings = settingsOf(prefs);
    if (settings == null) return (_) => null;
    final cache = <String, SolarDay>{};
    return (day) => cache.putIfAbsent(
      DateUtilsX.dayKey(day),
      () => PrayerTimes.compute(settings, day),
    );
  }
}
