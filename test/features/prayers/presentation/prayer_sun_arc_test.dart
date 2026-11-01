/// The hero's sun arc and place icons: where "now" sits on today's sun
/// path and which of the four parts of the day it is in (night before
/// sunrise / after sunset), the plain 6 AM – 6 PM day without a location,
/// and the icon picked for a place (in English or as typed).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_sun_arc.dart';

void main() {
  final day = DateTime(2026, 11, 1);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 1, h, m);
  // Dhaka, 1 Nov 2026 (approximate is enough here).
  final sun = PrayerTimes.compute(
    const PrayerCalcSettings(
      location: GeoPoint(23.81, 90.41),
      method: PrayerCalcMethod.karachi,
    ),
    day,
  );

  group('SunPath', () {
    test('four parts between sunrise and sunset', () {
      final p = SunPath.of(sun, sun.sunrise.add(const Duration(minutes: 5)));
      expect(p.bounds.first, 0);
      expect(p.bounds.last, 1);
      for (var i = 1; i < p.bounds.length; i++) {
        expect(p.bounds[i], greaterThan(p.bounds[i - 1]));
      }
      expect(p.part, SunPart.morning);
      expect(
        SunPath.of(sun, sun.noon.subtract(const Duration(minutes: 5))).part,
        SunPart.lateMorning,
      );
      expect(
        SunPath.of(sun, sun.noon.add(const Duration(minutes: 5))).part,
        SunPart.afternoon,
      );
      expect(
        SunPath.of(sun, sun.asr.add(const Duration(minutes: 5))).part,
        SunPart.evening,
      );
    });

    test('night before sunrise and after sunset', () {
      expect(SunPath.of(sun, at(4)).isDay, isFalse);
      expect(SunPath.of(sun, at(4)).part, isNull);
      expect(SunPath.of(sun, at(21)).isDay, isFalse);
    });

    test('time left in this part, and until sunrise at night', () {
      // No location: mid morning 9:00, noon, Asr 3:30 PM, sunset 6 PM.
      expect(
        SunPath.of(null, at(14)).left,
        const Duration(hours: 1, minutes: 30),
      );
      expect(SunPath.of(null, at(17, 15)).left, const Duration(minutes: 45));
      expect(SunPath.of(null, at(8)).left, const Duration(hours: 1));
      expect(SunPath.of(null, at(5)).left, const Duration(hours: 1));
      // After sunset: until tomorrow's sunrise.
      expect(SunPath.of(null, at(20)).left, const Duration(hours: 10));
    });

    test('without a location: a 6 AM – 6 PM day', () {
      final p = SunPath.of(null, at(12));
      expect(p.now, closeTo(0.5, 1e-9));
      expect(p.part, SunPart.afternoon);
      expect(SunPath.of(null, at(9)).now, closeTo(0.25, 1e-9));
    });
  });

  group('place icons', () {
    test('known places, typed variants, and a pin otherwise', () {
      IconData icon(String p, [PrayerTradition t = PrayerTradition.islam]) =>
          PrayerStyle.placeIcon(p, t);
      expect(icon('Home'), FontAwesomeIcons.house);
      expect(icon('Work'), FontAwesomeIcons.briefcase);
      expect(icon('Mosque'), FontAwesomeIcons.mosque);
      expect(icon('Baitul Mukarram masjid'), FontAwesomeIcons.mosque);
      expect(icon('St. Mary\'s Church'), FontAwesomeIcons.church);
      expect(icon('Synagogue'), FontAwesomeIcons.synagogue);
      expect(
        icon('Temple', PrayerTradition.hinduism),
        FontAwesomeIcons.gopuram,
      );
      expect(icon('Temple', PrayerTradition.buddhism), FontAwesomeIcons.vihara);
      expect(icon('Grandma\'s garden'), FontAwesomeIcons.locationDot);
    });
  });
}
