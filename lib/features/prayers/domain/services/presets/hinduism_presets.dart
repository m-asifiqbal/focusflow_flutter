/// ============================================================
/// HINDUISM PRESETS — puja, japa, aarti, sandhya and the weekday vratas
/// ============================================================
///
/// What: the home practice almost every household keeps — morning puja at
/// the home shrine, japa on a 108-bead mala, the evening lamp and aarti —
/// plus Brahma muhurta rising, the three sandhyas (Smarta, Vaishnava and
/// Arya Samaj families), the Hanuman Chalisa, Hare Krishna japa of 16
/// rounds (Gaudiya), a Gita or Ramayana path, bhajan and satsang, a temple
/// visit, seva and a weekday vrata. Times use muhurta windows worked out
/// from sunrise and sunset (Brahma muhurta 96 to 48 minutes before
/// sunrise; the sandhyas around sunrise, midday and sunset).
/// Why: from the research in docs/prayer_traditions.md (Drik Panchang's
/// muhurta definitions, HAF, Himalayan Academy, ISKCON). Hinduism is
/// plural, so a stream only chooses defaults; nothing is hidden. Ekadashi,
/// Pradosh, Sankashti, Purnima and Amavasya follow the lunar tithi and
/// arrive with the calendar rules.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/presets/preset_kit.dart';

List<PrayerPreset> hinduismPresets(PresetKit k) {
  final sun = k.sun, at = k.at, p = k.p;
  const sandhyaStreams = {
    PrayerSchool.smarta,
    PrayerSchool.vaishnava,
    PrayerSchool.aryaSamaj,
  };
  return [
    p(
      tr('Brahma muhurta rising'),
      PrayerKind.meditation,
      sun(SolarEvent.sunrise, 4 * 60 + 40, -96),
      sun(SolarEvent.sunrise, 5 * 60 + 25, -48),
      color: '8B5CF6',
      priority: PrayerPriority.low,
      remindBefore: null,
      core: false,
      hint: tr('The hour before dawn · 96 to 48 minutes before sunrise'),
    ),
    p(
      tr('Morning puja'),
      PrayerKind.service,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunrise, 6 * 60 + 45, 45),
      color: 'EF4444',
      place: tr('Home shrine'),
      hint: tr('Lamp, incense and offerings at the home shrine'),
    ),
    p(
      tr('Mala japa'),
      PrayerKind.dhikr,
      sun(SolarEvent.sunrise, 6 * 60 + 45, 45),
      sun(SolarEvent.sunrise, 7 * 60 + 15, 75),
      color: '8B5CF6',
      remindBefore: null,
      target: 108,
      hint: tr('One mala of 108 beads · your own mantra'),
    ),
    p(
      tr('Evening lamp and aarti'),
      PrayerKind.service,
      sun(SolarEvent.sunset, 17 * 60 + 35, -10),
      sun(SolarEvent.sunset, 18 * 60 + 15, 30),
      color: 'F97316',
      place: tr('Home shrine'),
      hint: tr('Light the lamp at dusk · aarti and bhajan'),
    ),
    p(
      tr('Sandhyavandanam (morning)'),
      PrayerKind.salah,
      sun(SolarEvent.sunrise, 5 * 60 + 15, -72),
      sun(SolarEvent.sunrise, 6 * 60 + 15, 15),
      color: 'F59E0B',
      core: false,
      coreFor: sandhyaStreams,
      schools: sandhyaStreams,
      hint: tr(
        'Pratah sandhya with the Gayatri · if your family tradition keeps it',
      ),
    ),
    p(
      tr('Sandhyavandanam (midday)'),
      PrayerKind.salah,
      sun(SolarEvent.noon, 11 * 60 + 50, -24),
      sun(SolarEvent.noon, 12 * 60 + 40, 24),
      color: 'EAB308',
      priority: PrayerPriority.low,
      core: false,
      schools: sandhyaStreams,
      hint: tr('Madhyahna sandhya · around the Abhijit window'),
    ),
    p(
      tr('Sandhyavandanam (evening)'),
      PrayerKind.salah,
      sun(SolarEvent.sunset, 17 * 60 + 35),
      sun(SolarEvent.sunset, 18 * 60 + 45, 72),
      color: 'F97316',
      core: false,
      coreFor: sandhyaStreams,
      schools: sandhyaStreams,
      hint: tr('Sayam sandhya · from sunset'),
    ),
    p(
      tr('Gita or Ramayana path'),
      PrayerKind.recitation,
      at(20),
      at(20, 30),
      color: '10B981',
      core: false,
      hint: tr('A chapter or a few verses each evening'),
    ),
    p(
      tr('Hanuman Chalisa'),
      PrayerKind.recitation,
      sun(SolarEvent.sunrise, 7 * 60, 60),
      sun(SolarEvent.sunrise, 7 * 60 + 20, 80),
      color: 'F97316',
      priority: PrayerPriority.low,
      weekdays: PresetKit.tuesday | PresetKit.saturday,
      core: false,
      hint: tr('Tuesday and Saturday · once, or 7, 11 or 21 times'),
    ),
    p(
      tr('Hare Krishna japa'),
      PrayerKind.dhikr,
      sun(SolarEvent.sunrise, 5 * 60 + 30, -60),
      sun(SolarEvent.sunrise, 7 * 60, 60),
      color: '0EA5E9',
      remindBefore: null,
      target: 16,
      core: false,
      coreFor: {PrayerSchool.gaudiya},
      schools: {PrayerSchool.gaudiya},
      hint: tr('16 rounds of 108 beads · 1,728 names'),
    ),
    p(
      tr('Bhajan and satsang'),
      PrayerKind.service,
      at(18),
      at(19, 30),
      color: 'EAB308',
      remindBefore: 30,
      weekdays: PresetKit.sunday,
      core: false,
      hint: tr('Sing and listen together · weekly'),
    ),
    p(
      tr('Temple visit'),
      PrayerKind.service,
      at(8),
      at(9),
      color: 'EF4444',
      weekdays: PresetKit.sunday,
      place: tr('Temple'),
      core: false,
      hint: tr('Darshan · pick the weekday of your deity'),
    ),
    p(
      tr('Seva'),
      PrayerKind.service,
      at(10),
      at(11),
      color: '10B981',
      priority: PrayerPriority.low,
      weekdays: PresetKit.sunday,
      core: false,
      hint: tr('Selfless service · at the temple or in your community'),
    ),
    p(
      tr('Weekday vrata'),
      PrayerKind.fasting,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunset, 17 * 60 + 45),
      color: 'D97706',
      remindBefore: null,
      remindBeforeEnd: 0,
      weekdays: PresetKit.monday,
      core: false,
      coreFor: {PrayerSchool.shaiva},
      hint: tr(
        'Monday Shiva · Tuesday Hanuman · Thursday Vishnu · Friday Lakshmi · Saturday Shani',
      ),
    ),
    p(
      tr('Ekadashi vrata'),
      PrayerKind.fasting,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunset, 17 * 60 + 45),
      color: 'D97706',
      remindBefore: null,
      remindBeforeEnd: 0,
      calendar: 'tithi:11,26',
      core: false,
      coreFor: {PrayerSchool.vaishnava, PrayerSchool.gaudiya},
      hint: tr('Twice a month · the 11th lunar day · broken the next morning'),
    ),
    p(
      tr('Pradosh vrata'),
      PrayerKind.fasting,
      sun(SolarEvent.sunset, 17 * 60 + 45, -45),
      sun(SolarEvent.sunset, 17 * 60 + 45, 90),
      color: '6366F1',
      remindBefore: 30,
      calendar: 'tithi:13,28@18',
      core: false,
      coreFor: {PrayerSchool.shaiva},
      hint: tr('Twice a month · the 13th lunar day · Shiva worship at dusk'),
    ),
    p(
      tr('Sankashti Chaturthi'),
      PrayerKind.fasting,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunset, 17 * 60 + 45, 150),
      color: 'F97316',
      remindBefore: null,
      remindBeforeEnd: 0,
      calendar: 'tithi:19@20',
      core: false,
      hint: tr(
        'Each month · the 4th day after the full moon · Ganesha, broken at moonrise',
      ),
    ),
    p(
      tr('Purnima'),
      PrayerKind.service,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunset, 17 * 60 + 45),
      color: 'EAB308',
      remindBefore: 30,
      calendar: 'tithi:15',
      core: false,
      hint: tr(
        'The full-moon day · Satyanarayan puja, charity and a holy bath',
      ),
    ),
    p(
      tr('Amavasya'),
      PrayerKind.service,
      sun(SolarEvent.sunrise, 6 * 60),
      sun(SolarEvent.sunset, 17 * 60 + 45),
      color: '64748B',
      remindBefore: 30,
      calendar: 'tithi:30',
      core: false,
      hint: tr('The new-moon day · prayers and offerings for the ancestors'),
    ),
  ];
}
