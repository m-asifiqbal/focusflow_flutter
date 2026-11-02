/// ============================================================
/// BUDDHISM PRESETS — sitting, chanting, mala, nembutsu, daimoku
/// ============================================================
///
/// What: a morning and an evening sit (20 minutes), morning and evening
/// chanting or puja, refuge and precepts, mettā, walking meditation, sutra
/// reading and a weekly sangha sit for everyone; and each school's own: the
/// Tibetan mantra on a 108 mala and prostrations, the Pure Land nembutsu
/// (no goal), Nichiren's gongyo and daimoku, Zen's service. Durations are
/// short windows from a start time, the way people actually sit.
/// Why: from the research in docs/prayer_traditions.md (Abhayagiri, SFZC,
/// Plum Village, Access to Insight). Words avoid "prayer": the module says
/// practice, sitting and chanting. Uposatha days, the midday-fast days, the
/// lunar festivals and Vassa follow the moon and arrive with the calendar
/// rules.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/presets/preset_kit.dart';

List<PrayerPreset> buddhismPresets(PresetKit k) {
  final sun = k.sun, at = k.at, p = k.p;
  const chanters = {PrayerSchool.theravada, PrayerSchool.zen};
  return [
    p(
      tr('Morning sit'),
      PrayerKind.meditation,
      sun(SolarEvent.dawn, 5 * 60 + 30, 15),
      sun(SolarEvent.dawn, 5 * 60 + 50, 35),
      color: '10B981',
      hint: tr('20 minutes · zazen, calm or insight — your own way'),
    ),
    p(
      tr('Morning chanting'),
      PrayerKind.recitation,
      sun(SolarEvent.dawn, 6 * 60, 30),
      sun(SolarEvent.dawn, 6 * 60 + 15, 45),
      color: 'F59E0B',
      coreFor: {...chanters, PrayerSchool.nichiren},
      hint: tr('Puja or the morning service · 15 minutes'),
    ),
    p(
      tr('Evening chanting'),
      PrayerKind.recitation,
      sun(SolarEvent.sunset, 19 * 60, 60),
      sun(SolarEvent.sunset, 19 * 60 + 15, 75),
      color: 'F97316',
      coreFor: chanters,
      hint: tr('Puja or the evening service · 15 minutes'),
    ),
    p(
      tr('Evening sit'),
      PrayerKind.meditation,
      sun(SolarEvent.sunset, 18 * 60 + 30, 45),
      sun(SolarEvent.sunset, 18 * 60 + 50, 65),
      color: '6366F1',
      core: false,
      hint: tr('20 minutes · after the day\'s work'),
    ),
    p(
      tr('Refuge and precepts'),
      PrayerKind.recitation,
      sun(SolarEvent.dawn, 6 * 60, 20),
      sun(SolarEvent.dawn, 6 * 60 + 5, 25),
      color: 'EAB308',
      priority: PrayerPriority.low,
      remindBefore: null,
      core: false,
      schools: {PrayerSchool.theravada},
      hint: tr('The Three Refuges and the Five Precepts · 5 minutes'),
    ),
    p(
      tr('Metta (lovingkindness)'),
      PrayerKind.meditation,
      at(21),
      at(21, 15),
      color: '8B5CF6',
      priority: PrayerPriority.low,
      core: false,
      coreFor: {PrayerSchool.insight},
      hint: tr('10 to 15 minutes · wishing all beings well'),
    ),
    p(
      tr('Walking meditation'),
      PrayerKind.meditation,
      at(12, 30),
      at(12, 45),
      color: '14B8A6',
      priority: PrayerPriority.low,
      remindBefore: null,
      core: false,
      hint: tr('10 to 20 minutes · slow and mindful steps'),
    ),
    p(
      tr('Mantra on the mala'),
      PrayerKind.dhikr,
      at(6, 30),
      at(7),
      color: 'F59E0B',
      remindBefore: null,
      target: 108,
      core: false,
      coreFor: {PrayerSchool.tibetan},
      schools: {PrayerSchool.tibetan},
      hint: tr('Om Mani Padme Hum or your own · rounds of 108 beads'),
    ),
    p(
      tr('Prostrations'),
      PrayerKind.dhikr,
      at(6),
      at(6, 20),
      color: 'EF4444',
      remindBefore: null,
      target: 108,
      core: false,
      schools: {PrayerSchool.tibetan, PrayerSchool.zen},
      hint: tr('Bows to the Three Jewels · 3 or 108'),
    ),
    p(
      tr('Nembutsu'),
      PrayerKind.dhikr,
      at(7),
      at(7, 15),
      color: '0EA5E9',
      remindBefore: null,
      core: false,
      coreFor: {PrayerSchool.pureLand},
      schools: {PrayerSchool.pureLand},
      hint: tr('Namo Amituofo or Namu Amida Butsu · no count needed'),
    ),
    p(
      tr('Gongyo and daimoku'),
      PrayerKind.recitation,
      at(6, 30),
      at(7),
      color: 'F97316',
      core: false,
      coreFor: {PrayerSchool.nichiren},
      schools: {PrayerSchool.nichiren},
      hint: tr('Morning and evening · Nam-myoho-renge-kyo'),
    ),
    p(
      tr('Sutra or Dhamma reading'),
      PrayerKind.recitation,
      at(20, 30),
      at(20, 45),
      color: '10B981',
      priority: PrayerPriority.low,
      core: false,
      hint: tr('15 minutes · a sutra, a talk or a teaching'),
    ),
    p(
      tr('Sangha sit'),
      PrayerKind.service,
      at(10),
      at(11, 30),
      color: '14B8A6',
      remindBefore: 30,
      weekdays: PresetKit.sunday,
      place: tr('Meditation hall'),
      core: false,
      hint: tr('Sit and listen to a Dhamma talk together · weekly'),
    ),
    p(
      tr('Uposatha day'),
      PrayerKind.custom,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunset, 17 * 60 + 45),
      color: '14B8A6',
      remindBefore: 30,
      calendar: 'moon:0,1,2,3',
      core: false,
      coreFor: {PrayerSchool.theravada},
      hint: tr(
        'New, first-quarter, full and last-quarter moon · the eight precepts',
      ),
    ),
  ];
}
