/// The sky's colours follow the day: bright blue at noon, deep blue at
/// night, warm at sunrise and sunset, stars only in the dark, the colour
/// glides (no jumps between two seconds), a plain day without a location;
/// and the moon's age and lit fraction.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_palette.dart';

void main() {
  const dhaka = PrayerCalcSettings(
    location: GeoPoint(23.81, 90.41),
    method: PrayerCalcMethod.karachi,
  );
  SolarDay sunFor(DateTime d) => PrayerTimes.compute(dhaka, d);
  SolarDay? none(DateTime _) => null;
  final day = sunFor(DateTime(2026, 11, 1));

  double luminance(Color c) => c.computeLuminance();
  const min = Duration(minutes: 1);

  test('noon is bright, midnight dark, with stars only at night', () {
    final noon = SkyPalette.at(day.noon, sunFor);
    final midnight = SkyPalette.at(day.midnight, sunFor);
    expect(luminance(noon.top), greaterThan(luminance(midnight.top) * 4));
    expect(noon.stars, 0);
    expect(midnight.stars, 1);
    expect(noon.cloudTintAlpha, 0);
    expect(midnight.cloudTintAlpha, greaterThan(.5));
    // The hills are the accent, darker at night.
    expect(midnight.hillFront, greaterThan(noon.hillFront));
  });

  test('sunrise and sunset are warm at the horizon', () {
    for (final t in [
      day.sunrise.add(const Duration(minutes: 9)),
      day.sunset.subtract(const Duration(minutes: 3)),
    ]) {
      final c = SkyPalette.at(t, sunFor).horizon;
      expect(c.r, greaterThan(c.b), reason: '$t');
    }
  });

  test('stars come out after nightfall and are gone by mid morning', () {
    expect(SkyPalette.at(day.sunset, sunFor).stars, lessThan(.3));
    expect(SkyPalette.at(day.nightfall, sunFor).stars, greaterThan(.8));
    expect(
      SkyPalette.at(day.sunrise.add(const Duration(hours: 2)), sunFor).stars,
      0,
    );
  });

  test('the colour glides: neighbouring minutes barely differ', () {
    var t = day.sunrise.subtract(const Duration(hours: 3));
    var prev = SkyPalette.at(t, sunFor);
    for (var i = 0; i < 24 * 60; i++) {
      t = t.add(min);
      final c = SkyPalette.at(t, sunFor);
      for (final (a, b) in [
        (prev.top, c.top),
        (prev.mid, c.mid),
        (prev.horizon, c.horizon),
      ]) {
        expect(
          (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs(),
          lessThan(.12),
          reason: '$t',
        );
      }
      expect((prev.stars - c.stars).abs(), lessThan(.08), reason: '$t');
      prev = c;
    }
  });

  test('without a location the day runs 6 AM to 6 PM', () {
    final noon = SkyPalette.at(DateTime(2026, 11, 1, 12), none);
    final night = SkyPalette.at(DateTime(2026, 11, 1, 23), none);
    expect(noon.stars, 0);
    expect(night.stars, greaterThan(.8));
    expect(luminance(noon.top), greaterThan(luminance(night.top)));
  });

  group('moon', () {
    test('age and lit fraction through a month', () {
      // New moon 2026-11-09 12:02 UTC, full moon 2026-11-24 14:53 UTC.
      final newMoon = SkyMoon.age(DateTime.utc(2026, 11, 9, 12));
      expect(newMoon < 1.2 || newMoon > SkyMoon.synodic - 1.2, isTrue);
      final full = SkyMoon.age(DateTime.utc(2026, 11, 24, 15));
      expect((full - SkyMoon.synodic / 2).abs(), lessThan(1.2));
      expect(SkyMoon.lit(0), closeTo(0, 1e-9));
      expect(SkyMoon.lit(SkyMoon.synodic / 2), closeTo(1, 1e-9));
      expect(SkyMoon.lit(SkyMoon.synodic / 4), closeTo(.5, 1e-9));
    });
  });
}
