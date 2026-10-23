/// Insights › Medicine numbers: on time vs late vs skipped vs missed, the
/// period windows and buckets, the Venn of days, perfect days and runs,
/// time of day, per medicine, and fairness (paused / archived / future).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';

final _t0 = DateTime(2026, 1, 1);

Medicine _med(
  String id, {
  List<DoseTime> doses = const [DoseTime(8 * 60), DoseTime(20 * 60)],
  DateTime? start,
  bool paused = false,
  DateTime? archivedAt,
}) => Medicine(
  id: id,
  name: id,
  doses: doses,
  startDate: start ?? DateTime(2026, 10, 1),
  isPaused: paused,
  archivedAt: archivedAt,
  createdAt: _t0,
  updatedAt: _t0,
);

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A dose of [m] on [day] at [minutes]; [lateBy] minutes after its time.
DoseLog _log(
  Medicine m,
  DateTime day,
  int minutes, {
  int lateBy = 0,
  bool skipped = false,
}) => DoseLog(
  id: DoseLog.idFor(m.id, _key(day), minutes),
  medicineId: m.id,
  dayKey: _key(day),
  slotMinutes: minutes,
  status: skipped ? DoseStatus.skipped : DoseStatus.taken,
  takenAt: DateTime(
    day.year,
    day.month,
    day.day,
  ).add(Duration(minutes: minutes + lateBy)),
  createdAt: _t0,
  updatedAt: _t0,
);

MedicineInsights _compute(
  List<Medicine> meds,
  List<DoseLog> logs, {
  MedicinePeriod period = MedicinePeriod.daily,
  DateTime? now,
}) => MedicineInsightsCalculator.compute(
  medicines: meds,
  logs: logs,
  period: period,
  now: now ?? DateTime(2026, 10, 23, 23, 30),
);

void main() {
  test('windows: daily 7 days, monthly 30 days, yearly 12 months', () {
    final today = DateTime(2026, 10, 23);
    expect(MedicineInsightsCalculator.window(MedicinePeriod.daily, today), (
      DateTime(2026, 10, 17),
      DateTime(2026, 10, 24),
    ));
    expect(
      MedicineInsightsCalculator.window(MedicinePeriod.monthly, today).$1,
      DateTime(2026, 9, 24),
    );
    expect(
      MedicineInsightsCalculator.window(MedicinePeriod.yearly, today).$1,
      DateTime(2025, 11),
    );
  });

  test('outcomes: on time, late, skipped, missed', () {
    final m = _med('a', start: DateTime(2026, 10, 23));
    final day = DateTime(2026, 10, 23);
    // 08:00 taken 2 h late; 20:00 never logged → missed (it is 23:30).
    var s = _compute([m], [_log(m, day, 480, lateBy: 120)]);
    expect(s.counts, const DoseCounts(late: 1, missed: 1));
    expect(s.counts.adherence, 0.5);
    // 08:00 on time (10 min), 20:00 skipped.
    s = _compute(
      [m],
      [_log(m, day, 480, lateBy: 10), _log(m, day, 1200, skipped: true)],
    );
    expect(s.counts, const DoseCounts(onTime: 1, skipped: 1));
    expect(s.counts.onTimeRate, 1.0);
  });

  test('doses still ahead today are not missed yet', () {
    final m = _med('a', start: DateTime(2026, 10, 23));
    final s = _compute(
      [m],
      [_log(m, DateTime(2026, 10, 23), 480)],
      now: DateTime(2026, 10, 23, 12),
    );
    expect(s.counts, const DoseCounts(onTime: 1));
  });

  test('daily buckets, venn of days, perfect days and best run', () {
    final m = _med('a', start: DateTime(2026, 10, 17));
    final logs = [
      for (var d = 17; d <= 23; d++) ...[
        // Oct 20: evening late; Oct 21: evening missed.
        _log(m, DateTime(2026, 10, d), 480),
        if (d == 20) _log(m, DateTime(2026, 10, d), 1200, lateBy: 90),
        if (d != 20 && d != 21) _log(m, DateTime(2026, 10, d), 1200),
      ],
    ];
    final s = _compute([m], logs);
    expect(s.buckets, hasLength(7));
    expect(s.buckets.first.start, DateTime(2026, 10, 17));
    expect(s.buckets[4].counts, const DoseCounts(onTime: 1, missed: 1));
    expect(s.venn.onTimeOnly, 5);
    expect(s.venn.onTimeLate, 1);
    expect(s.venn.onTimeMissed, 1);
    expect(s.venn.days, 7);
    expect(s.perfectDays, 6);
    expect(s.bestStreak, 4); // Oct 17–20 (late still counts), then 22–23
    expect(s.timeOfDay.morning, 7);
    expect(s.timeOfDay.evening, 6);
  });

  test('yearly buckets are months', () {
    final m = _med(
      'a',
      doses: const [DoseTime(8 * 60)],
      start: DateTime(2026, 10, 1),
    );
    final s = _compute(
      [m],
      [_log(m, DateTime(2026, 10, 5), 480)],
      period: MedicinePeriod.yearly,
    );
    expect(s.buckets, hasLength(12));
    expect(s.buckets.last.start, DateTime(2026, 10));
    expect(s.buckets.last.counts.onTime, 1);
    // Oct 1–23, one dose a day, one taken.
    expect(s.buckets.last.counts.total, 23);
    expect(s.buckets.first.counts.isEmpty, isTrue);
  });

  test('paused counts only what was logged; archived stops at its day', () {
    final paused = _med('p', start: DateTime(2026, 10, 17), paused: true);
    final archived = _med(
      'x',
      doses: const [DoseTime(8 * 60)],
      start: DateTime(2026, 10, 17),
      archivedAt: DateTime(2026, 10, 18, 12),
    );
    final s = _compute(
      [paused, archived],
      [_log(paused, DateTime(2026, 10, 20), 480)],
    );
    // Paused: one logged dose, nothing missed. Archived: Oct 17 + 18 missed.
    expect(s.counts, const DoseCounts(onTime: 1, missed: 2));
    expect(
      s.perMedicine.map((p) => p.medicine.id),
      ['x', 'p'], // weakest first
    );
  });

  test(
    'previous window gives the deltas; as-needed doses are counted apart',
    () {
      final m = _med(
        'a',
        doses: const [DoseTime(480)],
        start: DateTime(2026, 10, 10),
      );
      final asNeeded = DoseLog(
        id: DoseLog.asNeededId('a', '2026-10-22', DateTime(2026, 10, 22, 15)),
        medicineId: 'a',
        dayKey: '2026-10-22',
        slotMinutes: 900,
        status: DoseStatus.taken,
        takenAt: DateTime(2026, 10, 22, 15),
        createdAt: _t0,
        updatedAt: _t0,
      );
      final s = _compute([m], [_log(m, DateTime(2026, 10, 12), 480), asNeeded]);
      // Previous window Oct 10–16: 7 due, 1 taken.
      expect(s.previous.total, 7);
      expect(s.previous.taken, 1);
      expect(s.asNeededTaken, 1);
      expect(s.hasData, isTrue);
    },
  );
}
