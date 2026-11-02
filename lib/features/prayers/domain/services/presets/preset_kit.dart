/// ============================================================
/// PRESET KIT — the preset type and the helpers every tradition uses
/// ============================================================
///
/// What: [PrayerPreset] (a suggested practice: the unsaved [Prayer], whether
/// it is ticked by default, which schools it is for, and a one-line hint
/// such as "2 rak'at · fard") and [PresetKit], which builds them: `p` makes
/// a preset of the kit's tradition, `sun` a sun-based time with its clock
/// fallback (used until a location is saved), `at` a clock time.
/// Why: the five traditions' catalogues (islam_presets.dart …) read like
/// lists of practices, not like constructor calls.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/prayers/domain/entities/calendar_rule.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// One suggested practice of a tradition.
@immutable
class PrayerPreset {
  const PrayerPreset(
    this.draft, {
    this.core = true,
    this.schools,
    this.coreFor,
    this.notFor,
    this.variant = false,
    this.hint = '',
  });

  /// The practice it adds (unsaved: empty id).
  final Prayer draft;

  /// Ticked by default (else an optional extra).
  final bool core;

  /// Only for these schools (null = everyone). A person who skipped the
  /// school question still sees them, as optional extras — unless the
  /// preset is a [variant].
  final Set<PrayerSchool>? schools;

  /// Ticked by default only for these schools (overrides [core] once a
  /// school is chosen).
  final Set<PrayerSchool>? coreFor;

  /// Left out for these schools (they have a variant of their own).
  final Set<PrayerSchool>? notFor;

  /// A school's own version of another preset (Jafari Maghrib): shown only
  /// once that school is chosen.
  final bool variant;

  /// A short note under the name ("2 rak'at · fard"), already translated.
  final String hint;

  PrayerPreset withCore(bool value) => PrayerPreset(
    draft,
    core: value,
    schools: schools,
    coreFor: coreFor,
    notFor: notFor,
    variant: variant,
    hint: hint,
  );
}

class PresetKit {
  const PresetKit(this.tradition, this.now, this.ramadan);

  final PrayerTradition tradition;
  final DateTime now;

  /// This year's Ramadan, or next year's once it is over.
  final (DateTime, DateTime) ramadan;

  /// Monday = bit 0 … Sunday = bit 6.
  static const int monday = 1;
  static const int tuesday = 1 << 1;
  static const int wednesday = 1 << 2;
  static const int thursday = 1 << 3;
  static const int friday = 1 << 4;
  static const int saturday = 1 << 5;
  static const int sunday = 1 << 6;
  static const int allDays = Prayer.everyDay;

  /// Every day but Saturday (Sun – Fri).
  static const int notSaturday = allDays & ~saturday;

  PrayerTimeRule sun(SolarEvent e, int fallback, [int offset = 0]) =>
      PrayerTimeRule.auto(e, offset: offset, minutes: fallback);

  PrayerTimeRule at(int h, [int m = 0]) => PrayerTimeRule.fixed(h * 60 + m);

  PrayerPreset p(
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
    String? calendar,
    int? target,
    String place = '',
    String hint = '',
    bool core = true,
    Set<PrayerSchool>? schools,
    Set<PrayerSchool>? coreFor,
    Set<PrayerSchool>? notFor,
    bool variant = false,
  }) => PrayerPreset(
    Prayer(
      id: '',
      name: name,
      kind: kind,
      tradition: tradition,
      start: start,
      end: end,
      weekdaysMask: weekdays,
      startDate: from,
      endDate: to,
      calendar: CalendarRule.parse(calendar),
      priority: priority,
      remindBefore: remindBefore,
      remindBeforeEnd: remindBeforeEnd,
      targetCount: target,
      colorHex: color,
      place: place,
      createdAt: now,
      updatedAt: now,
    ),
    core: core,
    schools: schools,
    coreFor: coreFor,
    notFor: notFor,
    variant: variant,
    hint: hint,
  );
}
