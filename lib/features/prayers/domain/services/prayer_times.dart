/// ============================================================
/// PRAYER TIMES — offline sun-based prayer times for any place and day
/// ============================================================
///
/// What: the classic astronomical prayer-time calculation (praytimes.org /
/// adhan): Julian day → sun declination + equation of time → the hour angle
/// at which the sun reaches a given altitude. It yields eight neutral
/// [SolarEvent]s (dawn, sunrise, solar noon, Asr, sunset, nightfall, the
/// middle of the night and the start of its last third) that a prayer of
/// any tradition can anchor to; Islamic methods only change the dawn and
/// nightfall angles ([PrayerCalcMethod]).
/// Why offline: the sun needs nothing but the date and the coordinates, and
/// the app has no network dependency (CLAUDE.md rule 1).
/// Accuracy: about ±1 minute against published tables (standard 0.833°
/// refraction + sun radius at the horizon; elevation is ignored).
/// High latitudes: where the sun never gets deep enough for dawn/nightfall
/// the [HighLatitudeRule] limits them to a share of the night, and where it
/// never rises or sets at all the day is computed at the nearest latitude
/// where it does (65°) — every [SolarDay] field is always a real time.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/services/world_cities.dart';

/// A place on Earth in decimal degrees.
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  /// −90 (south pole) … 90 (north pole).
  final double latitude;

  /// −180 (west) … 180 (east).
  final double longitude;

  /// Great-circle distance to [other] in km (haversine, mean Earth radius).
  double distanceKm(GeoPoint other) {
    final sLat = math.sin(_rad(other.latitude - latitude) / 2);
    final sLng = math.sin(_rad(other.longitude - longitude) / 2);
    final a =
        sLat * sLat +
        math.cos(_rad(latitude)) * math.cos(_rad(other.latitude)) * sLng * sLng;
    return 2 * 6371.0088 * math.asin(math.min(1, math.sqrt(a)));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// The published conventions for the depth of the sun at dawn (Fajr) and
/// nightfall (Isha). Persist by [name] — the names are stable.
enum PrayerCalcMethod {
  muslimWorldLeague(fajrAngle: 18, ishaAngle: 17),
  isna(fajrAngle: 15, ishaAngle: 15),
  egypt(fajrAngle: 19.5, ishaAngle: 17.5),
  ummAlQura(fajrAngle: 18.5, ishaMinutes: 90),
  karachi(fajrAngle: 18, ishaAngle: 18),
  dubai(fajrAngle: 18.2, ishaAngle: 18.2),
  kuwait(fajrAngle: 18, ishaAngle: 17.5),
  qatar(fajrAngle: 18, ishaMinutes: 90),
  singapore(fajrAngle: 20, ishaAngle: 18),
  turkey(fajrAngle: 18, ishaAngle: 17),
  tehran(fajrAngle: 17.7, ishaAngle: 14, maghribAngle: 4.5);

  const PrayerCalcMethod({
    required this.fajrAngle,
    this.ishaAngle,
    this.ishaMinutes,
    this.maghribAngle,
  });

  /// Degrees below the horizon at dawn.
  final double fajrAngle;

  /// Degrees below the horizon at nightfall, or null when [ishaMinutes] is
  /// used instead.
  final double? ishaAngle;

  /// Nightfall as fixed minutes after sunset (Umm al-Qura, Qatar).
  final int? ishaMinutes;

  /// Degrees below the horizon at Maghrib (Tehran); null = at sunset.
  final double? maghribAngle;

  String get label => switch (this) {
    muslimWorldLeague => tr('Muslim World League'),
    isna => tr('ISNA (North America)'),
    egypt => tr('Egyptian General Authority'),
    ummAlQura => tr('Umm al-Qura, Makkah'),
    karachi => tr('University of Islamic Sciences, Karachi'),
    dubai => tr('Dubai'),
    kuwait => tr('Kuwait'),
    qatar => tr('Qatar'),
    singapore => tr('Singapore (MUIS)'),
    turkey => tr('Turkey (Diyanet)'),
    tehran => tr('Tehran (Institute of Geophysics)'),
  };

  /// A sensible default for [p] — only a starting suggestion the user can
  /// change. Rough by design: it takes the country of the nearest city in
  /// the offline list ([WorldCities], within 1000 km; open sea and remote
  /// land → Muslim World League). That follows borders better than lat/lng
  /// boxes (e.g. the Iranian vs the Arabian side of the Gulf).
  static PrayerCalcMethod suggestedFor(GeoPoint p) {
    final near = WorldCities.nearest(p, maxKm: 1000);
    return switch (near?.city.country) {
      'Pakistan' || 'India' || 'Bangladesh' || 'Afghanistan' => karachi,
      'Saudi Arabia' || 'Yemen' || 'Oman' => ummAlQura,
      'United Arab Emirates' => dubai,
      'Kuwait' => kuwait,
      'Qatar' || 'Bahrain' => qatar,
      'Egypt' || 'Sudan' || 'Libya' || 'Syria' || 'Lebanon' => egypt,
      'Iraq' || 'Jordan' || 'Palestine' => egypt,
      'Iran' => tehran,
      'Turkey' => turkey,
      'Malaysia' || 'Singapore' || 'Indonesia' || 'Brunei' => singapore,
      'United States' || 'Canada' || 'Mexico' => isna,
      _ => muslimWorldLeague,
    };
  }
}

/// When is an object's shadow long enough for Asr?
enum AsrSchool {
  /// Shadow = object + its noon shadow (Shafi'i, Maliki, Hanbali).
  standard(1),

  /// Shadow = twice the object + its noon shadow.
  hanafi(2);

  const AsrSchool(this.shadowFactor);

  /// How many object lengths the shadow grows by after noon.
  final int shadowFactor;

  String get label => switch (this) {
    standard => tr('Standard: Shafii, Maliki, Hanbali'),
    hanafi => tr('Hanafi'),
  };
}

/// How dawn and nightfall are placed where the sun stays too high for the
/// method's angles (summer above ~48°). "Night" is sunset → next sunrise.
enum HighLatitudeRule {
  /// Use the angles as they are; only an unreachable angle falls back to the
  /// middle of the night.
  none,

  /// Dawn/nightfall no further from sunrise/sunset than half the night.
  middleOfNight,

  /// … than a seventh of the night.
  seventhOfNight,

  /// … than angle/60 of the night (18° → 18/60). The usual default.
  angleBased;

  String get label => switch (this) {
    none => tr('None'),
    middleOfNight => tr('Middle of the night'),
    seventhOfNight => tr('One seventh of the night'),
    angleBased => tr('Angle-based'),
  };
}

/// Sun-based moments any tradition can anchor to.
enum SolarEvent {
  /// Fajr: the sun at −fajrAngle before sunrise.
  dawn,
  sunrise,

  /// Dhuhr: the sun crosses the meridian.
  noon,
  asr,

  /// Maghrib: sunset (or the method's Maghrib angle, Tehran).
  sunset,

  /// Isha: the sun at −ishaAngle, or sunset + the method's minutes.
  nightfall,

  /// Halfway from this day's sunset to the next sunrise (usually after the
  /// clock's midnight, i.e. on the next calendar day).
  midnight,

  /// Two thirds of the way from this day's sunset to the next dawn — the
  /// night *after* this day, so normally early on the next calendar day.
  lastThird;

  String get label => switch (this) {
    dawn => tr('Dawn (Fajr)'),
    sunrise => tr('Sunrise'),
    noon => tr('Solar noon (Dhuhr)'),
    asr => tr('Afternoon (Asr)'),
    sunset => tr('Sunset (Maghrib)'),
    nightfall => tr('Nightfall (Isha)'),
    midnight => tr('Midnight'),
    lastThird => tr('Last third of the night'),
  };
}

/// Everything the calculation needs besides the date.
@immutable
class PrayerCalcSettings {
  const PrayerCalcSettings({
    required this.location,
    this.method = PrayerCalcMethod.muslimWorldLeague,
    this.asrSchool = AsrSchool.standard,
    this.highLatitudeRule = HighLatitudeRule.angleBased,
  });

  final GeoPoint location;
  final PrayerCalcMethod method;
  final AsrSchool asrSchool;
  final HighLatitudeRule highLatitudeRule;

  PrayerCalcSettings copyWith({
    GeoPoint? location,
    PrayerCalcMethod? method,
    AsrSchool? asrSchool,
    HighLatitudeRule? highLatitudeRule,
  }) => PrayerCalcSettings(
    location: location ?? this.location,
    method: method ?? this.method,
    asrSchool: asrSchool ?? this.asrSchool,
    highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
  );

  @override
  bool operator ==(Object other) =>
      other is PrayerCalcSettings &&
      other.location == location &&
      other.method == method &&
      other.asrSchool == asrSchool &&
      other.highLatitudeRule == highLatitudeRule;

  @override
  int get hashCode =>
      Object.hash(location, method, asrSchool, highLatitudeRule);
}

/// The eight moments of one solar day, as local times on whole minutes.
/// Dawn … nightfall belong to the day itself; [midnight] and [lastThird]
/// to the night after it.
@immutable
class SolarDay {
  const SolarDay({
    required this.dawn,
    required this.sunrise,
    required this.noon,
    required this.asr,
    required this.sunset,
    required this.nightfall,
    required this.midnight,
    required this.lastThird,
  });

  final DateTime dawn;
  final DateTime sunrise;
  final DateTime noon;
  final DateTime asr;
  final DateTime sunset;
  final DateTime nightfall;
  final DateTime midnight;
  final DateTime lastThird;

  /// The moment of [e].
  DateTime at(SolarEvent e) => switch (e) {
    SolarEvent.dawn => dawn,
    SolarEvent.sunrise => sunrise,
    SolarEvent.noon => noon,
    SolarEvent.asr => asr,
    SolarEvent.sunset => sunset,
    SolarEvent.nightfall => nightfall,
    SolarEvent.midnight => midnight,
    SolarEvent.lastThird => lastThird,
  };

  @override
  bool operator ==(Object other) =>
      other is SolarDay && SolarEvent.values.every((e) => other.at(e) == at(e));

  @override
  int get hashCode => Object.hashAll(SolarEvent.values.map(at));

  @override
  String toString() =>
      'SolarDay(${SolarEvent.values.map((e) => '${e.name} ${at(e)}').join(', ')})';
}

/// The calculator. Pure and cheap (three days of sun positions per call).
abstract final class PrayerTimes {
  /// The moments for the local calendar day [day] (only y/m/d are used) at
  /// `settings.location`: the solar day whose noon falls on that local date.
  static SolarDay compute(PrayerCalcSettings settings, DateTime day) {
    final loc = settings.location;
    final lat = loc.latitude.isFinite ? loc.latitude.clamp(-90.0, 90.0) : 0.0;
    final lng = loc.longitude.isFinite
        ? (loc.longitude + 180) % 360 - 180
        : 0.0;
    final date = _utcDateFor(day, lng);
    final prev = _Raw.of(settings, date.subtract(_oneDay), lat, lng);
    final today = _Raw.of(settings, date, lat, lng);
    final next = _Raw.of(settings, date.add(_oneDay), lat, lng);

    // All hours below are UTC hours from 0h UTC of [date].
    final m = settings.method;
    final rule = settings.highLatitudeRule;
    final sunset = today.sunset;
    final nightBefore = today.sunrise - (prev.sunset - 24);
    final nightAfter = next.sunrise + 24 - sunset;

    double dawnOf(_Raw r, double night) =>
        _limit(r.fajr, r.sunrise, -_portion(rule, m.fajrAngle) * night, rule);
    final dawn = dawnOf(today, nightBefore);
    final nextDawn = 24 + dawnOf(next, nightAfter);

    final maghribAngle = m.maghribAngle;
    final maghrib = maghribAngle == null
        ? sunset
        : _limit(
            today.maghrib,
            sunset,
            _portion(rule, maghribAngle) * nightAfter,
            rule,
          );
    final ishaAngle = m.ishaAngle;
    final nightfall = ishaAngle == null
        // Fixed minutes, but never past the middle of a very short night.
        ? math.min(
            maghrib + (m.ishaMinutes ?? 90) / 60,
            sunset + nightAfter / 2,
          )
        : _limit(
            today.isha,
            sunset,
            _portion(rule, ishaAngle) * nightAfter,
            rule,
          );

    DateTime at(double hours) =>
        date.add(Duration(minutes: (hours * 60).round())).toLocal();
    return SolarDay(
      dawn: at(dawn),
      sunrise: at(today.sunrise),
      noon: at(today.noon),
      asr: at(today.asr),
      sunset: at(maghrib),
      nightfall: at(math.max(nightfall, maghrib)),
      midnight: at(sunset + nightAfter / 2),
      lastThird: at(sunset + (nextDawn - sunset) * 2 / 3),
    );
  }

  static const _oneDay = Duration(days: 1);

  /// The UTC date whose solar noon at [lng] falls on the local date of
  /// [day]. Usually the same y/m/d; differs by a day where the clock is far
  /// from solar time (Samoa, Kiribati) or the device is in another zone.
  static DateTime _utcDateFor(DateTime day, double lng) {
    final want = DateTime.utc(day.year, day.month, day.day);
    var date = want;
    for (var i = 0; i < 2; i++) {
      final noon = date
          .add(Duration(minutes: ((12 - lng / 15) * 60).round()))
          .toLocal();
      final got = DateTime.utc(noon.year, noon.month, noon.day);
      final shift = got.difference(want).inDays;
      if (shift == 0) break;
      date = date.subtract(Duration(days: shift));
    }
    return date;
  }

  /// The share of the night allowed between dawn and sunrise (or sunset and
  /// nightfall) under [rule] for a method angle of [angle]°.
  static double _portion(HighLatitudeRule rule, double angle) => switch (rule) {
    HighLatitudeRule.none || HighLatitudeRule.middleOfNight => 1 / 2,
    HighLatitudeRule.seventhOfNight => 1 / 7,
    HighLatitudeRule.angleBased => angle / 60,
  };

  /// [raw] limited to [base] + [offset] hours (offset < 0: an event before
  /// [base]); also the value when [raw] is unreachable (NaN). Rule `none`
  /// keeps any reachable [raw].
  static double _limit(
    double raw,
    double base,
    double offset,
    HighLatitudeRule rule,
  ) {
    final limit = base + offset;
    if (!raw.isFinite) return limit;
    if (rule == HighLatitudeRule.none) return raw;
    return offset < 0 ? math.max(raw, limit) : math.min(raw, limit);
  }
}

/// One day's unadjusted events in UTC hours from 0h UTC of its date (NaN
/// where the sun never reaches the angle).
class _Raw {
  _Raw(this._t);

  final List<double> _t;
  double get fajr => _t[0];
  double get sunrise => _t[1];
  double get noon => _t[2];
  double get asr => _t[3];
  double get sunset => _t[4];
  double get maghrib => _t[5];
  double get isha => _t[6];

  /// Sunrise/sunset altitude: refraction + the sun's radius.
  static const _horizon = -0.833;

  /// Typical local solar hours of the seven events — the first guesses.
  static const _guess = [5.0, 6.0, 12.0, 13.0, 18.0, 18.0, 18.0];

  /// Polar fallback latitude: the sun rises and sets there every day.
  static const _maxLat = 65.0;

  static _Raw of(
    PrayerCalcSettings s,
    DateTime utcDate,
    double lat,
    double lng,
  ) {
    final r = _compute(s, utcDate, lat, lng);
    final ok = r.sunrise.isFinite && r.sunset.isFinite && r.asr.isFinite;
    if (ok || lat.abs() <= _maxLat) return r;
    // Midnight sun / polar night: use the nearest latitude where the sun
    // still rises and sets (the "nearest place" fallback).
    return _compute(s, utcDate, lat.sign * _maxLat, lng);
  }

  static _Raw _compute(
    PrayerCalcSettings s,
    DateTime utcDate,
    double lat,
    double lng,
  ) {
    final jd0 = utcDate.millisecondsSinceEpoch / 86400000 + 2440587.5;
    final lngH = lng / 15;
    final m = s.method;
    final guess = [for (final h in _guess) h - lngH];
    var t = guess;
    // Each pass re-evaluates the sun at the previous estimate; two passes
    // bring every event well inside a minute.
    for (var pass = 0; pass < 2; pass++) {
      double at(int i) => t[i].isFinite ? t[i] : guess[i];
      double event(int i, double altitude, {required bool before}) =>
          _event(jd0, at(i), lat, lngH, altitude, before: before);
      final maghrib = m.maghribAngle;
      final isha = m.ishaAngle;
      t = [
        event(0, -m.fajrAngle, before: true),
        event(1, _horizon, before: true),
        12 - lngH - _sun(jd0 + at(2) / 24).eqt,
        event(
          3,
          _asrAltitude(jd0 + at(3) / 24, lat, s.asrSchool),
          before: false,
        ),
        event(4, _horizon, before: false),
        maghrib == null ? double.nan : event(5, -maghrib, before: false),
        isha == null ? double.nan : event(6, -isha, before: false),
      ];
    }
    return _Raw(t);
  }

  /// UTC hour (from [jd0]) when the sun is at [altitude]° before (morning)
  /// or after (evening) its transit, evaluated near [t]; NaN if never.
  static double _event(
    double jd0,
    double t,
    double lat,
    double lngH,
    double altitude, {
    required bool before,
  }) {
    final sun = _sun(jd0 + t / 24);
    final noon = 12 - lngH - sun.eqt;
    final cosH =
        (_sin(altitude) - _sin(lat) * _sin(sun.decl)) /
        (_cos(lat) * _cos(sun.decl));
    if (!(cosH >= -1 && cosH <= 1)) return double.nan;
    final hours = _deg(math.acos(cosH)) / 15;
    return before ? noon - hours : noon + hours;
  }

  /// The sun's altitude when a shadow reaches the Asr length.
  static double _asrAltitude(double jd, double lat, AsrSchool school) {
    final decl = _sun(jd).decl;
    final noonShadow = math.tan(_rad((lat - decl).abs()));
    return _deg(math.atan(1 / (school.shadowFactor + noonShadow)));
  }

  /// Sun declination (°) and equation of time (hours) at Julian day [jd]
  /// (the USNO low-precision formulas praytimes.org uses).
  static ({double decl, double eqt}) _sun(double jd) {
    final d = jd - 2451545.0;
    final g = (357.529 + 0.98560028 * d) % 360;
    final q = (280.459 + 0.98564736 * d) % 360;
    final l = (q + 1.915 * _sin(g) + 0.020 * _sin(2 * g)) % 360;
    final e = 23.439 - 0.00000036 * d;
    final ra = (_deg(math.atan2(_cos(e) * _sin(l), _cos(l))) / 15) % 24;
    final eqt = (q / 15 - ra + 12) % 24 - 12;
    return (decl: _deg(math.asin(_sin(e) * _sin(l))), eqt: eqt);
  }
}

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;
double _sin(double deg) => math.sin(_rad(deg));
double _cos(double deg) => math.cos(_rad(deg));
