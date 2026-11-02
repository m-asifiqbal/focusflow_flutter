/// Each tradition in its own words: no Islamic vocabulary in another
/// tradition's profile, kinds and events that belong to it, the schools
/// shaping the starting sets (Hanafi Witr, Jafari Maghrib, Reform's lighter
/// week, the Orthodox prayer rule, a Smarta's sandhyas, a Zen sit, a Pure
/// Land nembutsu), every preset a real window with and without a location,
/// the Jewish halachic hours, and a school kept in the prayer settings.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/prayer_prefs.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_school.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/tradition_profile.dart';

void main() {
  final now = DateTime(2026, 11, 1, 9);
  final day = DateTime(2026, 11, 1);
  const dhaka = PrayerCalcSettings(
    location: GeoPoint(23.81, 90.41),
    method: PrayerCalcMethod.karachi,
  );
  SolarDay sunFor(DateTime d) => PrayerTimes.compute(dhaka, d);

  List<String> names(PrayerTradition t, [PrayerSchool? s]) => [
    for (final p in PrayerPresets.of(t, now, school: s)) p.draft.name,
  ];
  Set<String> core(PrayerTradition t, [PrayerSchool? s]) => {
    for (final p in PrayerPresets.of(t, now, school: s))
      if (p.core) p.draft.name,
  };

  group('words', () {
    // Words that belong to one tradition must not show up in another.
    const islamic = [
      'Salah',
      'Nafl',
      'Dhikr',
      'Suhoor',
      'Iftar',
      'Jamaat',
      'Fajr',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
      'Fard',
      'Quran',
      'Mosque',
    ];

    List<String> wordsOf(PrayerTradition t) {
      final p = PrayerTraditionProfile.of(t);
      return [
        p.newTitle,
        p.editTitle,
        p.nameHint,
        p.notesHint,
        for (final k in PrayerKind.values) ...[p.kindShort(k), p.kindLabel(k)],
        for (final k in PrayerKind.values) p.markLabel(k),
        p.wherePrompt,
        p.autoLabel,
        p.sunEventTitle,
        for (final e in p.sunEvents) p.eventLabel(e),
        p.fast.startLabel,
        p.fast.endLabel,
        p.fast.remindStartLabel,
        p.fast.remindEndLabel,
        p.fast.startsAt('5:00'),
        p.fast.endsNow,
        p.fast.endsIn(20),
        p.fast.endsWhen('in 5 min'),
        p.fast.startsWhen('in 5 min'),
        p.fast.span('5:00', '18:00'),
        p.congregationTitle,
        p.congregationTimeLabel,
        p.congregationAtLabel,
        p.congregationToday('1:00'),
        p.congregationLine('1:00'),
        p.congregationNow('X'),
        p.congregationSoon('X', 10),
        p.congregationBody('1:00'),
        p.inCongregation,
        ...p.places,
      ];
    }

    for (final t in [
      PrayerTradition.christianity,
      PrayerTradition.judaism,
      PrayerTradition.hinduism,
      PrayerTradition.buddhism,
      PrayerTradition.custom,
    ]) {
      test('${t.key}: no Islamic words', () {
        for (final w in wordsOf(t)) {
          for (final bad in islamic) {
            expect(w.contains(bad), isFalse, reason: '"$w" in ${t.key}');
          }
        }
      });
    }

    test('Islam keeps its own', () {
      final p = PrayerTraditionProfile.of(PrayerTradition.islam);
      expect(p.kindShort(PrayerKind.salah), 'Fard');
      expect(p.fast.endsNow, 'Iftar time');
      expect(p.fast.startLabel, contains('Suhoor'));
      expect(p.congregationTitle, 'Jamaat (congregation)');
      expect(p.hasCongregationEstimate, isTrue);
      expect(p.sunEvents, contains(SolarEvent.asr));
    });

    test('each tradition offers only what it has', () {
      final jewish = PrayerTraditionProfile.of(PrayerTradition.judaism);
      expect(jewish.sunEvents, contains(SolarEvent.sofZmanShema));
      expect(jewish.sunEvents, isNot(contains(SolarEvent.asr)));
      expect(jewish.autoLabel, 'Zmanim');
      expect(jewish.congregationTitle, 'Minyan (quorum of ten)');
      expect(jewish.hasCongregationEstimate, isFalse);
      final buddhist = PrayerTraditionProfile.of(PrayerTradition.buddhism);
      expect(buddhist.kinds.first, PrayerKind.meditation);
      expect(buddhist.kinds, isNot(contains(PrayerKind.salah)));
      expect(buddhist.markLabel(PrayerKind.meditation), 'Mark practised');
      final hindu = PrayerTraditionProfile.of(PrayerTradition.hinduism);
      expect(hindu.kindShort(PrayerKind.dhikr), 'Japa');
      expect(hindu.offsets, contains(-96)); // Brahma muhurta
      expect(hindu.goals, contains(108));
      final christian = PrayerTraditionProfile.of(PrayerTradition.christianity);
      expect(christian.kindShort(PrayerKind.dhikr), 'Beads');
      expect(christian.sunEvents, isNot(contains(SolarEvent.lastThird)));
    });

    test('a fast starts and ends where its tradition says', () {
      final (js, je) = PrayerTraditionProfile.of(
        PrayerTradition.judaism,
      ).fastWindow;
      expect(js.offset, -72); // alot hashachar
      expect(je.offset, 42); // tzeit
      final (bs, be) = PrayerTraditionProfile.of(
        PrayerTradition.buddhism,
      ).fastWindow;
      expect(bs.event, SolarEvent.noon); // nothing after midday
      expect(be.event, SolarEvent.dawn);
    });
  });

  group('presets', () {
    test('every tradition and school gives real windows', () {
      for (final t in PrayerTradition.values) {
        for (final school in <PrayerSchool?>[null, ...PrayerSchool.of(t)]) {
          final list = PrayerPresets.of(t, now, school: school);
          if (t == PrayerTradition.custom) {
            expect(list, isEmpty);
            continue;
          }
          expect(list, isNotEmpty, reason: '${t.key} $school');
          final seen = <String>{};
          for (final p in list) {
            final d = p.draft;
            expect(d.tradition, t);
            expect(p.hint, isNotEmpty, reason: d.name);
            expect(seen.add(d.name), isTrue, reason: 'twice: ${d.name}');
            for (final sun in <SolarDay?>[null, sunFor(day)]) {
              final w = PrayerSchedule.windowOn(
                d,
                day,
                sun,
                nextSun: sun == null
                    ? null
                    : sunFor(day.add(const Duration(days: 1))),
                prevSun: sun == null
                    ? null
                    : sunFor(day.subtract(const Duration(days: 1))),
              );
              final end = w.end;
              if (end != null) {
                expect(end.isAfter(w.start), isTrue, reason: d.name);
                expect(
                  end.difference(w.start).inHours,
                  lessThanOrEqualTo(26),
                  reason: '${d.name} ${w.start} – $end',
                );
              }
            }
          }
        }
      }
    });

    test('Islam: the five by default; a school adds its own', () {
      expect(core(PrayerTradition.islam), {
        'Fajr',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      });
      // Hanafi: Witr is wajib; Awwabin is offered.
      expect(
        core(PrayerTradition.islam, PrayerSchool.hanafi),
        contains('Witr'),
      );
      expect(
        names(PrayerTradition.islam, PrayerSchool.hanafi),
        contains('Awwabin'),
      );
      expect(
        core(PrayerTradition.islam, PrayerSchool.shafii),
        isNot(contains('Witr')),
      );
      expect(
        names(PrayerTradition.islam, PrayerSchool.shafii),
        isNot(contains('Awwabin')),
      );
      // Jafari: Maghrib after the redness fades, no congregational Taraweeh.
      final jafari = PrayerPresets.of(
        PrayerTradition.islam,
        now,
        school: PrayerSchool.jafari,
      );
      final maghrib = jafari.singleWhere((p) => p.draft.name == 'Maghrib');
      expect(maghrib.draft.start.offset, 15);
      expect(jafari.map((p) => p.draft.name), isNot(contains('Taraweeh')));
      final sunni = PrayerPresets.of(PrayerTradition.islam, now);
      expect(
        sunni.singleWhere((p) => p.draft.name == 'Maghrib').draft.start.offset,
        0,
      );
    });

    test('Islam: the Duha window and the adhkar count', () {
      final all = PrayerPresets.of(PrayerTradition.islam, now);
      Prayer get(String n) => all.firstWhere((p) => p.draft.name == n).draft;
      expect(get('Duha').start.offset, 20);
      expect(get('Duha').end!.event, SolarEvent.noon);
      expect(get('Duha').end!.offset, -10);
      expect(get('Tahajjud').end!.event, SolarEvent.dawn);
    });

    test('Christianity: each branch has its own', () {
      final catholic = core(
        PrayerTradition.christianity,
        PrayerSchool.catholic,
      );
      expect(
        catholic,
        containsAll(['Rosary', 'Sunday Mass', 'Friday penance']),
      );
      final orthodox = core(
        PrayerTradition.christianity,
        PrayerSchool.easternOrthodox,
      );
      expect(
        orthodox,
        containsAll([
          'Jesus Prayer',
          'Divine Liturgy',
          'Wednesday and Friday fast',
        ]),
      );
      expect(orthodox, isNot(contains('Rosary')));
      final protestant = core(
        PrayerTradition.christianity,
        PrayerSchool.protestant,
      );
      expect(protestant, containsAll(['Quiet time', 'Sunday worship']));
      expect(protestant, isNot(contains('Morning prayer')));
      expect(
        names(PrayerTradition.christianity, PrayerSchool.orientalOrthodox),
        contains('Prime (First Hour)'),
      );
      expect(
        names(PrayerTradition.christianity, PrayerSchool.protestant),
        isNot(contains('Prime (First Hour)')),
      );
      // The Catholic Friday is a weekday rule.
      final friday = PrayerPresets.of(
        PrayerTradition.christianity,
        now,
        school: PrayerSchool.catholic,
      ).singleWhere((p) => p.draft.name == 'Friday penance').draft;
      expect(friday.weekdaysMask, PrayerPresets.friday);
      expect(friday.kind, PrayerKind.fasting);
    });

    test('Judaism: three services for the observant, options for Reform', () {
      for (final s in [
        PrayerSchool.jewishOrthodox,
        PrayerSchool.conservative,
      ]) {
        expect(
          core(PrayerTradition.judaism, s),
          containsAll(['Shacharit', 'Mincha', 'Maariv']),
        );
      }
      final reform = core(PrayerTradition.judaism, PrayerSchool.reform);
      expect(reform, isNot(contains('Shacharit')));
      expect(reform, contains('Candle lighting'));
      // Unasked: the three services, as before.
      expect(core(PrayerTradition.judaism), {'Shacharit', 'Mincha', 'Maariv'});
      // Shabbat items sit on their weekday, by the sun.
      final all = PrayerPresets.of(PrayerTradition.judaism, now);
      Prayer get(String n) => all.firstWhere((p) => p.draft.name == n).draft;
      expect(get('Candle lighting').start.offset, -18);
      expect(get('Candle lighting').weekdaysMask, PrayerPresets.friday);
      expect(get('Shacharit').weekdaysMask & (1 << 5), 0); // not on Shabbat
      expect(get('Shacharit').end!.event, SolarEvent.sofZmanTefillah);
      expect(get('Mincha').start.offset, 30); // mincha gedola
    });

    test('Hinduism: the household practice, then the streams', () {
      expect(core(PrayerTradition.hinduism), {
        'Morning puja',
        'Mala japa',
        'Evening lamp and aarti',
      });
      expect(
        core(PrayerTradition.hinduism, PrayerSchool.smarta),
        contains('Sandhyavandanam (morning)'),
      );
      expect(
        names(PrayerTradition.hinduism, PrayerSchool.shaiva),
        isNot(contains('Sandhyavandanam (morning)')),
      );
      final gaudiya = PrayerPresets.of(
        PrayerTradition.hinduism,
        now,
        school: PrayerSchool.gaudiya,
      ).singleWhere((p) => p.draft.name == 'Hare Krishna japa');
      expect(gaudiya.core, isTrue);
      expect(gaudiya.draft.targetCount, 16);
      final brahma = PrayerPresets.of(
        PrayerTradition.hinduism,
        now,
      ).singleWhere((p) => p.draft.name == 'Brahma muhurta rising').draft;
      expect(brahma.start.offset, -96);
      expect(brahma.end!.offset, -48);
    });

    test('Buddhism: a sit for everyone, a school\'s own beside it', () {
      expect(core(PrayerTradition.buddhism), contains('Morning sit'));
      expect(
        core(PrayerTradition.buddhism, PrayerSchool.pureLand),
        contains('Nembutsu'),
      );
      expect(
        names(PrayerTradition.buddhism, PrayerSchool.pureLand),
        isNot(contains('Gongyo and daimoku')),
      );
      final pureLand = PrayerPresets.of(
        PrayerTradition.buddhism,
        now,
        school: PrayerSchool.pureLand,
      ).singleWhere((p) => p.draft.name == 'Nembutsu').draft;
      expect(pureLand.targetCount, isNull); // no count needed
      expect(
        core(PrayerTradition.buddhism, PrayerSchool.nichiren),
        contains('Gongyo and daimoku'),
      );
      final mala = PrayerPresets.of(
        PrayerTradition.buddhism,
        now,
        school: PrayerSchool.tibetan,
      ).singleWhere((p) => p.draft.name == 'Mantra on the mala').draft;
      expect(mala.targetCount, 108);
      // A sit is a short window from its start.
      final sit = PrayerPresets.of(
        PrayerTradition.buddhism,
        now,
      ).singleWhere((p) => p.draft.name == 'Morning sit').draft;
      expect(sit.end!.offset - sit.start.offset, 20);
    });

    test('a school of another tradition changes nothing', () {
      expect(
        names(PrayerTradition.judaism, PrayerSchool.catholic),
        names(PrayerTradition.judaism),
      );
    });
  });

  group('halachic hours', () {
    test('sof zman Shema, Tefillah and plag follow the day', () {
      final s = sunFor(day);
      final length = s.sunset.difference(s.sunrise);
      expect(
        s.at(SolarEvent.sofZmanShema).difference(s.sunrise).inMinutes,
        closeTo(length.inMinutes / 4, 1),
      );
      expect(
        s.at(SolarEvent.sofZmanTefillah).difference(s.sunrise).inMinutes,
        closeTo(length.inMinutes / 3, 1),
      );
      expect(
        s.sunset.difference(s.at(SolarEvent.plagHamincha)).inMinutes,
        closeTo(length.inMinutes * 1.25 / 12, 1),
      );
      // Whole minutes, in the right order.
      for (final e in [
        SolarEvent.sofZmanShema,
        SolarEvent.sofZmanTefillah,
        SolarEvent.plagHamincha,
      ]) {
        expect(s.at(e).second, 0);
      }
      expect(s.sunrise.isBefore(s.at(SolarEvent.sofZmanShema)), isTrue);
      expect(
        s
            .at(SolarEvent.sofZmanShema)
            .isBefore(s.at(SolarEvent.sofZmanTefillah)),
        isTrue,
      );
      expect(s.at(SolarEvent.sofZmanTefillah).isBefore(s.noon), isTrue);
      expect(s.noon.isBefore(s.at(SolarEvent.plagHamincha)), isTrue);
      expect(s.at(SolarEvent.plagHamincha).isBefore(s.sunset), isTrue);
    });
  });

  group('schools in the settings', () {
    test('a school is kept per tradition and survives a round trip', () {
      final prefs = const PrayerPrefs().copyWith(
        tradition: 'islam',
        schools: {'islam': 'hanafi', 'judaism': 'reform'},
      );
      final back = PrayerPrefs.fromJson(prefs.toJson());
      expect(back.schoolOf('islam'), 'hanafi');
      expect(back.schoolOf('judaism'), 'reform');
      expect(back.schoolOf('hinduism'), isNull);
      expect(back, prefs);
      expect(PrayerSchool.fromKey(back.schoolOf('islam')), PrayerSchool.hanafi);
      // Old settings without the field, and junk in it, are fine.
      expect(PrayerPrefs.fromJson({'tradition': 'islam'}).schools, isEmpty);
      expect(PrayerPrefs.fromJson({'schools': 'x'}).schools, isEmpty);
      expect(PrayerSchool.fromKey('nope'), isNull);
    });

    test('every school belongs to the tradition it is listed under', () {
      for (final t in PrayerTradition.values) {
        for (final s in PrayerSchool.of(t)) {
          expect(s.tradition, t);
          expect(s.label, isNotEmpty);
        }
        expect(
          PrayerSchool.of(t).isNotEmpty,
          t != PrayerTradition.custom,
          reason: t.key,
        );
      }
    });
  });
}
