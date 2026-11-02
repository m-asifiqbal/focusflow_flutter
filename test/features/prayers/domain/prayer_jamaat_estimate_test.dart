/// The offline jamaat estimate: which prayer is which (sun event, then the
/// name), each prayer's delay and rounding, the guard before the window's
/// end, how it reaches the schedule ("~" days follow the season), and that
/// it survives a save.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_jamaat_estimate.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

final _now = DateTime(2026, 11, 1, 10);

Prayer _salah(String name, PrayerTimeRule start, {PrayerTimeRule? end}) =>
    Prayer(
      id: name,
      name: name,
      kind: PrayerKind.salah,
      tradition: PrayerTradition.islam,
      start: start,
      end: end,
      createdAt: _now,
      updatedAt: _now,
    );

DateTime _at(int h, [int m = 0, int s = 0]) => DateTime(2026, 11, 1, h, m, s);

void main() {
  group('roleOf', () {
    test('by sun event, else by name; never fasts or other kinds', () {
      DailyPrayer? role(Prayer p) => PrayerJamaatEstimate.roleOf(p);
      expect(
        role(_salah('X', const PrayerTimeRule.auto(SolarEvent.dawn))),
        DailyPrayer.fajr,
      );
      expect(
        role(_salah('X', const PrayerTimeRule.auto(SolarEvent.nightfall))),
        DailyPrayer.isha,
      );
      expect(
        role(_salah('Zuhr', const PrayerTimeRule.fixed(13 * 60))),
        DailyPrayer.dhuhr,
      );
      expect(
        role(_salah('Maghrib', const PrayerTimeRule.fixed(18 * 60))),
        DailyPrayer.maghrib,
      );
      expect(
        role(_salah('Tahajjud', const PrayerTimeRule.fixed(3 * 60))),
        isNull,
      );
      final fast = _salah(
        'Fajr',
        const PrayerTimeRule.fixed(5 * 60),
      ).copyWith(kind: PrayerKind.fasting);
      expect(role(fast), isNull);
    });
  });

  group('at', () {
    test('delay, then up to the round time', () {
      // Fajr 4:57:40 + 30 → 5:27 → 5:30.
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.fajr, _at(4, 57, 40), _at(6, 10)),
        _at(5, 30),
      );
      // Dhuhr 11:52 + 30 → 12:22 → 12:30 (quarter hours).
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.dhuhr, _at(11, 52), _at(15, 20)),
        _at(12, 30),
      );
      // Dhuhr 12:00:30 + 30 → 12:30 (seconds don't push it a step).
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.dhuhr, _at(12, 0, 30), _at(15, 20)),
        _at(12, 30),
      );
      // Asr 15:21 + 15 → 15:36 → 15:40.
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.asr, _at(15, 21), _at(17, 19)),
        _at(15, 40),
      );
      // Maghrib 17:19 + 5 → 17:24.
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.maghrib, _at(17, 19), _at(18, 33)),
        _at(17, 24),
      );
    });

    test('never closer than 15 minutes to the end of a short window', () {
      // Fajr 5:00 – 5:40: 5:30 would leave 10 min → 5:25.
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.fajr, _at(5), _at(5, 40)),
        _at(5, 25),
      );
      // A window shorter than the margin: at the start.
      expect(
        PrayerJamaatEstimate.at(DailyPrayer.maghrib, _at(18), _at(18, 10)),
        _at(18),
      );
    });
  });

  test('the schedule uses it, marked as estimated', () {
    final asr = _salah(
      'Asr',
      const PrayerTimeRule.fixed(15 * 60 + 21),
      end: const PrayerTimeRule.fixed(17 * 60 + 19),
    ).copyWith(jamaat: const PrayerJamaat.estimated());
    final slot = PrayerSchedule.dayPlan([asr], _now, (_) => null, {}).single;
    expect(slot.jamaat, _at(15, 40));
    expect(asr.jamaat!.estimated, isTrue);
  });

  test('an estimated jamaat survives a save', () async {
    final h = await TestHarness.create(now: _now);
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final id = await repo.save(
      Prayer(
        id: '',
        name: 'Isha',
        kind: PrayerKind.salah,
        start: const PrayerTimeRule.fixed(19 * 60),
        jamaat: const PrayerJamaat.estimated(),
        remindBeforeJamaat: 10,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    final back = (await repo.getPrayer(id))!;
    expect(back.jamaat, const PrayerJamaat.estimated());
    expect(back.remindBeforeJamaat, 10);
    // Back to a set time clears the flag.
    await repo.save(back.copyWith(jamaat: const PrayerJamaat.at(19 * 60 + 30)));
    expect(
      (await repo.getPrayer(id))!.jamaat,
      const PrayerJamaat.at(19 * 60 + 30),
    );
  });
}
