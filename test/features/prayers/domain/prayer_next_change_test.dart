/// When does the Prayer page next change by itself? At the first window
/// start, end, "ending soon" stretch, jamaat time or midnight after now —
/// the instant the page wakes up at, so a waqt that has ended never lingers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

final _t0 = DateTime(2026, 1, 1);

Prayer _p(String id, int start, int? end, {PrayerJamaat? jamaat}) => Prayer(
  id: id,
  name: id,
  kind: PrayerKind.salah,
  start: PrayerTimeRule.fixed(start),
  end: end == null ? null : PrayerTimeRule.fixed(end),
  jamaat: jamaat,
  createdAt: _t0,
  updatedAt: _t0,
);

SolarDay? _noSun(DateTime _) => null;

void main() {
  final day = DateTime(2026, 11, 1);
  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 11, 1, h, m, s);
  List<PrayerSlot> plan(List<Prayer> ps) =>
      PrayerSchedule.dayPlan(ps, day, _noSun, {});

  test('the next window edge, in order', () {
    final slots = plan([
      _p('asr', 15 * 60 + 45, 17 * 60 + 45),
      _p('maghrib', 17 * 60 + 45, 19 * 60),
    ]);
    // Before Asr: its start.
    expect(PrayerSchedule.nextChange(slots, at(14, 0)), at(15, 45));
    // In Asr: first the last-20-minutes mark, then its end.
    expect(PrayerSchedule.nextChange(slots, at(16, 0)), at(17, 25));
    expect(PrayerSchedule.nextChange(slots, at(17, 25)), at(17, 45));
    // Exactly at the end: the next thing is Maghrib's own marks.
    expect(PrayerSchedule.nextChange(slots, at(17, 45)), at(18, 40));
    // After the last window: midnight.
    expect(PrayerSchedule.nextChange(slots, at(19, 30)), DateTime(2026, 11, 2));
  });

  test('a second before an end is still that end', () {
    final slots = plan([_p('asr', 15 * 60 + 45, 17 * 60 + 45)]);
    expect(PrayerSchedule.nextChange(slots, at(17, 44, 59)), at(17, 45));
  });

  test('jamaat: comes into view 3 hours ahead, then passes', () {
    final slots = plan([
      _p(
        'asr',
        15 * 60 + 45,
        17 * 60 + 45,
        jamaat: const PrayerJamaat.at(17 * 60),
      ),
    ]);
    expect(PrayerSchedule.nextChange(slots, at(13, 0)), at(14, 0));
    expect(PrayerSchedule.nextChange(slots, at(16, 30)), at(17, 0));
  });

  test('tomorrow\'s first prayer counts while it is the card', () {
    final today = plan([_p('asr', 15 * 60 + 45, 17 * 60 + 45)]);
    final fajr = PrayerSchedule.dayPlan(
      [_p('fajr', 5 * 60, 6 * 60)],
      DateTime(2026, 11, 2),
      _noSun,
      {},
    ).single;
    // Midnight comes first, then Fajr's start is reachable too.
    expect(
      PrayerSchedule.nextChange([...today, fajr], at(23, 0)),
      DateTime(2026, 11, 2),
    );
    expect(
      PrayerSchedule.nextChange([fajr], DateTime(2026, 11, 2, 0, 0, 1)),
      DateTime(2026, 11, 2, 5),
    );
  });

  test('nothing but the end of the day for an empty list', () {
    expect(
      PrayerSchedule.nextChange(const [], at(10, 0)),
      DateTime(2026, 11, 2),
    );
  });
}
