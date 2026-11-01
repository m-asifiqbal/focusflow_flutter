/// PrayerInsightsCalculator — outcomes, buckets, per prayer, best run of
/// complete days, the previous window, fasts, dhikr and places; days
/// before a prayer existed and today's open window never count.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';

/// Sun 1 Nov 2026, 10:00 — Fajr's window is over, Isha's is ahead.
final _now = DateTime(2026, 11, 1, 10);
final _created = DateTime(2026, 9, 1);

Prayer _prayer(
  String id,
  String name,
  int start,
  int end, {
  PrayerKind kind = PrayerKind.salah,
  int? target,
  String place = '',
  DateTime? created,
}) => Prayer(
  id: id,
  name: name,
  kind: kind,
  start: PrayerTimeRule.fixed(start),
  end: PrayerTimeRule.fixed(end),
  targetCount: target,
  place: place,
  createdAt: created ?? _created,
  updatedAt: created ?? _created,
);

PrayerLog _log(
  String id,
  DateTime day,
  PrayerStatus s, {
  bool congregation = false,
  String? place,
  int count = 0,
}) => PrayerLog(
  prayerId: id,
  day: day,
  status: s,
  congregation: congregation,
  place: place,
  count: count,
);

DateTime _ago(int days) => DateUtilsX.addDays(DateUtilsX.dateOnly(_now), -days);

void main() {
  final fajr = _prayer('f', 'Fajr', 5 * 60, 6 * 60, place: 'Home');
  final isha = _prayer('i', 'Isha', 19 * 60, 23 * 60);
  final fast = _prayer(
    'x',
    'Monday fast',
    5 * 60,
    18 * 60,
    kind: PrayerKind.fasting,
  );
  final dhikr = _prayer(
    'd',
    'Evening adhkar',
    17 * 60,
    20 * 60,
    kind: PrayerKind.dhikr,
    target: 100,
  );

  test('daily window: outcomes, buckets, per prayer, streak', () {
    final logs = [
      // 6 days ago … yesterday: Fajr every day (one late), Isha all but 3
      // days ago (missed: no log).
      for (var d = 1; d <= 6; d++)
        _log(
          'f',
          _ago(d),
          d == 2 ? PrayerStatus.late : PrayerStatus.onTime,
          congregation: d == 1,
          place: d == 1 ? 'Mosque' : null,
        ),
      for (var d = 1; d <= 6; d++)
        if (d != 3) _log('i', _ago(d), PrayerStatus.onTime),
      // Today: Fajr done; Isha still ahead (pending → not counted).
      _log('f', _ago(0), PrayerStatus.madeUp),
    ];
    final s = PrayerInsightsCalculator.compute(
      prayers: [isha, fajr],
      logs: logs,
      period: PrayerPeriod.daily,
      now: _now,
    );
    expect(s.start, _ago(6));
    expect(s.buckets, hasLength(7));
    // Fajr: 5 on time, 1 late, 1 made up · Isha: 5 on time, 1 missed.
    expect(s.counts.onTime, 10);
    expect(s.counts.late, 1);
    expect(s.counts.madeUp, 1);
    expect(s.counts.missed, 1);
    expect(s.counts.due, 13);
    expect(s.counts.completion, closeTo(12 / 13, 1e-9));
    // Order of the day, not the input order.
    expect(s.perPrayer.map((p) => p.prayer.name), ['Fajr', 'Isha']);
    expect(s.perPrayer.last.counts.missed, 1);
    // Complete: 6 days back to 4 days back, then 2 and 1 days back
    // (today is still open) → best run 3.
    expect(s.trackedDays, 7);
    expect(s.completeDays, 5);
    expect(s.bestStreak, 3);
    expect(s.congregation, 1);
    // Done Fajr logs: one at the mosque, the rest at the usual place.
    expect(s.places, [('Home', 6), ('Mosque', 1)]);
    // Nothing logged the week before: every due day was missed.
    expect(s.previous.missed, 14);
    expect(s.previous.completion, 0);
  });

  test('a prayer added this week only counts from its first day', () {
    final late = _prayer(
      'n',
      'Night prayer',
      21 * 60,
      22 * 60,
      created: _ago(2),
    );
    final s = PrayerInsightsCalculator.compute(
      prayers: [late],
      logs: [_log('n', _ago(1), PrayerStatus.onTime)],
      period: PrayerPeriod.daily,
      now: _now,
    );
    // Two days ago (missed) and yesterday; today's window is ahead.
    expect(s.counts.onTime, 1);
    expect(s.counts.missed, 1);
    expect(s.trackedDays, 2);
    expect(s.previous.isEmpty, isTrue);
  });

  test('fasts and dhikr are counted on their own; excused never lowers', () {
    final s = PrayerInsightsCalculator.compute(
      prayers: [fajr, fast, dhikr],
      logs: [
        _log('x', _ago(1), PrayerStatus.onTime),
        _log('x', _ago(2), PrayerStatus.late),
        _log('d', _ago(1), PrayerStatus.onTime, count: 100),
        _log('d', _ago(2), PrayerStatus.pending, count: 40),
        for (var d = 0; d <= 6; d++)
          _log(
            'f',
            _ago(d),
            d == 4 ? PrayerStatus.excused : PrayerStatus.onTime,
          ),
      ],
      period: PrayerPeriod.daily,
      now: _now,
    );
    expect(s.counts.excused, 1);
    expect(s.counts.completion, 1);
    expect(s.perPrayer.single.prayer.name, 'Fajr');
    // Fasted yesterday, broken 2 days ago, 4 more days not fasted (today
    // is still running).
    expect(s.fastsKept, 1);
    expect(s.fastsDue, 6);
    expect(s.dhikrTotal, 140);
    expect(s.dhikrGoalDays, 1);
    expect(s.bestStreak, 7);
  });

  test('yearly: 12 month buckets; empty without prayers', () {
    final s = PrayerInsightsCalculator.compute(
      prayers: [fajr],
      logs: [_log('f', DateTime(2026, 10, 3), PrayerStatus.onTime)],
      period: PrayerPeriod.yearly,
      now: _now,
    );
    expect(s.buckets, hasLength(12));
    expect(s.buckets.first.start, DateTime(2025, 12));
    expect(s.buckets.last.start, DateTime(2026, 11));
    expect(s.buckets[10].counts.onTime, 1);
    final none = PrayerInsightsCalculator.compute(
      prayers: const [],
      logs: const [],
      period: PrayerPeriod.monthly,
      now: _now,
    );
    expect(none.hasData, isFalse);
    expect(none.buckets, hasLength(30));
  });
}
