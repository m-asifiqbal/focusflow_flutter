/// Medicine detail calendar: the day-by-day dose states of a span, how a day
/// folds into one outcome, and where a course sits on the insights Gantt.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_calendar.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_gantt_card.dart';

final _t0 = DateTime(2026, 1, 1);
final _now = DateTime(2026, 10, 15, 12);

Medicine _med({
  DateTime? start,
  DateTime? end,
  DateTime? archivedAt,
  bool paused = false,
  List<DoseTime> doses = const [DoseTime(8 * 60), DoseTime(20 * 60)],
}) => Medicine(
  id: 'm',
  name: 'Metformin',
  doses: doses,
  startDate: start ?? DateTime(2026, 10, 1),
  endDate: end,
  isPaused: paused,
  archivedAt: archivedAt,
  createdAt: _t0,
  updatedAt: _t0,
);

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DoseLog _taken(Medicine m, DateTime day, int minutes, {bool skipped = false}) =>
    DoseLog(
      id: DoseLog.idFor(m.id, _key(day), minutes),
      medicineId: m.id,
      dayKey: _key(day),
      slotMinutes: minutes,
      status: skipped ? DoseStatus.skipped : DoseStatus.taken,
      takenAt: DateTime(day.year, day.month, day.day, 0, minutes),
      createdAt: _t0,
      updatedAt: _t0,
    );

void main() {
  group('MedicineCalendar.days', () {
    test('one entry per day, with the states of its doses', () {
      final m = _med();
      final logs = [
        _taken(m, DateTime(2026, 10, 12), 8 * 60),
        _taken(m, DateTime(2026, 10, 12), 20 * 60),
        _taken(m, DateTime(2026, 10, 13), 8 * 60, skipped: true),
      ];
      final days = MedicineCalendar.days(
        m,
        logs,
        DateTime(2026, 10, 11),
        DateTime(2026, 10, 16),
        _now,
      );
      expect(days, hasLength(6));
      expect(days.first.day, DateTime(2026, 10, 11));
      // 11th: nothing logged → both missed.
      expect(days[0].states, [DoseState.missed, DoseState.missed]);
      expect(days[1].states, [DoseState.taken, DoseState.taken]);
      expect(days[2].states, [DoseState.skipped, DoseState.missed]);
      // 15th at noon: 08:00 is due, 20:00 still to come.
      expect(days[4].states, [DoseState.due, DoseState.upcoming]);
      // The future.
      expect(days[5].states, [DoseState.upcoming, DoseState.upcoming]);
    });

    test('nothing before the start date or after the end date', () {
      final m = _med(
        start: DateTime(2026, 10, 13),
        end: DateTime(2026, 10, 14),
      );
      final days = MedicineCalendar.days(
        m,
        const [],
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 15),
        _now,
      );
      expect([for (final d in days) d.states.length], [0, 2, 2, 0]);
    });

    test('a pause does not rewrite history', () {
      final m = _med(paused: true);
      final days = MedicineCalendar.days(
        m,
        const [],
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 12),
        _now,
      );
      expect(days.single.states, [DoseState.missed, DoseState.missed]);
    });

    test('ignores logs of other medicines and caps a span at a year', () {
      final m = _med(start: DateTime(2020));
      final other = DoseLog(
        id: DoseLog.idFor('other', '2026-10-12', 480),
        medicineId: 'other',
        dayKey: '2026-10-12',
        slotMinutes: 480,
        status: DoseStatus.taken,
        createdAt: _t0,
        updatedAt: _t0,
      );
      final days = MedicineCalendar.days(
        m,
        [other],
        DateTime(2020),
        DateTime(2026),
        _now,
      );
      expect(days, hasLength(MedicineCalendar.maxDays));
      expect(
        MedicineCalendar.days(
          m,
          const [],
          DateTime(2026, 2),
          DateTime(2026, 1),
          _now,
        ),
        isEmpty,
      );
    });
  });

  group('DayOutcome.of', () {
    test('folds a day into one word', () {
      DayOutcome o(List<DoseState> s) => DayOutcome.of(s);
      expect(o(const []), DayOutcome.none);
      expect(o(const [DoseState.taken, DoseState.taken]), DayOutcome.taken);
      expect(o(const [DoseState.taken, DoseState.missed]), DayOutcome.partial);
      expect(
        o(const [DoseState.taken, DoseState.upcoming]),
        DayOutcome.partial,
      );
      expect(o(const [DoseState.missed, DoseState.missed]), DayOutcome.missed);
      expect(o(const [DoseState.missed, DoseState.skipped]), DayOutcome.missed);
      expect(o(const [DoseState.skipped]), DayOutcome.skipped);
      expect(o(const [DoseState.upcoming]), DayOutcome.pending);
      expect(o(const [DoseState.due, DoseState.snoozed]), DayOutcome.pending);
    });
  });

  group('Gantt span of a course', () {
    MedicineInsights insights(MedicinePeriod p) =>
        MedicineInsightsCalculator.compute(
          medicines: const [],
          logs: const [],
          period: p,
          now: _now,
        );

    test('daily: 7 days ending today', () {
      final i = insights(MedicinePeriod.daily); // Oct 9 – Oct 15
      expect(medicineAxisUnits(i), 7);
      final inside = medicineGanttSpan(
        _med(start: DateTime(2026, 10, 11), end: DateTime(2026, 10, 13)),
        i,
      )!;
      expect((inside.start, inside.end), (2, 4));
      expect((inside.before, inside.after), (false, false));
      // Started earlier, no end: runs through the whole axis, open both ways.
      final open = medicineGanttSpan(_med(start: DateTime(2026, 9, 1)), i)!;
      expect((open.start, open.end), (0, 6));
      expect((open.before, open.after), (true, true));
      // Archived on the 12th: stops there.
      final archived = medicineGanttSpan(
        _med(
          start: DateTime(2026, 10, 1),
          archivedAt: DateTime(2026, 10, 12, 9),
        ),
        i,
      )!;
      expect((archived.end, archived.after), (3, false));
    });

    test('a course outside the period has no span', () {
      final i = insights(MedicinePeriod.daily);
      expect(
        medicineGanttSpan(
          _med(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 20)),
          i,
        ),
        isNull,
      );
      expect(medicineGanttSpan(_med(start: DateTime(2026, 11, 1)), i), isNull);
    });

    test('yearly: 12 month cells', () {
      final i = insights(MedicinePeriod.yearly); // Nov 2025 – Oct 2026
      expect(medicineAxisUnits(i), 12);
      final s = medicineGanttSpan(
        _med(start: DateTime(2026, 3, 10), end: DateTime(2026, 6, 1)),
        i,
      )!;
      expect((s.start, s.end), (4, 7));
      expect(medicineAxisTicks(i), hasLength(12));
    });

    test('axis labels: weekday initials, every 5th day, month initials', () {
      expect(medicineAxisTicks(insights(MedicinePeriod.daily)), hasLength(7));
      expect(
        medicineAxisTicks(insights(MedicinePeriod.monthly)).map((t) => t.unit),
        [0, 5, 10, 15, 20, 25],
      );
    });
  });

  test('MedicineLogSpan has value equality', () {
    final a = MedicineLogSpan('m', DateTime(2026, 10), DateTime(2026, 10, 31));
    final b = MedicineLogSpan('m', DateTime(2026, 10), DateTime(2026, 10, 31));
    expect(a, b);
    expect({a: 1}[b], 1);
    expect(
      a == MedicineLogSpan('m', DateTime(2026, 9), DateTime(2026, 9, 30)),
      isFalse,
    );
  });
}
