/// Prayer windows and progress: due days (weekdays, date range, pause),
/// windows that end tomorrow, slot states through the day, "mark" = on
/// time inside the window / late after, the hero pick, Tahajjud from the
/// night ending this morning, streaks / on-time rate / week grid, and that
/// every tradition's presets produce real windows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_presets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

final _t0 = DateTime(2026, 1, 1);

Prayer _p(
  String id, {
  int start = 15 * 60 + 45,
  int? end = 17 * 60 + 45,
  PrayerKind kind = PrayerKind.salah,
  int weekdays = Prayer.everyDay,
  DateTime? from,
  DateTime? to,
  bool paused = false,
}) => Prayer(
  id: id,
  name: id,
  kind: kind,
  start: PrayerTimeRule.fixed(start),
  end: end == null ? null : PrayerTimeRule.fixed(end),
  weekdaysMask: weekdays,
  startDate: from,
  endDate: to,
  isPaused: paused,
  createdAt: _t0,
  updatedAt: _t0,
);

SolarDay? _noSun(DateTime _) => null;

void main() {
  final day = DateTime(2026, 10, 23); // a Friday

  group('due days', () {
    test('weekdays, date range and pause', () {
      expect(PrayerSchedule.isDueOn(_p('a'), day), isTrue);
      expect(
        PrayerSchedule.isDueOn(_p('a', weekdays: PrayerPresets.friday), day),
        isTrue,
      );
      expect(
        PrayerSchedule.isDueOn(_p('a', weekdays: PrayerPresets.monday), day),
        isFalse,
      );
      final ranged = _p(
        'r',
        from: DateTime(2026, 10, 20),
        to: DateTime(2026, 10, 22),
      );
      expect(PrayerSchedule.isDueOn(ranged, DateTime(2026, 10, 22)), isTrue);
      expect(PrayerSchedule.isDueOn(ranged, day), isFalse);
      expect(PrayerSchedule.isDueOn(_p('p', paused: true), day), isFalse);
    });
  });

  group('windows and states', () {
    test('an end at or before the start is the next day', () {
      final w = PrayerSchedule.windowOn(
        _p('isha', start: 19 * 60, end: 60),
        day,
        null,
      );
      expect(w.start, DateTime(2026, 10, 23, 19));
      expect(w.end, DateTime(2026, 10, 24, 1));
    });

    test('states through the day, and what a mark records', () {
      final slot = PrayerSchedule.dayPlan([_p('asr')], day, _noSun, {}).single;
      DateTime at(int h, int m) => DateTime(2026, 10, 23, h, m);
      expect(slot.stateAt(at(15, 0)), PrayerSlotState.upcoming);
      expect(slot.stateAt(at(16, 0)), PrayerSlotState.open);
      expect(slot.stateAt(at(17, 30)), PrayerSlotState.endingSoon);
      expect(slot.stateAt(at(18, 0)), PrayerSlotState.missed);
      expect(slot.markAt(at(16, 0)), PrayerStatus.onTime);
      expect(slot.markAt(at(18, 0)), PrayerStatus.late);
      final done = PrayerSlot(
        prayer: slot.prayer,
        day: day,
        window: slot.window,
        log: PrayerLog(prayerId: 'asr', day: day, status: PrayerStatus.late),
      );
      expect(done.stateAt(at(18, 0)), PrayerSlotState.done);
    });

    test('the hero: the open prayer, else the next; never a fast', () {
      final slots = PrayerSchedule.dayPlan(
        [
          _p('dhuhr', start: 12 * 60, end: 15 * 60 + 45),
          _p('asr'),
          _p('fast', kind: PrayerKind.fasting, start: 5 * 60, end: 18 * 60),
        ],
        day,
        _noSun,
        {},
      );
      expect(
        PrayerSchedule.focus(slots, DateTime(2026, 10, 23, 13))?.prayer.id,
        'dhuhr',
      );
      expect(
        PrayerSchedule.focus(slots, DateTime(2026, 10, 23, 15, 50))?.prayer.id,
        'asr',
      );
      expect(PrayerSchedule.focus(slots, DateTime(2026, 10, 23, 19)), isNull);
    });

    test('Tahajjud: the last third of the night ending this morning', () {
      const settings = PrayerCalcSettings(location: GeoPoint(23.81, 90.41));
      SolarDay sunFor(DateTime d) => PrayerTimes.compute(settings, d);
      final tahajjud = Prayer(
        id: 't',
        name: 'Tahajjud',
        start: const PrayerTimeRule.auto(SolarEvent.lastThird, minutes: 210),
        end: const PrayerTimeRule.auto(SolarEvent.dawn, minutes: 300),
        createdAt: _t0,
        updatedAt: _t0,
      );
      final w = PrayerSchedule.dayPlan([tahajjud], day, sunFor, {}).single;
      expect(w.window.start.isBefore(w.window.end!), isTrue);
      expect(w.window.start.day, 23);
      expect(w.window.end, sunFor(day).dawn);
    });
  });

  group('progress', () {
    test('streak, best streak, on-time rate, month and week grid', () {
      final a = _p('a', start: 5 * 60, end: 6 * 60);
      final b = _p('b', start: 12 * 60, end: 13 * 60);
      final now = DateTime(2026, 10, 23, 14);
      PrayerLog log(Prayer p, int daysAgo, PrayerStatus s) => PrayerLog(
        prayerId: p.id,
        day: DateTime(2026, 10, 23 - daysAgo),
        status: s,
      );
      final logs = [
        // Today and the two days before: complete (one late).
        log(a, 0, PrayerStatus.onTime),
        log(b, 0, PrayerStatus.onTime),
        log(a, 1, PrayerStatus.onTime),
        log(b, 1, PrayerStatus.late),
        log(a, 2, PrayerStatus.onTime),
        log(b, 2, PrayerStatus.excused),
        // 3 days ago: b missed (no log) — breaks the streak.
        log(a, 3, PrayerStatus.onTime),
        // 4–5 days ago: complete.
        log(a, 4, PrayerStatus.onTime),
        log(b, 4, PrayerStatus.onTime),
        log(a, 5, PrayerStatus.madeUp),
        log(b, 5, PrayerStatus.onTime),
      ];
      final p = PrayerStats.compute(prayers: [a, b], logs: logs, now: now);
      expect(p.streakDays, 3);
      expect(p.week, hasLength(2));
      expect(p.week.first.cells.last, PrayerCell.onTime);
      expect(p.week.last.cells[3], PrayerCell.missed);
      expect(p.week.last.cells[4], PrayerCell.excused);
      // Every past slot back to Jan 1 is due; the missed ones count.
      expect(p.onTimeRate, isNotNull);
      expect(p.onTimeRate!, lessThan(1));
    });

    test('an open prayer today does not break the streak', () {
      final a = _p('a', start: 5 * 60, end: 6 * 60);
      final b = _p('b', start: 20 * 60, end: 21 * 60);
      final now = DateTime(2026, 10, 23, 14);
      final logs = [
        PrayerLog(prayerId: 'a', day: day, status: PrayerStatus.onTime),
        PrayerLog(
          prayerId: 'a',
          day: DateTime(2026, 10, 22),
          status: PrayerStatus.onTime,
        ),
        PrayerLog(
          prayerId: 'b',
          day: DateTime(2026, 10, 22),
          status: PrayerStatus.onTime,
        ),
      ];
      final p = PrayerStats.compute(prayers: [a, b], logs: logs, now: now);
      expect(p.streakDays, 1);
      expect(p.week.last.cells.last, PrayerCell.pending);
    });

    test('fasts count as fasting days, never in the streak', () {
      final fast = _p('f', kind: PrayerKind.fasting, start: 300, end: 1080);
      final p = PrayerStats.compute(
        prayers: [fast],
        logs: [PrayerLog(prayerId: 'f', day: day, status: PrayerStatus.onTime)],
        now: DateTime(2026, 10, 23, 20),
      );
      expect(p.fastingDaysThisMonth, 1);
      expect(p.week, isEmpty);
      expect(p.streakDays, 0);
    });
  });

  group('presets', () {
    test('every tradition gives real windows, with and without a location', () {
      const settings = PrayerCalcSettings(location: GeoPoint(23.81, 90.41));
      SolarDay sunFor(DateTime d) => PrayerTimes.compute(settings, d);
      for (final t in PrayerTradition.values) {
        final presets = PrayerPresets.of(t, DateTime(2026, 11, 1));
        if (t == PrayerTradition.custom) {
          expect(presets, isEmpty);
          continue;
        }
        expect(presets.where((p) => p.core), isNotEmpty, reason: t.name);
        for (final p in presets) {
          for (final sun in [sunFor, _noSun]) {
            final w = PrayerSchedule.windowOn(
              p.draft,
              day,
              sun(day),
              nextSun: sun(day.add(const Duration(days: 1))),
              prevSun: sun(day.subtract(const Duration(days: 1))),
            );
            expect(
              w.end == null || w.end!.isAfter(w.start),
              isTrue,
              reason: '${t.name} ${p.draft.name}',
            );
          }
        }
        expect(
          PrayerPresets.manual([
            for (final p in presets) p.draft,
          ]).every((p) => !p.usesSun),
          isTrue,
        );
      }
    });

    test('the Ramadan fast covers the coming Ramadan', () {
      final (from, to) = PrayerPresets.ramadanRange(DateTime(2026, 11, 1));
      expect(from, DateTime(2027, 2, 8));
      expect(to.difference(from).inDays, inInclusiveRange(28, 29));
    });
  });
}
