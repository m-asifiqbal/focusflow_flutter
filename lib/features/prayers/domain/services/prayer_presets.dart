/// ============================================================
/// PRAYER PRESETS — the starting sets of the "Set up Prayer" picker
/// ============================================================
///
/// What: for each [PrayerTradition] a list of [PrayerPreset]s — the core
/// prayers (ticked by default) and optional extras (unticked) — with names,
/// kinds, windows, reminders, priorities and colours. Islamic prayers and
/// fasts use sun-based windows (Fajr = dawn → sunrise …); the other
/// traditions use sun anchors where the practice is tied to the sun
/// (Sandhya at sunrise / noon / sunset, Shacharit / Mincha / Maariv) and
/// fixed times otherwise. Every value stays editable afterwards.
/// Why: a good first day without typing — and the app never assumes one
/// faith: "Your own practice" starts empty. Each auto rule carries a
/// fallback clock time so a preset works before a location is saved, and
/// [PrayerPresets.manual] turns a set into fixed times ("Manual").
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// One suggested prayer of a tradition.
@immutable
class PrayerPreset {
  const PrayerPreset(this.draft, {this.core = true});

  /// The prayer it adds (unsaved: empty id).
  final Prayer draft;

  /// Ticked by default (else an optional extra).
  final bool core;
}

abstract final class PrayerPresets {
  /// Monday = bit 0 … Sunday = bit 6.
  static const int monday = 1;
  static const int thursday = 1 << 3;
  static const int friday = 1 << 4;
  static const int sunday = 1 << 6;

  /// The starting set of [tradition] at [now] (names in the active
  /// language).
  static List<PrayerPreset> of(PrayerTradition tradition, DateTime now) {
    Prayer p(
      String name,
      PrayerKind kind,
      PrayerTimeRule start,
      PrayerTimeRule? end, {
      String color = '10B981',
      PrayerPriority priority = PrayerPriority.normal,
      int? remindBefore = 0,
      int? remindBeforeEnd,
      int weekdays = Prayer.everyDay,
      DateTime? from,
      DateTime? to,
      int? target,
      String place = '',
    }) => Prayer(
      id: '',
      name: name,
      kind: kind,
      tradition: tradition,
      start: start,
      end: end,
      weekdaysMask: weekdays,
      startDate: from,
      endDate: to,
      priority: priority,
      remindBefore: remindBefore,
      remindBeforeEnd: remindBeforeEnd,
      targetCount: target,
      colorHex: color,
      place: place,
      createdAt: now,
      updatedAt: now,
    );

    PrayerTimeRule sun(SolarEvent e, int fallback, [int offset = 0]) =>
        PrayerTimeRule.auto(e, offset: offset, minutes: fallback);
    PrayerTimeRule at(int h, [int m = 0]) => PrayerTimeRule.fixed(h * 60 + m);
    // This year's Ramadan, or next year's once it is over.
    final ramadan = ramadanRange(now);

    return switch (tradition) {
      PrayerTradition.islam => [
        PrayerPreset(
          p(
            tr('Fajr'),
            PrayerKind.salah,
            sun(SolarEvent.dawn, 5 * 60),
            sun(SolarEvent.sunrise, 6 * 60 + 15),
            color: '3B82F6',
            priority: PrayerPriority.high,
            remindBeforeEnd: 20,
          ),
        ),
        PrayerPreset(
          p(
            tr('Dhuhr'),
            PrayerKind.salah,
            sun(SolarEvent.noon, 12 * 60 + 15),
            sun(SolarEvent.asr, 15 * 60 + 45),
            color: 'F59E0B',
            remindBeforeEnd: 20,
          ),
        ),
        PrayerPreset(
          p(
            tr('Asr'),
            PrayerKind.salah,
            sun(SolarEvent.asr, 15 * 60 + 45),
            sun(SolarEvent.sunset, 17 * 60 + 45),
            color: '10B981',
            remindBeforeEnd: 20,
          ),
        ),
        PrayerPreset(
          p(
            tr('Maghrib'),
            PrayerKind.salah,
            sun(SolarEvent.sunset, 17 * 60 + 45),
            sun(SolarEvent.nightfall, 19 * 60),
            color: 'F97316',
            remindBeforeEnd: 15,
          ),
        ),
        PrayerPreset(
          p(
            tr('Isha'),
            PrayerKind.salah,
            sun(SolarEvent.nightfall, 19 * 60),
            sun(SolarEvent.midnight, 23 * 60 + 45),
            color: '6366F1',
            remindBeforeEnd: 30,
          ),
        ),
        PrayerPreset(
          p(
            tr('Jumuah'),
            PrayerKind.salah,
            sun(SolarEvent.noon, 12 * 60 + 15),
            sun(SolarEvent.asr, 15 * 60 + 45),
            color: '0EA5E9',
            priority: PrayerPriority.high,
            remindBefore: 45,
            weekdays: friday,
            place: tr('Mosque'),
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Tahajjud'),
            PrayerKind.nafl,
            sun(SolarEvent.lastThird, 3 * 60 + 30),
            sun(SolarEvent.dawn, 5 * 60),
            color: '8B5CF6',
            priority: PrayerPriority.low,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Duha'),
            PrayerKind.nafl,
            sun(SolarEvent.sunrise, 6 * 60 + 35, 20),
            sun(SolarEvent.noon, 12 * 60 + 5, -10),
            color: 'EAB308',
            priority: PrayerPriority.low,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Morning adhkar'),
            PrayerKind.dhikr,
            sun(SolarEvent.dawn, 5 * 60),
            sun(SolarEvent.sunrise, 6 * 60 + 15),
            color: '14B8A6',
            priority: PrayerPriority.low,
            remindBefore: null,
            target: 100,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Evening adhkar'),
            PrayerKind.dhikr,
            sun(SolarEvent.asr, 15 * 60 + 45),
            sun(SolarEvent.sunset, 17 * 60 + 45),
            color: '14B8A6',
            priority: PrayerPriority.low,
            remindBefore: null,
            target: 100,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Monday and Thursday fast'),
            PrayerKind.fasting,
            sun(SolarEvent.dawn, 5 * 60),
            sun(SolarEvent.sunset, 17 * 60 + 45),
            color: 'D97706',
            remindBefore: 30,
            remindBeforeEnd: 0,
            weekdays: monday | thursday,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Ramadan fast'),
            PrayerKind.fasting,
            sun(SolarEvent.dawn, 5 * 60),
            sun(SolarEvent.sunset, 17 * 60 + 45),
            color: 'D97706',
            priority: PrayerPriority.high,
            remindBefore: 30,
            remindBeforeEnd: 0,
            from: ramadan.$1,
            to: ramadan.$2,
          ),
          core: false,
        ),
      ],
      PrayerTradition.christianity => [
        PrayerPreset(
          p(
            tr('Morning prayer'),
            PrayerKind.salah,
            at(6, 30),
            at(7),
            color: '3B82F6',
          ),
        ),
        PrayerPreset(
          p(
            tr('Midday prayer'),
            PrayerKind.salah,
            at(12),
            at(12, 15),
            color: 'F59E0B',
            priority: PrayerPriority.low,
          ),
        ),
        PrayerPreset(
          p(
            tr('Evening prayer'),
            PrayerKind.salah,
            at(18),
            at(18, 30),
            color: 'F97316',
          ),
        ),
        PrayerPreset(
          p(
            tr('Night prayer'),
            PrayerKind.salah,
            at(21, 30),
            at(22),
            color: '6366F1',
            priority: PrayerPriority.low,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Bible reading'),
            PrayerKind.recitation,
            at(20),
            at(20, 30),
            color: '10B981',
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Rosary'),
            PrayerKind.dhikr,
            at(19),
            at(19, 30),
            color: '8B5CF6',
            remindBefore: null,
            target: 50,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Sunday service'),
            PrayerKind.service,
            at(9),
            at(11),
            color: '0EA5E9',
            priority: PrayerPriority.high,
            remindBefore: 45,
            weekdays: sunday,
            place: tr('Church'),
          ),
          core: false,
        ),
      ],
      PrayerTradition.hinduism => [
        PrayerPreset(
          p(
            tr('Morning Sandhya'),
            PrayerKind.salah,
            sun(SolarEvent.sunrise, 5 * 60 + 45, -30),
            sun(SolarEvent.sunrise, 6 * 60 + 45, 30),
            color: 'F59E0B',
          ),
        ),
        PrayerPreset(
          p(
            tr('Midday Sandhya'),
            PrayerKind.salah,
            sun(SolarEvent.noon, 11 * 60 + 45, -15),
            sun(SolarEvent.noon, 12 * 60 + 15, 15),
            color: 'EAB308',
            priority: PrayerPriority.low,
          ),
        ),
        PrayerPreset(
          p(
            tr('Evening Sandhya'),
            PrayerKind.salah,
            sun(SolarEvent.sunset, 17 * 60 + 15, -30),
            sun(SolarEvent.sunset, 18 * 60, 15),
            color: 'F97316',
          ),
        ),
        PrayerPreset(
          p(
            tr('Puja'),
            PrayerKind.service,
            at(7),
            at(7, 30),
            color: 'EF4444',
            place: tr('Home'),
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Evening aarti'),
            PrayerKind.service,
            sun(SolarEvent.sunset, 17 * 60 + 45),
            sun(SolarEvent.sunset, 18 * 60 + 15, 30),
            color: 'F97316',
            place: tr('Home'),
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Japa'),
            PrayerKind.dhikr,
            at(6),
            at(6, 30),
            color: '8B5CF6',
            remindBefore: null,
            target: 108,
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Monday fast'),
            PrayerKind.fasting,
            sun(SolarEvent.sunrise, 6 * 60),
            sun(SolarEvent.sunset, 18 * 60),
            color: 'D97706',
            remindBefore: null,
            remindBeforeEnd: 0,
            weekdays: monday,
          ),
          core: false,
        ),
      ],
      PrayerTradition.buddhism => [
        PrayerPreset(
          p(
            tr('Morning chanting'),
            PrayerKind.recitation,
            at(6),
            at(6, 30),
            color: 'F59E0B',
          ),
        ),
        PrayerPreset(
          p(
            tr('Meditation'),
            PrayerKind.meditation,
            at(7),
            at(7, 20),
            color: '10B981',
          ),
        ),
        PrayerPreset(
          p(
            tr('Evening chanting'),
            PrayerKind.recitation,
            at(19),
            at(19, 30),
            color: 'F97316',
          ),
        ),
        PrayerPreset(
          p(
            tr('Loving-kindness meditation'),
            PrayerKind.meditation,
            at(21),
            at(21, 15),
            color: '8B5CF6',
            priority: PrayerPriority.low,
          ),
          core: false,
        ),
      ],
      PrayerTradition.judaism => [
        PrayerPreset(
          p(
            tr('Shacharit'),
            PrayerKind.salah,
            sun(SolarEvent.sunrise, 6 * 60),
            sun(SolarEvent.noon, 12 * 60),
            color: '3B82F6',
          ),
        ),
        PrayerPreset(
          p(
            tr('Mincha'),
            PrayerKind.salah,
            sun(SolarEvent.noon, 12 * 60 + 30, 30),
            sun(SolarEvent.sunset, 17 * 60 + 45),
            color: 'F59E0B',
          ),
        ),
        PrayerPreset(
          p(
            tr('Maariv'),
            PrayerKind.salah,
            sun(SolarEvent.nightfall, 19 * 60),
            sun(SolarEvent.midnight, 23 * 60 + 45),
            color: '6366F1',
          ),
        ),
        PrayerPreset(
          p(
            tr('Shabbat candle lighting'),
            PrayerKind.service,
            sun(SolarEvent.sunset, 17 * 60 + 27, -18),
            sun(SolarEvent.sunset, 17 * 60 + 45),
            color: 'EAB308',
            priority: PrayerPriority.high,
            remindBefore: 30,
            weekdays: friday,
            place: tr('Home'),
          ),
          core: false,
        ),
        PrayerPreset(
          p(
            tr('Torah study'),
            PrayerKind.recitation,
            at(20),
            at(21),
            color: '10B981',
          ),
          core: false,
        ),
      ],
      PrayerTradition.custom => const [],
    };
  }

  /// The Gregorian days of the next (or current) Ramadan from [now] — the
  /// tabular calendar's dates; the user can move them by a day in the
  /// editor to match local moon sighting.
  static (DateTime, DateTime) ramadanRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var year = HijriDate.fromGregorian(today).year;
    for (var i = 0; i < 2; i++, year++) {
      final from = HijriDate(year, 9, 1).toGregorian();
      final to = HijriDate(
        year,
        10,
        1,
      ).toGregorian().subtract(const Duration(days: 1));
      final last = DateTime(to.year, to.month, to.day);
      if (!last.isBefore(today)) {
        return (DateTime(from.year, from.month, from.day), last);
      }
    }
    final from = HijriDate(year, 9, 1).toGregorian();
    return (
      DateTime(from.year, from.month, from.day),
      DateTime(from.year, from.month, from.day + 29),
    );
  }

  /// [prayers] with every auto rule turned into its fixed fallback time
  /// ("I'll set the times myself").
  static List<Prayer> manual(List<Prayer> prayers) => [
    for (final p in prayers)
      p.copyWith(
        start: PrayerTimeRule.fixed(p.start.minutes),
        end: p.end == null ? null : PrayerTimeRule.fixed(p.end!.minutes),
      ),
  ];
}
