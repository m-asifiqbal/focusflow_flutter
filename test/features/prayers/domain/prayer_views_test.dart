/// The newer shapes of Prayer progress: the Venn of days and the "When you
/// pray" rows of Insights › Prayer, and the Day / Month / Year views of the
/// Prayer page — what places a day, which logs give the mark times, how
/// days before a prayer existed and today's open window are treated.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_progress_views.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_timing.dart';

/// Sun 1 Nov 2026, 10:00 — Fajr's window is over, Isha's is ahead.
final _now = DateTime(2026, 11, 1, 10);
final _created = DateTime(2025, 9, 1);

Prayer _prayer(String id, String name, int start, int end, {DateTime? at}) =>
    Prayer(
      id: id,
      name: name,
      kind: PrayerKind.salah,
      start: PrayerTimeRule.fixed(start),
      end: PrayerTimeRule.fixed(end),
      createdAt: at ?? _created,
      updatedAt: at ?? _created,
    );

PrayerLog _log(
  String id,
  DateTime day,
  PrayerStatus s, {
  DateTime? at,
  bool congregation = false,
}) => PrayerLog(
  prayerId: id,
  day: day,
  status: s,
  loggedAt: at,
  congregation: congregation,
);

DateTime _ago(int days) => DateUtilsX.addDays(DateUtilsX.dateOnly(_now), -days);

DateTime _at(DateTime day, int h, [int m = 0]) =>
    DateTime(day.year, day.month, day.day, h, m);

void main() {
  final fajr = _prayer('f', 'Fajr', 5 * 60, 6 * 60);
  final isha = _prayer('i', 'Isha', 19 * 60, 23 * 60);

  group('Venn of days', () {
    test('places each day by the outcomes it had', () {
      final logs = [
        // 1 day ago: both on time → on time only.
        _log('f', _ago(1), PrayerStatus.onTime),
        _log('i', _ago(1), PrayerStatus.onTime),
        // 2: on time + late → the on time / late overlap.
        _log('f', _ago(2), PrayerStatus.onTime),
        _log('i', _ago(2), PrayerStatus.late),
        // 3: made up + nothing for Isha (missed) → late / missed overlap.
        _log('f', _ago(3), PrayerStatus.madeUp),
        // 4: excused + on time → on time only (excused places nowhere).
        _log('f', _ago(4), PrayerStatus.excused),
        _log('i', _ago(4), PrayerStatus.onTime),
        // 5: on time, late, missed are impossible with two prayers — both
        // missed → missed only.
        // 6: late + late → late only.
        _log('f', _ago(6), PrayerStatus.late),
        _log('i', _ago(6), PrayerStatus.late),
      ];
      final s = PrayerInsightsCalculator.compute(
        prayers: [fajr, isha],
        logs: logs,
        period: PrayerPeriod.daily,
        now: _now,
      );
      // Today: Fajr unmarked after its window → missed; Isha still ahead.
      expect(
        s.venn,
        const PrayerVenn(
          onTimeOnly: 2,
          lateOnly: 1,
          missedOnly: 2,
          onTimeLate: 1,
          lateMissed: 1,
        ),
      );
      expect(s.venn.days, 7);
      expect(s.venn.lateNotMissed, 2);
      expect(s.venn.withMissed, 3);
    });
  });

  group('When you pray', () {
    test('mean window and quartiles of on-time / late mark times', () {
      final logs = [
        for (final (d, h, m) in [(1, 5, 10), (2, 5, 20), (3, 5, 40)])
          _log('f', _ago(d), PrayerStatus.onTime, at: _at(_ago(d), h, m)),
        // Late, marked after midnight: 24 h + 0:30.
        _log('i', _ago(2), PrayerStatus.late, at: _at(_ago(1), 0, 30)),
        // Made up a day later and unmarked times never count.
        _log('i', _ago(3), PrayerStatus.madeUp, at: _at(_ago(1), 9)),
        _log('i', _ago(4), PrayerStatus.onTime),
      ];
      final s = PrayerInsightsCalculator.compute(
        prayers: [isha, fajr],
        logs: logs,
        period: PrayerPeriod.daily,
        now: _now,
      );
      expect(s.timing.map((t) => t.prayer.id), ['f', 'i']);
      final f = s.timing.first;
      expect(f.windowStart, 5 * 60);
      expect(f.windowEnd, 6 * 60);
      expect(f.marks, 3);
      expect(f.median, 5 * 60 + 20);
      expect(f.q1, 5 * 60 + 20);
      expect(f.q3, 5 * 60 + 40);
      final i = s.timing.last;
      expect(i.marks, 1);
      expect(i.median, 24 * 60 + 30);
    });

    test('a prayer created today is sampled from today only', () {
      final fresh = _prayer('n', 'Dhuhr', 12 * 60, 15 * 60, at: _now);
      final rows = PrayerTimingCalculator.compute(
        tracked: [fresh],
        logs: const [],
        window: PrayerInsightsCalculator.window(PrayerPeriod.monthly, _now),
        today: _now,
        sunFor: (_) => null,
        step: 2,
      );
      expect(rows.single.windowStart, 12 * 60);
      expect(rows.single.median, isNull);
    });
  });

  group('Day view', () {
    test('outcome, mark time and congregation of each prayer', () {
      final day = _ago(1);
      final entries = PrayerProgressViews.dayOf(
        prayers: [isha, fajr],
        logs: [
          _log(
            'f',
            day,
            PrayerStatus.onTime,
            at: _at(day, 5, 12),
            congregation: true,
          ),
        ],
        now: _now,
        day: day,
      );
      expect(entries.map((e) => e.prayer.id), ['f', 'i']);
      expect(entries.first.cell, PrayerCell.onTime);
      expect(entries.first.loggedAt, _at(day, 5, 12));
      expect(entries.first.congregation, isTrue);
      expect(entries.last.cell, PrayerCell.missed);
      expect(entries.last.loggedAt, isNull);
    });

    test('today: an open prayer is pending', () {
      final entries = PrayerProgressViews.dayOf(
        prayers: [fajr, isha],
        logs: const [],
        now: _now,
        day: _ago(0),
      );
      expect(entries.map((e) => e.cell), [
        PrayerCell.missed,
        PrayerCell.pending,
      ]);
    });
  });

  group('Month view', () {
    test('every day of the month, no cells after today', () {
      final days = PrayerProgressViews.monthOf(
        prayers: [fajr, isha],
        logs: [_log('f', _ago(0), PrayerStatus.onTime)],
        now: _now,
        month: _now,
      );
      expect(days.length, 30);
      expect(days.first.day, DateTime(2026, 11));
      expect(days.first.cells, [PrayerCell.onTime, PrayerCell.pending]);
      expect(days[1].cells, isEmpty);
    });
  });

  group('Year view', () {
    test('daily shares and the last 12 months per prayer', () {
      final created = DateTime(2026, 10, 30);
      final f = _prayer('f', 'Fajr', 5 * 60, 6 * 60, at: created);
      final i = _prayer('i', 'Isha', 19 * 60, 23 * 60, at: created);
      final year = PrayerProgressViews.yearOf(
        prayers: [i, f],
        logs: [
          _log('f', _ago(2), PrayerStatus.onTime),
          _log('i', _ago(2), PrayerStatus.late),
          _log('f', _ago(1), PrayerStatus.onTime),
        ],
        now: _now,
      );
      expect(year.daily[_ago(2)], 1.0);
      expect(year.daily[_ago(1)], 0.5);
      // Today: Fajr missed, Isha still open → 0 of 1.
      expect(year.daily[_ago(0)], 0.0);
      expect(year.daily.containsKey(_ago(3)), isFalse);
      expect(year.perPrayer.map((e) => e.$1.id), ['f', 'i']);
      expect(year.perPrayer.first.$2, const PrayerRate(2, 3));
      expect(year.perPrayer.last.$2, const PrayerRate(1, 2));
      expect(year.total, const PrayerRate(3, 5));
    });
  });
}
