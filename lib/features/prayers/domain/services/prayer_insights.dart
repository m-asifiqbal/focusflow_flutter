/// ============================================================
/// PRAYER INSIGHTS — analytics for Insights › Prayer
/// ============================================================
///
/// Pure function of the active prayers, their logs, a period and "now":
///   • every due prayer whose window has ended is ON TIME, LATE, MADE UP,
///     MISSED (never marked) or EXCUSED — the same rule as the Prayer
///     tab's progress ([PrayerStats.cellsFor]);
///   • [PrayerPeriod] picks the window and the chart buckets, like
///     Insights › Medicine: Daily = the last 7 days by day, Monthly = the
///     last 30 days by day, Yearly = the last 12 months by month; the
///     window right before it gives the deltas;
///   • per prayer, the best run of complete days, prayers in congregation,
///     where they were prayed, fasts kept and the dhikr tally;
///   • the Venn of days and the "when you pray" rows (prayer_timing.dart).
/// Fasts and counting practices are counted on their own, never in the
/// prayer outcomes (a missed fast is not a missed prayer). Excused days
/// are shown but never lower a rate.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_timing.dart';

enum PrayerPeriod { daily, monthly, yearly }

/// How the due prayers of a window ended.
@immutable
class PrayerCounts {
  const PrayerCounts({
    this.onTime = 0,
    this.late = 0,
    this.madeUp = 0,
    this.missed = 0,
    this.excused = 0,
  });

  static const zero = PrayerCounts();

  final int onTime;
  final int late;
  final int madeUp;
  final int missed;
  final int excused;

  int get done => onTime + late + madeUp;

  /// Prayers that count towards the rates (excused ones don't).
  int get due => done + missed;
  int get total => due + excused;
  bool get isEmpty => total == 0;

  /// Done ÷ due (null when nothing was due).
  double? get completion => due == 0 ? null : done / due;

  /// On time ÷ due (null when nothing was due).
  double? get onTimeRate => due == 0 ? null : onTime / due;

  PrayerCounts add(PrayerCell c) => switch (c) {
    PrayerCell.onTime => _with(onTime: 1),
    PrayerCell.late => _with(late: 1),
    PrayerCell.madeUp => _with(madeUp: 1),
    PrayerCell.missed => _with(missed: 1),
    PrayerCell.excused => _with(excused: 1),
    PrayerCell.pending || PrayerCell.none => this,
  };

  PrayerCounts _with({
    int onTime = 0,
    int late = 0,
    int madeUp = 0,
    int missed = 0,
    int excused = 0,
  }) => PrayerCounts(
    onTime: this.onTime + onTime,
    late: this.late + late,
    madeUp: this.madeUp + madeUp,
    missed: this.missed + missed,
    excused: this.excused + excused,
  );

  @override
  bool operator ==(Object other) =>
      other is PrayerCounts &&
      other.onTime == onTime &&
      other.late == late &&
      other.madeUp == madeUp &&
      other.missed == missed &&
      other.excused == excused;

  @override
  int get hashCode => Object.hash(onTime, late, madeUp, missed, excused);
}

/// One bar of the chart: a day (Daily / Monthly) or a month (Yearly).
@immutable
class PrayerBucket {
  const PrayerBucket({required this.start, required this.counts});

  final DateTime start;
  final PrayerCounts counts;

  @override
  bool operator ==(Object other) =>
      other is PrayerBucket && other.start == start && other.counts == counts;

  @override
  int get hashCode => Object.hash(start, counts);
}

/// One prayer's row of the per-prayer card.
@immutable
class PrayerShare {
  const PrayerShare({required this.prayer, required this.counts});

  final Prayer prayer;
  final PrayerCounts counts;

  @override
  bool operator ==(Object other) =>
      other is PrayerShare &&
      other.prayer.id == prayer.id &&
      other.prayer.name == prayer.name &&
      other.counts == counts;

  @override
  int get hashCode => Object.hash(prayer.id, prayer.name, counts);
}

@immutable
class PrayerInsights {
  const PrayerInsights({
    required this.period,
    required this.start,
    required this.end,
    required this.counts,
    required this.previous,
    required this.buckets,
    required this.perPrayer,
    required this.completeDays,
    required this.trackedDays,
    required this.bestStreak,
    required this.congregation,
    required this.fastsKept,
    required this.fastsDue,
    required this.dhikrTotal,
    required this.dhikrGoalDays,
    required this.places,
    this.venn = PrayerVenn.zero,
    this.timing = const [],
  });

  final PrayerPeriod period;

  /// First day of the window and the day after its last.
  final DateTime start;
  final DateTime end;
  final PrayerCounts counts;

  /// The window of the same length right before (deltas).
  final PrayerCounts previous;
  final List<PrayerBucket> buckets;

  /// Prayers due in the window, in the order of the day (earliest first).
  final List<PrayerShare> perPrayer;

  /// Days on which every due prayer was done or excused.
  final int completeDays;

  /// Days with at least one prayer due (so far).
  final int trackedDays;

  /// Longest run of complete days in the window.
  final int bestStreak;

  /// Prayers done in congregation.
  final int congregation;

  /// Fast days kept (fasted or made up) out of the fast days due.
  final int fastsKept;
  final int fastsDue;

  /// Counting practices: the tally and the days the goal was reached.
  final int dhikrTotal;
  final int dhikrGoalDays;

  /// Where done prayers were prayed, most frequent first (top 4).
  final List<(String, int)> places;

  /// Days by the outcomes they had.
  final PrayerVenn venn;

  /// Each prayer's typical window and mark times, in the order of the day.
  final List<PrayerTiming> timing;

  bool get hasData =>
      !counts.isEmpty || fastsDue > 0 || fastsKept > 0 || dhikrTotal > 0;

  static const _eq = ListEquality<Object>();

  @override
  bool operator ==(Object other) =>
      other is PrayerInsights &&
      other.period == period &&
      other.start == start &&
      other.end == end &&
      other.counts == counts &&
      other.previous == previous &&
      _eq.equals(other.buckets, buckets) &&
      _eq.equals(other.perPrayer, perPrayer) &&
      other.completeDays == completeDays &&
      other.trackedDays == trackedDays &&
      other.bestStreak == bestStreak &&
      other.congregation == congregation &&
      other.fastsKept == fastsKept &&
      other.fastsDue == fastsDue &&
      other.dhikrTotal == dhikrTotal &&
      other.dhikrGoalDays == dhikrGoalDays &&
      _eq.equals(other.places, places) &&
      other.venn == venn &&
      _eq.equals(other.timing, timing);

  @override
  int get hashCode => Object.hash(
    period,
    start,
    counts,
    previous,
    _eq.hash(buckets),
    _eq.hash(perPrayer),
    bestStreak,
    congregation,
    fastsKept,
    dhikrTotal,
    _eq.hash(places),
    venn,
    _eq.hash(timing),
  );
}

abstract final class PrayerInsightsCalculator {
  /// `[start, end)` of [period] ending today.
  static (DateTime, DateTime) window(PrayerPeriod period, DateTime today) {
    final t = DateUtilsX.dateOnly(today);
    final end = DateUtilsX.addDays(t, 1);
    return switch (period) {
      PrayerPeriod.daily => (DateUtilsX.addDays(t, -6), end),
      PrayerPeriod.monthly => (DateUtilsX.addDays(t, -29), end),
      PrayerPeriod.yearly => (DateTime(t.year, t.month - 11), end),
    };
  }

  /// The window before [window] of the same length (yearly: 12 months).
  static (DateTime, DateTime) previousWindow(
    PrayerPeriod period,
    (DateTime, DateTime) window,
  ) {
    final (start, end) = window;
    if (period == PrayerPeriod.yearly) {
      return (DateTime(start.year - 1, start.month), start);
    }
    final days = DateUtilsX.daysBetween(start, end);
    return (DateUtilsX.addDays(start, -days), start);
  }

  /// Insights of [period] at [now] from [prayers] (active ones count) and
  /// their [logs] (covering [previousWindow] to today). [sunFor] gives any
  /// day's sun times for the windows of the timing rows (defaults to
  /// [sunToday] for every day).
  static PrayerInsights compute({
    required List<Prayer> prayers,
    required List<PrayerLog> logs,
    required PrayerPeriod period,
    required DateTime now,
    SolarDay? sunToday,
    SolarDay? sunTomorrow,
    SolarDay? Function(DateTime day)? sunFor,
  }) {
    final win = window(period, now);
    final prev = previousWindow(period, win);
    final active = [
      for (final p in prayers)
        if (p.isActive) p,
    ];
    final tracked = [
      for (final p in active)
        if (!p.kind.isFast && !p.kind.counts) p,
    ]..sort(_byTimeOfDay);
    final fasts = [
      for (final p in active)
        if (p.kind.isFast) p,
    ];
    final cell = PrayerStats.cellsFor(
      prayers: active,
      logs: logs,
      now: now,
      sunToday: sunToday,
      sunTomorrow: sunTomorrow,
    );
    final today = DateUtilsX.dateOnly(now);
    int bucketOf(DateTime d) => period == PrayerPeriod.yearly
        ? d.year * 12 + d.month - 1
        : DateUtilsX.dayNumber(d);

    var counts = PrayerCounts.zero;
    final perPrayer = <String, PrayerCounts>{};
    final byBucket = <int, PrayerCounts>{};
    var complete = 0, trackedDays = 0, best = 0, run = 0;
    var fastsKept = 0, fastsDue = 0;
    final vennMasks = List.filled(8, 0);
    for (
      var day = win.$1;
      day.isBefore(win.$2) && !day.isAfter(today);
      day = DateUtilsX.addDays(day, 1)
    ) {
      var dayDue = 0, dayOk = 0, mask = 0;
      var open = false;
      for (final p in tracked) {
        final c = cell(p, day);
        if (c == PrayerCell.none) continue;
        if (c == PrayerCell.pending) {
          open = true;
          continue;
        }
        counts = counts.add(c);
        perPrayer[p.id] = (perPrayer[p.id] ?? PrayerCounts.zero).add(c);
        final b = bucketOf(day);
        byBucket[b] = (byBucket[b] ?? PrayerCounts.zero).add(c);
        dayDue++;
        if (c != PrayerCell.missed) dayOk++;
        mask |= PrayerVenn.maskOf(c);
      }
      for (final p in fasts) {
        final c = cell(p, day);
        if (c == PrayerCell.onTime || c == PrayerCell.madeUp) fastsKept++;
        if (c == PrayerCell.onTime ||
            c == PrayerCell.madeUp ||
            c == PrayerCell.late ||
            c == PrayerCell.missed) {
          fastsDue++;
        }
      }
      if (dayDue == 0) continue;
      vennMasks[mask]++;
      trackedDays++;
      if (dayOk == dayDue && !open) {
        complete++;
        run++;
        if (run > best) best = run;
      } else if (dayOk < dayDue) {
        run = 0;
      }
    }

    var previous = PrayerCounts.zero;
    for (
      var day = prev.$1;
      day.isBefore(prev.$2);
      day = DateUtilsX.addDays(day, 1)
    ) {
      for (final p in tracked) {
        previous = previous.add(cell(p, day));
      }
    }

    // Logs: congregation, places, dhikr.
    final byId = {for (final p in active) p.id: p};
    final startNo = DateUtilsX.dayNumber(win.$1);
    final endNo = DateUtilsX.dayNumber(win.$2);
    var congregation = 0, dhikr = 0, goalDays = 0;
    final places = <String, int>{};
    for (final l in logs) {
      final p = byId[l.prayerId];
      if (p == null) continue;
      final n = DateUtilsX.dayNumber(l.day);
      if (n < startNo || n >= endNo) continue;
      if (p.kind.counts) {
        dhikr += l.count;
        final goal = p.targetCount;
        if (goal != null && goal > 0 && l.count >= goal) goalDays++;
        continue;
      }
      if (p.kind.isFast || !l.status.done) continue;
      if (l.congregation) congregation++;
      final place = (l.place ?? p.place).trim();
      if (place.isNotEmpty) {
        places[place] = (places[place] ?? 0) + 1;
      }
    }
    final topPlaces = [for (final e in places.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return PrayerInsights(
      period: period,
      start: win.$1,
      end: win.$2,
      counts: counts,
      previous: previous,
      buckets: _buckets(period, win, byBucket, bucketOf),
      perPrayer: List.unmodifiable([
        for (final p in tracked)
          if (perPrayer[p.id] case final c? when !c.isEmpty)
            PrayerShare(prayer: p, counts: c),
      ]),
      completeDays: complete,
      trackedDays: trackedDays,
      bestStreak: best,
      congregation: congregation,
      fastsKept: fastsKept,
      fastsDue: fastsDue,
      dhikrTotal: dhikr,
      dhikrGoalDays: goalDays,
      places: List.unmodifiable(topPlaces.take(4)),
      venn: PrayerVenn.fromMasks(vennMasks),
      timing: PrayerTimingCalculator.compute(
        tracked: tracked,
        logs: logs,
        window: win,
        today: today,
        sunFor: sunFor ?? (_) => sunToday,
        step: switch (period) {
          PrayerPeriod.daily => 1,
          PrayerPeriod.monthly => 2,
          PrayerPeriod.yearly => 7,
        },
      ),
    );
  }

  static int _byTimeOfDay(Prayer a, Prayer b) {
    final c = a.start.minutes.compareTo(b.start.minutes);
    return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
  }

  static List<PrayerBucket> _buckets(
    PrayerPeriod period,
    (DateTime, DateTime) win,
    Map<int, PrayerCounts> byBucket,
    int Function(DateTime) bucketOf,
  ) {
    final out = <PrayerBucket>[];
    if (period == PrayerPeriod.yearly) {
      for (var i = 0; i < 12; i++) {
        final m = DateTime(win.$1.year, win.$1.month + i);
        out.add(
          PrayerBucket(
            start: m,
            counts: byBucket[bucketOf(m)] ?? PrayerCounts.zero,
          ),
        );
      }
    } else {
      for (var d = win.$1; d.isBefore(win.$2); d = DateUtilsX.addDays(d, 1)) {
        out.add(
          PrayerBucket(
            start: d,
            counts: byBucket[bucketOf(d)] ?? PrayerCounts.zero,
          ),
        );
      }
    }
    return List.unmodifiable(out);
  }
}
