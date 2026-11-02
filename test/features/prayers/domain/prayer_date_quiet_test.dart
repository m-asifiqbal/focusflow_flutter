/// The per-tradition date line (Hijri, Hebrew with the sunset roll-over, the
/// liturgical season, the tithi, the moon day) and the Shabbat / Yom Tov
/// quiet windows, plus the calendar rules the presets now carry.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_date_line.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_quiet.dart';
import 'package:focusflow/features/prayers/domain/services/calendar_rules.dart';

void main() {
  group('date line', () {
    test('Islam: the Hijri date with the correction', () {
      final now = DateTime(2026, 11, 2, 12);
      expect(
        PrayerDateLine.of(PrayerTradition.islam, now, hijriAdjust: 1),
        HijriDate.fromGregorian(DateTime(2026, 11, 2), adjustDays: 1).format(),
      );
    });

    test('Judaism: the Hebrew day turns over at sunset', () {
      final sunset = DateTime(2026, 9, 11, 18);
      expect(
        PrayerDateLine.of(
          PrayerTradition.judaism,
          DateTime(2026, 9, 11, 12),
          sunset: sunset,
        ),
        '29 Elul 5786',
      );
      expect(
        PrayerDateLine.of(
          PrayerTradition.judaism,
          DateTime(2026, 9, 11, 19),
          sunset: sunset,
        ),
        '1 Tishrei 5787',
      );
    });

    test('Christianity: the season and its week', () {
      expect(
        PrayerDateLine.of(PrayerTradition.christianity, DateTime(2026, 3, 1)),
        'Lent · week 2',
      );
      expect(
        PrayerDateLine.of(PrayerTradition.christianity, DateTime(2026, 12, 10)),
        'Advent · week 2',
      );
      expect(
        PrayerDateLine.of(PrayerTradition.christianity, DateTime(2026, 7, 1)),
        isNull,
      );
    });

    test('Hinduism the tithi, Buddhism the phase day, custom nothing', () {
      expect(
        PrayerDateLine.of(PrayerTradition.hinduism, DateTime(2026, 11, 2, 12)),
        matches(RegExp(r'^(Shukla|Krishna) \w+$|^(Purnima|Amavasya)$')),
      );
      expect(
        PrayerDateLine.of(PrayerTradition.custom, DateTime(2026, 11, 2)),
        isNull,
      );
      var phases = 0;
      for (var i = 0; i < 30; i++) {
        final d = DateTime(2026, 11, 1 + i);
        if (PrayerDateLine.of(PrayerTradition.buddhism, d) != null) phases++;
      }
      expect(phases, inInclusiveRange(3, 5));
    });
  });

  group('Shabbat and Yom Tov quiet', () {
    bool quiet(DateTime t, {bool israel = false}) =>
        PrayerQuiet.isQuiet(t, (_) => null, inIsrael: israel);

    test('Shabbat runs from candle lighting to nightfall', () {
      // Saturday 7 Nov 2026; sunset falls back to 18:00 without a location.
      expect(quiet(DateTime(2026, 11, 6, 17, 30)), isFalse);
      expect(quiet(DateTime(2026, 11, 6, 17, 45)), isTrue);
      expect(quiet(DateTime(2026, 11, 7, 12)), isTrue);
      expect(quiet(DateTime(2026, 11, 7, 18, 41)), isTrue);
      expect(quiet(DateTime(2026, 11, 7, 18, 43)), isFalse);
      expect(quiet(DateTime(2026, 11, 4, 12)), isFalse);
    });

    test('Yom Tov runs into Shabbat; Israel keeps one day', () {
      // Pesach 2026: Thu 2 and Fri 3 Apr, then Shabbat (Diaspora).
      expect(quiet(DateTime(2026, 4, 2, 12)), isTrue);
      expect(quiet(DateTime(2026, 4, 3, 12)), isTrue);
      expect(quiet(DateTime(2026, 4, 3, 19)), isTrue);
      expect(quiet(DateTime(2026, 4, 4, 12)), isTrue);
      expect(quiet(DateTime(2026, 4, 3, 12), israel: true), isFalse);
      expect(quiet(DateTime(2026, 4, 2, 12), israel: true), isTrue);
    });
  });

  test('the presets repeat by calendar, not by stale date ranges', () {
    final now = DateTime(2026, 11, 2);
    for (final t in [
      PrayerTradition.islam,
      PrayerTradition.judaism,
      PrayerTradition.christianity,
      PrayerTradition.hinduism,
      PrayerTradition.buddhism,
    ]) {
      final presets = PrayerPresets.of(t, now);
      for (final p in presets) {
        final rule = p.draft.calendar;
        if (rule == null) continue;
        // Every rule parses to a name and finds a date within two years.
        expect(CalendarRules.describe(rule), isNotEmpty, reason: rule.key);
        expect(
          CalendarRules.nextDates(rule, now, count: 1),
          isNotEmpty,
          reason: '${p.draft.name} ${rule.key}',
        );
      }
    }
    final islam = PrayerPresets.of(PrayerTradition.islam, now);
    final ramadan = islam.firstWhere((p) => p.draft.name == 'Ramadan fast');
    expect(ramadan.draft.calendar?.key, 'hspan:9-1-30');
    expect(ramadan.draft.startDate, isNull);
  });
}
