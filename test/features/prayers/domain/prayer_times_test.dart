/// PrayerTimes: event ordering for many places and seasons, Hanafi vs
/// standard Asr, physical reference values (compared in UTC, since the
/// device time zone of the test run is unknown), high-latitude and polar
/// fallbacks, the method suggestion and GeoPoint distance.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

const _dhaka = GeoPoint(23.8103, 90.4125);
const _makkah = GeoPoint(21.4225, 39.8262);
const _jakarta = GeoPoint(-6.2088, 106.8456);
const _newYork = GeoPoint(40.7128, -74.0060);
const _capeTown = GeoPoint(-33.9249, 18.4241);
const _tehran = GeoPoint(35.6892, 51.3890);
const _london = GeoPoint(51.5074, -0.1278);
const _oslo = GeoPoint(59.91, 10.75);
const _tromso = GeoPoint(69.65, 18.96);

SolarDay _day(
  GeoPoint p,
  DateTime d, {
  PrayerCalcMethod method = PrayerCalcMethod.muslimWorldLeague,
  AsrSchool asr = AsrSchool.standard,
  HighLatitudeRule rule = HighLatitudeRule.angleBased,
}) => PrayerTimes.compute(
  PrayerCalcSettings(
    location: p,
    method: method,
    asrSchool: asr,
    highLatitudeRule: rule,
  ),
  d,
);

DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// Asserts [t] is within [tol] minutes of [h]:[m] UTC (time of day only,
/// wrapping at midnight).
void _expectUtc(DateTime t, int h, int m, {int tol = 2, String what = ''}) {
  final u = t.toUtc();
  var diff = (u.hour * 60 + u.minute - (h * 60 + m)) % 1440;
  if (diff > 720) diff -= 1440;
  expect(diff.abs(), lessThanOrEqualTo(tol), reason: '$what: got $u');
}

/// Every field on a whole minute, and the order that holds everywhere:
/// dawn < sunrise < noon < asr < sunset ≤ nightfall ≤ midnight < next
/// sunrise, and sunset < lastThird < next dawn.
void _expectDayOrdered(SolarDay s, SolarDay next, String what) {
  for (final e in SolarEvent.values) {
    expect(s.at(e).second, 0, reason: '$what ${e.name}');
    expect(s.at(e).millisecond, 0, reason: '$what ${e.name}');
  }
  expect(s.dawn.isBefore(s.sunrise), isTrue, reason: '$what dawn');
  expect(s.sunrise.isBefore(s.noon), isTrue, reason: '$what sunrise');
  expect(s.noon.isBefore(s.asr), isTrue, reason: '$what noon');
  expect(s.asr.isBefore(s.sunset), isTrue, reason: '$what asr');
  expect(s.sunset.isAfter(s.nightfall), isFalse, reason: '$what sunset');
  expect(s.nightfall.isAfter(s.midnight), isFalse, reason: '$what isha');
  expect(s.midnight.isBefore(next.sunrise), isTrue, reason: '$what mid');
  expect(s.sunset.isBefore(s.lastThird), isTrue, reason: '$what third');
  expect(s.lastThird.isBefore(next.dawn), isTrue, reason: '$what third');
}

/// The full chain, which holds where nights are long enough (low and
/// middle latitudes): dawn < sunrise < noon < asr < sunset ≤ nightfall <
/// midnight < lastThird < next dawn. (In short summer nights the last
/// third of sunset → dawn starts before the middle of sunset → sunrise.)
void _expectFullChain(SolarDay s, SolarDay next, String what) {
  _expectDayOrdered(s, next, what);
  expect(s.nightfall.isBefore(s.midnight), isTrue, reason: '$what isha');
  expect(s.midnight.isBefore(s.lastThird), isTrue, reason: '$what mid');
}

void main() {
  final dates = [
    DateTime(2026, 1, 15),
    DateTime(2026, 3, 20),
    DateTime(2026, 6, 21),
    DateTime(2026, 9, 23),
    DateTime(2026, 12, 21),
  ];

  test('events are ordered for many places and seasons', () {
    final places = {
      'Dhaka': (_dhaka, PrayerCalcMethod.karachi),
      'Makkah': (_makkah, PrayerCalcMethod.ummAlQura),
      'Jakarta': (_jakarta, PrayerCalcMethod.singapore),
      'New York': (_newYork, PrayerCalcMethod.isna),
      'Cape Town': (_capeTown, PrayerCalcMethod.muslimWorldLeague),
      'Tehran': (_tehran, PrayerCalcMethod.tehran),
    };
    for (final MapEntry(key: name, value: (p, m)) in places.entries) {
      for (final d in dates) {
        for (final asr in AsrSchool.values) {
          final s = _day(p, d, method: m, asr: asr);
          final n = _day(p, _next(d), method: m, asr: asr);
          _expectFullChain(s, n, '$name $d ${asr.name}');
        }
      }
    }
  });

  test('London in winter and spring has the full chain too', () {
    for (final d in [DateTime(2026, 12, 21), DateTime(2026, 3, 20)]) {
      _expectFullChain(_day(_london, d), _day(_london, _next(d)), '$d');
    }
  });

  test('noon falls on the requested local day', () {
    const samoa = GeoPoint(-13.85, -171.75);
    for (final p in [_dhaka, _newYork, _london, samoa]) {
      for (final d in dates) {
        final noon = _day(p, d).noon;
        expect((noon.year, noon.month, noon.day), (d.year, d.month, d.day));
      }
    }
  });

  test('Hanafi Asr is later than standard Asr', () {
    for (final p in [_dhaka, _makkah, _london, _jakarta]) {
      for (final d in dates) {
        final std = _day(p, d).asr;
        final hanafi = _day(p, d, asr: AsrSchool.hanafi).asr;
        expect(hanafi.isAfter(std), isTrue, reason: '$p $d');
      }
    }
  });

  test('equator at the March equinox: 12-hour day around solar noon', () {
    final s = _day(const GeoPoint(0, 0), DateTime(2026, 3, 20));
    // Equation of time ≈ −7.5 min in late March → noon ≈ 12:07 UTC.
    _expectUtc(s.noon, 12, 7, what: 'noon');
    _expectUtc(s.sunrise, 6, 0, tol: 10, what: 'sunrise');
    // 12 h + refraction/sun radius at both ends (≈ 3.3 min each).
    final len = s.sunset.difference(s.sunrise).inMinutes;
    expect(len, inInclusiveRange(724, 730));
    final mid = s.sunrise.add(Duration(minutes: len ~/ 2));
    expect(mid.difference(s.noon).inMinutes.abs(), lessThanOrEqualTo(1));
  });

  test('solar noon follows the equation of time (±17 min)', () {
    // Extremes: ≈ +16.4 min around 3 Nov, ≈ −14.2 min around 11 Feb.
    const zero = GeoPoint(0, 0);
    _expectUtc(_day(zero, DateTime(2026, 11, 3)).noon, 11, 43);
    _expectUtc(_day(zero, DateTime(2026, 2, 11)).noon, 12, 14);
    for (final d in dates) {
      final u = _day(const GeoPoint(10, 45), d).noon.toUtc(); // 09:00 ± EqT
      final minutes = u.hour * 60 + u.minute;
      expect((minutes - 9 * 60).abs(), lessThanOrEqualTo(17), reason: '$d');
    }
  });

  test('London, 21 June: sunrise 03:43 and sunset 20:21 UTC', () {
    final s = _day(_london, DateTime(2026, 6, 21));
    _expectUtc(s.sunrise, 3, 43, tol: 3, what: 'sunrise');
    _expectUtc(s.sunset, 20, 21, tol: 3, what: 'sunset');
    _expectUtc(s.noon, 12, 2, what: 'noon');
  });

  test('Oslo midsummer: high-latitude rules give valid ordered times', () {
    final d = DateTime(2026, 6, 21);
    for (final rule in HighLatitudeRule.values) {
      final s = _day(_oslo, d, rule: rule);
      final n = _day(_oslo, _next(d), rule: rule);
      _expectDayOrdered(s, n, 'Oslo ${rule.name}');
      // Sunrise ≈ 03:54 CEST (01:54 UTC), sunset ≈ 22:44 CEST.
      _expectUtc(s.sunrise, 1, 54, tol: 3, what: 'sunrise');
      _expectUtc(s.sunset, 20, 44, tol: 3, what: 'sunset');
    }
    // 18°/17° are never reached: dawn and nightfall sit on the rule's
    // share of the night — "middle of the night" puts nightfall at midnight.
    final mid = _day(_oslo, d, rule: HighLatitudeRule.middleOfNight);
    final gap = mid.midnight.difference(mid.nightfall).inMinutes;
    expect(gap.abs(), lessThanOrEqualTo(1));
    final seventh = _day(_oslo, d, rule: HighLatitudeRule.seventhOfNight);
    final angle = _day(_oslo, d);
    expect(seventh.nightfall.isBefore(angle.nightfall), isTrue);
    expect(seventh.dawn.isAfter(angle.dawn), isTrue);
  });

  test('polar day and polar night still give valid times', () {
    for (final d in [DateTime(2026, 6, 21), DateTime(2026, 12, 21)]) {
      for (final rule in HighLatitudeRule.values) {
        final s = _day(_tromso, d, rule: rule);
        final n = _day(_tromso, _next(d), rule: rule);
        _expectDayOrdered(s, n, 'Tromsø $d ${rule.name}');
      }
    }
  });

  test('fixed-minute Isha is sunset + 90 min', () {
    final s = _day(
      _makkah,
      DateTime(2026, 11, 1),
      method: PrayerCalcMethod.ummAlQura,
    );
    expect(s.nightfall.difference(s.sunset).inMinutes, 90);
  });

  test('Tehran Maghrib (4.5°) is after the astronomical sunset', () {
    final d = DateTime(2026, 3, 20);
    final mwl = _day(_tehran, d);
    final tehran = _day(_tehran, d, method: PrayerCalcMethod.tehran);
    final delay = tehran.sunset.difference(mwl.sunset).inMinutes;
    expect(delay, inInclusiveRange(10, 30));
  });

  test('suggestedFor picks the regional method', () {
    PrayerCalcMethod at(double lat, double lng) =>
        PrayerCalcMethod.suggestedFor(GeoPoint(lat, lng));
    expect(at(23.81, 90.41), PrayerCalcMethod.karachi); // Dhaka
    expect(at(21.42, 39.83), PrayerCalcMethod.ummAlQura); // Makkah
    expect(at(40.71, -74.01), PrayerCalcMethod.isna); // New York
    expect(at(51.5074, -0.1278), PrayerCalcMethod.muslimWorldLeague);
    expect(at(-6.2, 106.85), PrayerCalcMethod.singapore); // Jakarta
    expect(at(25.2, 55.27), PrayerCalcMethod.dubai);
    expect(at(30.04, 31.24), PrayerCalcMethod.egypt); // Cairo
    expect(at(35.69, 51.39), PrayerCalcMethod.tehran);
    expect(at(41.01, 28.98), PrayerCalcMethod.turkey); // Istanbul
    expect(at(-30, -140), PrayerCalcMethod.muslimWorldLeague); // Pacific
  });

  test('every enum value has a label', () {
    final labels = [
      for (final v in PrayerCalcMethod.values) v.label,
      for (final v in AsrSchool.values) v.label,
      for (final v in HighLatitudeRule.values) v.label,
      for (final v in SolarEvent.values) v.label,
    ];
    expect(labels.every((l) => l.isNotEmpty), isTrue);
  });

  test('GeoPoint.distanceKm: Dhaka → Chattogram ≈ 216 km', () {
    const dhaka = GeoPoint(23.81, 90.41);
    expect(
      dhaka.distanceKm(const GeoPoint(22.3569, 91.7832)),
      closeTo(216, 10),
    );
    expect(dhaka.distanceKm(dhaka), 0);
    expect(const GeoPoint(1, 2), const GeoPoint(1, 2));
  });
}
