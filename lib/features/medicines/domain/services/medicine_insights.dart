/// ============================================================
/// MEDICINE INSIGHTS — adherence analytics for Insights › Medicine
/// ============================================================
///
/// Pure function of the medicines, their dose logs, a period and "now":
///   • every scheduled dose whose time has come is ON TIME (taken within
///     [MedicineInsightsCalculator.lateAfterMinutes] of its time, or
///     early), LATE, SKIPPED or MISSED (never logged);
///   • [MedicinePeriod] picks the window and the chart buckets: Daily = the
///     last 7 days by day, Monthly = the last 30 days by day, Yearly = the
///     last 12 months by month; the window before it gives the deltas;
///   • the Venn counts *days* by which outcomes they had (a day can have an
///     on-time dose, a late one and a missed one all at once);
///   • per medicine, time of day (when doses are taken), perfect days and
///     the longest run of them, as-needed doses logged.
/// Fairness: a paused medicine only counts what was logged (it was not
/// expected), an archived one stops at its archive day, nothing counts
/// before a medicine's start date.
/// Day loops work on day numbers; a DateTime is built only for due days.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';

enum MedicinePeriod { daily, monthly, yearly }

/// How the doses of a window ended.
@immutable
class DoseCounts {
  const DoseCounts({
    this.onTime = 0,
    this.late = 0,
    this.skipped = 0,
    this.missed = 0,
  });

  static const zero = DoseCounts();

  final int onTime;
  final int late;
  final int skipped;
  final int missed;

  int get taken => onTime + late;
  int get total => taken + skipped + missed;
  bool get isEmpty => total == 0;

  /// Taken ÷ due (null when nothing was due).
  double? get adherence => total == 0 ? null : taken / total;

  /// On time ÷ taken (null when nothing was taken).
  double? get onTimeRate => taken == 0 ? null : onTime / taken;

  DoseCounts operator +(DoseCounts o) => DoseCounts(
    onTime: onTime + o.onTime,
    late: late + o.late,
    skipped: skipped + o.skipped,
    missed: missed + o.missed,
  );

  @override
  bool operator ==(Object other) =>
      other is DoseCounts &&
      other.onTime == onTime &&
      other.late == late &&
      other.skipped == skipped &&
      other.missed == missed;

  @override
  int get hashCode => Object.hash(onTime, late, skipped, missed);

  @override
  String toString() => 'DoseCounts($onTime/$late/$skipped/$missed)';
}

/// One bar of the chart: a day (Daily / Monthly) or a month (Yearly).
@immutable
class DoseBucket {
  const DoseBucket({required this.start, required this.counts});

  final DateTime start;
  final DoseCounts counts;

  @override
  bool operator ==(Object other) =>
      other is DoseBucket && other.start == start && other.counts == counts;

  @override
  int get hashCode => Object.hash(start, counts);
}

/// Days counted by the outcomes they had (the three-circle Venn).
@immutable
class DoseVenn {
  const DoseVenn({
    this.onTimeOnly = 0,
    this.lateOnly = 0,
    this.missedOnly = 0,
    this.onTimeLate = 0,
    this.onTimeMissed = 0,
    this.lateMissed = 0,
    this.all = 0,
  });

  final int onTimeOnly;
  final int lateOnly;

  /// Missed or skipped only.
  final int missedOnly;
  final int onTimeLate;
  final int onTimeMissed;
  final int lateMissed;
  final int all;

  int get days =>
      onTimeOnly +
      lateOnly +
      missedOnly +
      onTimeLate +
      onTimeMissed +
      lateMissed +
      all;

  @override
  bool operator ==(Object other) =>
      other is DoseVenn &&
      other.onTimeOnly == onTimeOnly &&
      other.lateOnly == lateOnly &&
      other.missedOnly == missedOnly &&
      other.onTimeLate == onTimeLate &&
      other.onTimeMissed == onTimeMissed &&
      other.lateMissed == lateMissed &&
      other.all == all;

  @override
  int get hashCode => Object.hash(
    onTimeOnly,
    lateOnly,
    missedOnly,
    onTimeLate,
    onTimeMissed,
    lateMissed,
    all,
  );
}

/// Taken doses by the part of day they were due.
@immutable
class DoseTimeOfDay {
  const DoseTimeOfDay({this.morning = 0, this.afternoon = 0, this.evening = 0});

  final int morning;
  final int afternoon;
  final int evening;
  int get total => morning + afternoon + evening;

  @override
  bool operator ==(Object other) =>
      other is DoseTimeOfDay &&
      other.morning == morning &&
      other.afternoon == afternoon &&
      other.evening == evening;

  @override
  int get hashCode => Object.hash(morning, afternoon, evening);
}

/// One medicine's row of the per-medicine chart.
@immutable
class MedicineShare {
  const MedicineShare({required this.medicine, required this.counts});

  final Medicine medicine;
  final DoseCounts counts;

  @override
  bool operator ==(Object other) =>
      other is MedicineShare &&
      other.medicine.id == medicine.id &&
      other.medicine.name == medicine.name &&
      other.counts == counts;

  @override
  int get hashCode => Object.hash(medicine.id, medicine.name, counts);
}

@immutable
class MedicineInsights {
  const MedicineInsights({
    required this.period,
    required this.start,
    required this.end,
    required this.counts,
    required this.previous,
    required this.buckets,
    required this.perMedicine,
    required this.venn,
    required this.timeOfDay,
    required this.perfectDays,
    required this.daysWithDoses,
    required this.bestStreak,
    required this.asNeededTaken,
  });

  final MedicinePeriod period;

  /// First day of the window and the day after its last.
  final DateTime start;
  final DateTime end;
  final DoseCounts counts;

  /// The window of the same length right before (deltas).
  final DoseCounts previous;
  final List<DoseBucket> buckets;

  /// Medicines with doses in the window, lowest adherence first.
  final List<MedicineShare> perMedicine;
  final DoseVenn venn;
  final DoseTimeOfDay timeOfDay;

  /// Days on which every due dose was taken.
  final int perfectDays;

  /// Days with at least one dose due (so far).
  final int daysWithDoses;

  /// Longest run of perfect days in the window.
  final int bestStreak;
  final int asNeededTaken;

  bool get hasData => !counts.isEmpty || asNeededTaken > 0;

  static const _eq = ListEquality<Object>();

  @override
  bool operator ==(Object other) =>
      other is MedicineInsights &&
      other.period == period &&
      other.start == start &&
      other.end == end &&
      other.counts == counts &&
      other.previous == previous &&
      _eq.equals(other.buckets, buckets) &&
      _eq.equals(other.perMedicine, perMedicine) &&
      other.venn == venn &&
      other.timeOfDay == timeOfDay &&
      other.perfectDays == perfectDays &&
      other.daysWithDoses == daysWithDoses &&
      other.bestStreak == bestStreak &&
      other.asNeededTaken == asNeededTaken;

  @override
  int get hashCode => Object.hash(
    period,
    start,
    counts,
    previous,
    _eq.hash(buckets),
    _eq.hash(perMedicine),
    venn,
    perfectDays,
    bestStreak,
    asNeededTaken,
  );
}

abstract final class MedicineInsightsCalculator {
  /// A dose taken more than this many minutes after its time is late.
  static const int lateAfterMinutes = 60;

  /// `[start, end)` of [period] ending today.
  static (DateTime, DateTime) window(MedicinePeriod period, DateTime today) {
    final t = DateUtilsX.dateOnly(today);
    final end = DateUtilsX.addDays(t, 1);
    return switch (period) {
      MedicinePeriod.daily => (DateUtilsX.addDays(t, -6), end),
      MedicinePeriod.monthly => (DateUtilsX.addDays(t, -29), end),
      MedicinePeriod.yearly => (DateTime(t.year, t.month - 11), end),
    };
  }

  /// The window before [window] of the same length (yearly: 12 months).
  static (DateTime, DateTime) previousWindow(
    MedicinePeriod period,
    (DateTime, DateTime) window,
  ) {
    final (start, end) = window;
    if (period == MedicinePeriod.yearly) {
      return (DateTime(start.year - 1, start.month), start);
    }
    final days = DateUtilsX.daysBetween(start, end);
    return (DateUtilsX.addDays(start, -days), start);
  }

  static MedicineInsights compute({
    required List<Medicine> medicines,
    required List<DoseLog> logs,
    required MedicinePeriod period,
    required DateTime now,
  }) {
    final win = window(period, now);
    final prev = previousWindow(period, win);
    final byId = {for (final l in logs) l.id: l};
    final current = _Pass(medicines, byId, now, period, win.$1);
    current.run(win.$1, win.$2);
    final before = _Pass(medicines, byId, now, period, prev.$1)
      ..run(prev.$1, prev.$2);

    final startNo = DateUtilsX.dayNumber(win.$1);
    final endNo = DateUtilsX.dayNumber(win.$2);
    var asNeeded = 0;
    for (final l in logs) {
      if (!l.isAsNeeded || !l.isTaken) continue;
      final n = DateUtilsX.dayNumberOfKey(l.dayKey);
      if (n >= startNo && n < endNo) asNeeded++;
    }

    final shares =
        [
          for (final m in medicines)
            if (current.perMedicine[m.id] case final c? when !c.isEmpty)
              MedicineShare(medicine: m, counts: c),
        ]..sort(
          (a, b) =>
              (a.counts.adherence ?? 1).compareTo(b.counts.adherence ?? 1),
        );

    return MedicineInsights(
      period: period,
      start: win.$1,
      end: win.$2,
      counts: current.counts,
      previous: before.counts,
      buckets: current.buckets(win.$1, win.$2),
      perMedicine: List.unmodifiable(shares),
      venn: current.venn(),
      timeOfDay: DoseTimeOfDay(
        morning: current.tod[0],
        afternoon: current.tod[1],
        evening: current.tod[2],
      ),
      perfectDays: current.perfect,
      daysWithDoses: current.dueDays,
      bestStreak: current.bestRun,
      asNeededTaken: asNeeded,
    );
  }
}

/// One walk over a window's days.
class _Pass {
  _Pass(this.meds, this.byId, this.now, this.period, this.windowStart);

  final List<Medicine> meds;
  final Map<String, DoseLog> byId;
  final DateTime now;
  final MedicinePeriod period;
  final DateTime windowStart;

  var counts = DoseCounts.zero;
  final Map<String, DoseCounts> perMedicine = {};
  final Map<int, DoseCounts> _byBucket = {};
  final List<int> tod = [0, 0, 0];

  /// Venn region counts, indexed by the 3-bit outcome mask.
  final List<int> _venn = List.filled(8, 0);
  int perfect = 0;
  int dueDays = 0;
  int bestRun = 0;
  int _run = 0;

  int _bucketOf(DateTime day) => period == MedicinePeriod.yearly
      ? day.year * 12 + day.month - 1
      : DateUtilsX.dayNumber(day);

  void run(DateTime from, DateTime to) {
    final fromNo = DateUtilsX.dayNumber(from);
    final toNo = DateUtilsX.dayNumber(to);
    final todayNo = DateUtilsX.dayNumber(now);
    final starts = [for (final m in meds) DateUtilsX.dayNumber(m.startDate)];
    final archived = [
      for (final m in meds)
        m.archivedAt == null ? null : DateUtilsX.dayNumber(m.archivedAt!),
    ];
    for (var dayNo = fromNo; dayNo < toNo && dayNo <= todayNo; dayNo++) {
      DateTime? day;
      var mask = 0;
      var due = 0, taken = 0;
      for (var i = 0; i < meds.length; i++) {
        final m = meds[i];
        if (dayNo < starts[i]) continue;
        final arch = archived[i];
        if (arch != null && dayNo > arch) continue;
        if (!MedicineSchedule.isDueByNumber(m, dayNo, ignorePause: true)) {
          continue;
        }
        day ??= DateUtilsX.addDays(from, dayNo - fromNo);
        final key = DateUtilsX.dayKey(day);
        for (final d in m.doses) {
          final log = byId[DoseLog.idFor(m.id, key, d.minutes)];
          final slotAt = DateUtilsX.atMinutes(day, d.minutes);
          final DoseCounts c;
          if (log != null && log.isTaken) {
            final at = log.takenAt;
            final late =
                at != null &&
                at.difference(slotAt).inMinutes >
                    MedicineInsightsCalculator.lateAfterMinutes;
            c = late ? const DoseCounts(late: 1) : const DoseCounts(onTime: 1);
            mask |= late ? 2 : 1;
            taken++;
            tod[d.minutes < 12 * 60 ? 0 : (d.minutes < 17 * 60 ? 1 : 2)]++;
          } else if (log != null && log.isSkipped) {
            c = const DoseCounts(skipped: 1);
            mask |= 4;
          } else {
            // Not logged: a paused medicine wasn't expected; a dose still
            // ahead today isn't missed yet.
            if (m.isPaused || slotAt.isAfter(now)) continue;
            c = const DoseCounts(missed: 1);
            mask |= 4;
          }
          due++;
          counts = counts + c;
          perMedicine[m.id] = (perMedicine[m.id] ?? DoseCounts.zero) + c;
          final b = _bucketOf(day);
          _byBucket[b] = (_byBucket[b] ?? DoseCounts.zero) + c;
        }
      }
      if (due == 0) continue;
      dueDays++;
      _venn[mask]++;
      if (taken == due) {
        perfect++;
        _run++;
        if (_run > bestRun) bestRun = _run;
      } else if (dayNo < todayNo || mask & 4 != 0) {
        _run = 0;
      }
    }
  }

  List<DoseBucket> buckets(DateTime from, DateTime to) {
    if (period == MedicinePeriod.yearly) {
      return [
        for (var i = 0; i < 12; i++)
          () {
            final start = DateTime(from.year, from.month + i);
            return DoseBucket(
              start: start,
              counts: _byBucket[_bucketOf(start)] ?? DoseCounts.zero,
            );
          }(),
      ];
    }
    final days = DateUtilsX.daysBetween(from, to);
    return [
      for (var i = 0; i < days; i++)
        () {
          final day = DateUtilsX.addDays(from, i);
          return DoseBucket(
            start: day,
            counts: _byBucket[_bucketOf(day)] ?? DoseCounts.zero,
          );
        }(),
    ];
  }

  DoseVenn venn() => DoseVenn(
    onTimeOnly: _venn[1],
    lateOnly: _venn[2],
    missedOnly: _venn[4],
    onTimeLate: _venn[3],
    onTimeMissed: _venn[5],
    lateMissed: _venn[6],
    all: _venn[7],
  );
}
