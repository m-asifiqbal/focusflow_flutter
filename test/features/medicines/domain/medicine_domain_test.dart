/// Medicine domain rules: which days a medicine is due, the day plan,
/// stock arithmetic, dose states, adherence / streak and the wording.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';

final _t0 = DateTime(2026, 1, 1);

Medicine med(
  String id, {
  String name = 'Metformin',
  MedicineScheduleType schedule = MedicineScheduleType.everyDay,
  int mask = 127,
  int everyN = 2,
  List<DoseTime> doses = const [DoseTime(8 * 60), DoseTime(20 * 60)],
  DateTime? start,
  DateTime? end,
  bool paused = false,
  double? stock,
  double? refillAt,
}) => Medicine(
  id: id,
  name: name,
  schedule: schedule,
  weekdaysMask: mask,
  everyNDays: everyN,
  doses: doses,
  startDate: start ?? DateTime(2026, 10, 1),
  endDate: end,
  isPaused: paused,
  stockLeft: stock,
  refillAt: refillAt,
  createdAt: _t0,
  updatedAt: _t0,
);

DoseLog log(
  Medicine m,
  DateTime day,
  int minutes, {
  DoseStatus status = DoseStatus.taken,
  DateTime? snoozedUntil,
}) {
  final key =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return DoseLog(
    id: DoseLog.idFor(m.id, key, minutes),
    medicineId: m.id,
    dayKey: key,
    slotMinutes: minutes,
    status: status,
    takenAt: status == DoseStatus.pending
        ? null
        : DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60),
    snoozedUntil: snoozedUntil,
    createdAt: _t0,
    updatedAt: _t0,
  );
}

void main() {
  group('MedicineSchedule.isScheduledOn', () {
    test('every day from the start date, until the end date', () {
      final m = med(
        'a',
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 7),
      );
      expect(MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 4)), false);
      expect(MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 5)), true);
      expect(
        MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 7, 23)),
        true,
      );
      expect(MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 8)), false);
    });

    test('specific days follow the Monday-based mask', () {
      // Mon + Wed + Fri.
      final m = med(
        'a',
        schedule: MedicineScheduleType.specificDays,
        mask: 0x15,
      );
      // 2026-10-19 is a Monday.
      final days = [
        for (var i = 0; i < 7; i++)
          MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 19 + i)),
      ];
      expect(days, [true, false, true, false, true, false, false]);
    });

    test('every N days counts from the start date', () {
      final m = med(
        'a',
        schedule: MedicineScheduleType.everyNDays,
        everyN: 3,
        start: DateTime(2026, 10, 1),
      );
      expect(MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 1)), true);
      expect(MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 2)), false);
      expect(MedicineSchedule.isScheduledOn(m, DateTime(2026, 10, 4)), true);
    });

    test('as needed and paused are never due (history ignores the pause)', () {
      final asNeeded = med('a', schedule: MedicineScheduleType.asNeeded);
      final paused = med('b', paused: true);
      final day = DateTime(2026, 10, 10);
      expect(MedicineSchedule.isScheduledOn(asNeeded, day), false);
      expect(MedicineSchedule.isScheduledOn(paused, day), false);
      expect(
        MedicineSchedule.isScheduledOn(paused, day, ignorePause: true),
        true,
      );
    });
  });

  group('MedicineSchedule.dayPlan', () {
    test('orders doses by time, then name, and keeps their logs', () {
      final a = med('a', name: 'Zinc', doses: const [DoseTime(8 * 60)]);
      final b = med('b', name: 'Aspirin', doses: const [DoseTime(8 * 60, 2)]);
      final day = DateTime(2026, 10, 10);
      final plan = MedicineSchedule.dayPlan([a, b], day, [log(a, day, 480)]);
      expect(plan.map((s) => s.medicine.name), ['Aspirin', 'Zinc']);
      expect(plan.first.quantity, 2);
      expect(plan.last.log?.isTaken, true);
    });

    test('includes as-needed doses logged that day', () {
      final m = med(
        'a',
        schedule: MedicineScheduleType.asNeeded,
        doses: const [],
      );
      final day = DateTime(2026, 10, 10);
      final at = DateTime(2026, 10, 10, 14, 30);
      final l = DoseLog(
        id: DoseLog.asNeededId('a', '2026-10-10', at),
        medicineId: 'a',
        dayKey: '2026-10-10',
        slotMinutes: 14 * 60 + 30,
        status: DoseStatus.taken,
        takenAt: at,
        createdAt: at,
        updatedAt: at,
      );
      final plan = MedicineSchedule.dayPlan([m], day, [l]);
      expect(plan, hasLength(1));
      expect(plan.single.isAsNeeded, true);
      expect(plan.single.minutes, 14 * 60 + 30);
    });
  });

  test('stock: units per day and days left', () {
    final m = med(
      'a',
      doses: const [DoseTime(480), DoseTime(1200, 0.5)],
      stock: 6,
    );
    expect(MedicineSchedule.unitsPerDay(m), 1.5);
    expect(MedicineSchedule.daysLeft(m), 4);
    final weekly = med(
      'b',
      schedule: MedicineScheduleType.specificDays,
      mask: 0x01,
      doses: const [DoseTime(480, 7)],
      stock: 3,
    );
    expect(MedicineSchedule.unitsPerDay(weekly), 1);
    expect(MedicineSchedule.daysLeft(weekly), 3);
    expect(MedicineSchedule.daysLeft(med('c')), isNull);
    expect(med('d', stock: 5, refillAt: 5).isLow, true);
    expect(med('e', stock: 6, refillAt: 5).isLow, false);
  });

  group('DoseSlot.stateAt', () {
    final m = med('a', doses: const [DoseTime(8 * 60)]);
    final day = DateTime(2026, 10, 10);
    DoseSlot slot([DoseLog? l]) =>
        DoseSlot(medicine: m, day: day, minutes: 480, quantity: 1, log: l);

    test('upcoming → due → missed as time passes', () {
      expect(slot().stateAt(DateTime(2026, 10, 10, 7)), DoseState.upcoming);
      expect(slot().stateAt(DateTime(2026, 10, 10, 9)), DoseState.due);
      expect(slot().stateAt(DateTime(2026, 10, 11, 9)), DoseState.missed);
      expect(slot().stateAt(DateTime(2026, 10, 9, 9)), DoseState.upcoming);
    });

    test('logged and snoozed', () {
      final now = DateTime(2026, 10, 10, 9);
      expect(slot(log(m, day, 480)).stateAt(now), DoseState.taken);
      expect(
        slot(log(m, day, 480, status: DoseStatus.skipped)).stateAt(now),
        DoseState.skipped,
      );
      final snoozed = log(
        m,
        day,
        480,
        status: DoseStatus.pending,
        snoozedUntil: DateTime(2026, 10, 10, 9, 10),
      );
      expect(slot(snoozed).stateAt(now), DoseState.snoozed);
      expect(
        slot(snoozed).stateAt(DateTime(2026, 10, 10, 9, 20)),
        DoseState.due,
      );
    });
  });

  group('MedicineStatsCalculator', () {
    // Two doses a day since Oct 18; now is Oct 23, 12:00.
    final m = med('a', start: DateTime(2026, 10, 18));
    final now = DateTime(2026, 10, 23, 12);

    test('a fully taken week: 100 %, streak of past days, next dose', () {
      final logs = [
        for (var d = 18; d <= 22; d++) ...[
          log(m, DateTime(2026, 10, d), 480),
          log(m, DateTime(2026, 10, d), 1200),
        ],
        log(m, DateTime(2026, 10, 23), 480),
      ];
      final s = MedicineStatsCalculator.compute(m, logs, now);
      expect(s.adherence, 1.0);
      // Today still has the 20:00 dose: it neither counts nor breaks.
      expect(s.streak, 5);
      expect(s.takenToday, 1);
      expect(s.dueToday, 2);
      expect(s.nextDose?.minutes, 20 * 60);
      expect(s.week, hasLength(7));
      expect(s.week.last.states, [DoseState.taken, DoseState.upcoming]);
      // History: only doses whose time has come, newest first.
      expect(s.history.first.minutes, 480);
      expect(s.history.first.day, DateTime(2026, 10, 23));
    });

    test('a missed dose breaks the streak and lowers adherence', () {
      final logs = [
        for (var d = 18; d <= 22; d++) ...[
          log(m, DateTime(2026, 10, d), 480),
          if (d != 21) log(m, DateTime(2026, 10, d), 1200),
        ],
      ];
      final s = MedicineStatsCalculator.compute(m, logs, now);
      expect(s.streak, 1); // Oct 22 only; Oct 21's evening was missed
      // 9 taken of 10 past doses + today's 08:00 missed? No: today's 08:00
      // is "due", which is not counted.
      expect(s.adherence, closeTo(9 / 10, 1e-9));
    });

    test('nothing due yet → no adherence', () {
      final fresh = med('b', start: DateTime(2026, 10, 23));
      final s = MedicineStatsCalculator.compute(
        fresh,
        const [],
        DateTime(2026, 10, 23, 7),
      );
      expect(s.adherence, isNull);
      expect(s.streak, 0);
    });
  });

  test('wording: amounts and schedules', () {
    expect(MedicineWords.number(1), '1');
    expect(MedicineWords.number(0.5), '0.5');
    expect(MedicineWords.number(2.25), '2.25');
    expect(MedicineWords.amount(1, MedicineForm.tablet), '1 tablet');
    expect(MedicineWords.amount(2, MedicineForm.tablet), '2 tablets');
    expect(MedicineWords.amount(0.5, MedicineForm.tablet), '0.5 tablets');
    expect(MedicineWords.amount(5, MedicineForm.liquid), '5 ml');
    expect(MedicineWords.amount(2, MedicineForm.inhaler), '2 puffs');
    expect(MedicineWords.weekdays(0x1F), 'Weekdays');
    expect(MedicineWords.weekdays(0x7F), 'Every day');
    final m = med('a', schedule: MedicineScheduleType.everyNDays, everyN: 3);
    expect(MedicineWords.schedule(m), 'Every 3 days');
    expect(
      MedicineWords.doseLine(
        med('b').copyWith(strength: '500 mg', foodTiming: FoodTiming.afterFood),
        1,
      ),
      '500 mg · 1 tablet · after food',
    );
  });
}
