/// The Prayer card's sky arc and place icons: day (sunrise → sunset) and
/// night (sunset → sunrise) halves, their four parts and the time left in
/// the current one, the plain 6 AM – 6 PM day without a location, and the
/// icon picked for a place (in English or as typed).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_sun_arc.dart';

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 1, h, m);
  // Dhaka.
  const dhaka = PrayerCalcSettings(
    location: GeoPoint(23.81, 90.41),
    method: PrayerCalcMethod.karachi,
  );
  SolarDay sunFor(DateTime d) => PrayerTimes.compute(dhaka, d);
  SolarDay? none(DateTime _) => null;
  final today = sunFor(at(0));
  const five = Duration(minutes: 5);

  group('day', () {
    test('four parts between sunrise and sunset', () {
      final p = SkyPath.of(sunFor, today.sunrise.add(five));
      expect(p.isDay, isTrue);
      expect(p.bounds.first, 0);
      expect(p.bounds.last, 1);
      for (var i = 1; i < p.bounds.length; i++) {
        expect(p.bounds[i], greaterThan(p.bounds[i - 1]));
      }
      expect(p.part, SkyPart.morning);
      expect(
        SkyPath.of(sunFor, today.noon.subtract(five)).part,
        SkyPart.lateMorning,
      );
      expect(SkyPath.of(sunFor, today.noon.add(five)).part, SkyPart.afternoon);
      final evening = SkyPath.of(sunFor, today.asr.add(five));
      expect(evening.part, SkyPart.evening);
      // Asr → sunset: the time left in this waqt.
      expect(evening.left, today.sunset.difference(today.asr.add(five)));
      expect(evening.from, today.sunrise);
      expect(evening.to, today.sunset);
    });

    test('without a location: a 6 AM – 6 PM day', () {
      final p = SkyPath.of(none, at(12));
      expect(p.now, closeTo(0.5, 1e-9));
      expect(p.part, SkyPart.afternoon);
      expect(SkyPath.of(none, at(9)).now, closeTo(0.25, 1e-9));
      // Noon → Asr 3:30 PM.
      expect(SkyPath.of(none, at(14)).left, const Duration(minutes: 90));
    });
  });

  group('night', () {
    test('after sunset: dusk, then night after nightfall (Isha)', () {
      final dusk = SkyPath.of(sunFor, today.sunset.add(five));
      expect(dusk.isDay, isFalse);
      expect(dusk.part, SkyPart.dusk);
      expect(dusk.from, today.sunset);
      expect(dusk.to, sunFor(DateTime(2026, 11, 2)).sunrise);
      expect(dusk.left, today.nightfall.difference(today.sunset.add(five)));
      expect(SkyPath.of(sunFor, today.nightfall.add(five)).part, SkyPart.night);
    });

    test('before sunrise: the night that began yesterday evening', () {
      final yesterday = sunFor(DateTime(2026, 10, 31));
      final p = SkyPath.of(sunFor, at(4));
      expect(p.isDay, isFalse);
      expect(p.from, yesterday.sunset);
      expect(p.to, today.sunrise);
      expect(p.part, anyOf(SkyPart.lateNight, SkyPart.beforeDawn));
      // Without a location: 6 PM – 6 AM, 4 AM is after 2 AM → before dawn.
      final plain = SkyPath.of(none, at(4));
      expect(plain.part, SkyPart.beforeDawn);
      expect(plain.left, const Duration(hours: 2));
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
