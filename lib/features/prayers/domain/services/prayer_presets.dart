/// ============================================================
/// PRAYER PRESETS — the starting sets of the "Set up Prayer" picker
/// ============================================================
///
/// What: for each [PrayerTradition] a list of [PrayerPreset]s — the core
/// practices (ticked by default) and optional extras (unticked) — with
/// names, kinds, windows, reminders, priorities, colours and a hint, for
/// the tradition's own words (presets/islam_presets.dart …). Islamic
/// prayers and fasts use sun-based windows; Judaism uses zmanim, Hinduism
/// muhurta windows, Christianity and Buddhism mostly clock times with sun
/// options. Every value stays editable afterwards.
/// A [PrayerSchool] (Hanafi, Catholic, Reform, Smarta, Zen …) refines the
/// set: practices of other schools are left out, the school's own are
/// ticked, and a person who skipped the question sees every school's
/// practices as options.
/// Why: a good first day without typing — and the app never assumes one
/// faith: "Your own practice" starts empty. Each auto rule carries a
/// fallback clock time so a preset works before a location is saved, and
/// [PrayerPresets.manual] turns a set into fixed times ("Manual").
/// ============================================================
library;

import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';
import 'package:focusflow/features/prayers/domain/services/presets/buddhism_presets.dart';
import 'package:focusflow/features/prayers/domain/services/presets/christianity_presets.dart';
import 'package:focusflow/features/prayers/domain/services/presets/hinduism_presets.dart';
import 'package:focusflow/features/prayers/domain/services/presets/islam_presets.dart';
import 'package:focusflow/features/prayers/domain/services/presets/judaism_presets.dart';
import 'package:focusflow/features/prayers/domain/services/presets/preset_kit.dart';

export 'package:focusflow/features/prayers/domain/services/presets/preset_kit.dart'
    show PrayerPreset;

abstract final class PrayerPresets {
  /// Monday = bit 0 … Sunday = bit 6.
  static const int monday = PresetKit.monday;
  static const int thursday = PresetKit.thursday;
  static const int friday = PresetKit.friday;
  static const int sunday = PresetKit.sunday;

  /// The starting set of [tradition] at [now] (names in the active
  /// language), for [school] when one was chosen.
  static List<PrayerPreset> of(
    PrayerTradition tradition,
    DateTime now, {
    PrayerSchool? school,
  }) {
    final kit = PresetKit(tradition, now, ramadanRange(now));
    final all = switch (tradition) {
      PrayerTradition.islam => islamPresets(kit),
      PrayerTradition.christianity => christianityPresets(kit),
      PrayerTradition.hinduism => hinduismPresets(kit),
      PrayerTradition.buddhism => buddhismPresets(kit),
      PrayerTradition.judaism => judaismPresets(kit),
      PrayerTradition.custom => const <PrayerPreset>[],
    };
    final s = school?.tradition == tradition ? school : null;
    final out = <PrayerPreset>[];
    for (final r in all) {
      if (s == null) {
        // Skipped: every school's own practices are options, and a school's
        // variant of another preset stays out of the way.
        if (r.variant) continue;
        out.add(r.schools == null ? r : r.withCore(false));
      } else {
        if (r.schools != null && !r.schools!.contains(s)) continue;
        if (r.notFor?.contains(s) ?? false) continue;
        out.add(r.withCore(r.coreFor?.contains(s) ?? r.core));
      }
    }
    return out;
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
