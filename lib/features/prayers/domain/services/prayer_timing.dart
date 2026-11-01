/// ============================================================
/// PRAYER TIMING — the Venn of days and when prayers are marked
/// ============================================================
///
/// Two more shapes of Insights › Prayer, kept out of the main calculator:
///   • [PrayerVenn] counts *days* by the outcomes they had — ON TIME,
///     LATE / MADE UP, MISSED (a day can have several: it then sits in an
///     overlap). Excused prayers don't place a day anywhere.
///   • [PrayerTiming] (the Gantt rows): each prayer's typical window in the
///     period (the mean start / end of its days, sampled) and when the user
///     marked it — the median and the middle half (quartiles) of the mark
///     times of prayers kept on time or late. Made-up prayers are left out:
///     they are marked a day or more later and would drag the times away.
/// Times are minutes after the prayer's day's midnight on the wall clock
/// (DST-safe), so a night prayer ending after midnight reads past 24 h.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// Days counted by the outcomes they had (the three-circle Venn).
@immutable
class PrayerVenn {
  const PrayerVenn({
    this.onTimeOnly = 0,
    this.lateOnly = 0,
    this.missedOnly = 0,
    this.onTimeLate = 0,
    this.onTimeMissed = 0,
    this.lateMissed = 0,
    this.all = 0,
  });

  /// From region counts indexed by a 3-bit mask (1 on time, 2 late or
  /// made up, 4 missed) — see [maskOf].
  factory PrayerVenn.fromMasks(List<int> m) => PrayerVenn(
    onTimeOnly: m[1],
    lateOnly: m[2],
    missedOnly: m[4],
    onTimeLate: m[3],
    onTimeMissed: m[5],
    lateMissed: m[6],
    all: m[7],
  );

  static const zero = PrayerVenn();

  final int onTimeOnly;
  final int lateOnly;
  final int missedOnly;
  final int onTimeLate;
  final int onTimeMissed;
  final int lateMissed;
  final int all;

  /// Days that sit anywhere in the diagram.
  int get days =>
      onTimeOnly +
      lateOnly +
      missedOnly +
      onTimeLate +
      onTimeMissed +
      lateMissed +
      all;

  /// Days with a prayer late or made up but none missed.
  int get lateNotMissed => lateOnly + onTimeLate;

  /// Days with at least one prayer missed.
  int get withMissed => missedOnly + onTimeMissed + lateMissed + all;

  /// A cell's bit in the day mask (0 = places the day nowhere).
  static int maskOf(PrayerCell c) => switch (c) {
    PrayerCell.onTime => 1,
    PrayerCell.late || PrayerCell.madeUp => 2,
    PrayerCell.missed => 4,
    _ => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is PrayerVenn &&
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

/// One row of the "When you pray" Gantt.
@immutable
class PrayerTiming {
  const PrayerTiming({
    required this.prayer,
    required this.windowStart,
    required this.windowEnd,
    required this.marks,
    this.q1,
    this.median,
    this.q3,
  });

  final Prayer prayer;

  /// The mean window of the period's days, in minutes after midnight.
  final int windowStart;

  /// Null when the prayer has no end (only a start).
  final int? windowEnd;

  /// Prayers marked on time or late (the times below come from these).
  final int marks;

  /// Mark times: lower quartile, median, upper quartile (null = no marks).
  final int? q1;
  final int? median;
  final int? q3;

  @override
  bool operator ==(Object other) =>
      other is PrayerTiming &&
      other.prayer.id == prayer.id &&
      other.prayer.name == prayer.name &&
      other.windowStart == windowStart &&
      other.windowEnd == windowEnd &&
      other.marks == marks &&
      other.q1 == q1 &&
      other.median == median &&
      other.q3 == q3;

  @override
  int get hashCode => Object.hash(
    prayer.id,
    prayer.name,
    windowStart,
    windowEnd,
    marks,
    q1,
    median,
    q3,
  );
}

abstract final class PrayerTimingCalculator {
  /// The Gantt rows for [tracked] (in the order given) over `[start, end)`
  /// of [window] up to [today]. Windows are sampled every [step] days
  /// (the year view doesn't need 365 sun calculations); [sunFor] gives a
  /// day's sun times. Prayers not due on any sampled day are left out.
  static List<PrayerTiming> compute({
    required List<Prayer> tracked,
    required List<PrayerLog> logs,
    required (DateTime, DateTime) window,
    required DateTime today,
    required SolarDay? Function(DateTime day) sunFor,
    int step = 1,
  }) {
    final startNo = DateUtilsX.dayNumber(window.$1);
    final endNo = DateUtilsX.dayNumber(window.$2);
    final marks = <String, List<int>>{};
    for (final l in logs) {
      if (l.status != PrayerStatus.onTime && l.status != PrayerStatus.late) {
        continue;
      }
      final at = l.loggedAt;
      if (at == null) continue;
      final n = DateUtilsX.dayNumber(l.day);
      if (n < startNo || n >= endNo) continue;
      final m = minutesAfter(l.day, at);
      if (m < 0 || m >= 2 * Duration.minutesPerDay) continue;
      (marks[l.prayerId] ??= []).add(m);
    }

    var last = DateUtilsX.addDays(window.$2, -1);
    final t = DateUtilsX.dateOnly(today);
    if (last.isAfter(t)) last = t;
    final out = <PrayerTiming>[];
    for (final p in tracked) {
      var starts = 0, ends = 0, n = 0, nEnd = 0;
      final created = DateUtilsX.dateOnly(p.createdAt);
      for (
        var d = last;
        !d.isBefore(window.$1);
        d = DateUtilsX.addDays(d, -step)
      ) {
        if (d.isBefore(created) || !PrayerSchedule.isDueOn(p, d)) continue;
        final w = PrayerSchedule.windowOn(
          p,
          d,
          sunFor(d),
          nextSun: sunFor(DateUtilsX.addDays(d, 1)),
          prevSun: sunFor(DateUtilsX.addDays(d, -1)),
        );
        starts += minutesAfter(d, w.start);
        n++;
        if (w.end case final e?) {
          ends += minutesAfter(d, e);
          nEnd++;
        }
      }
      if (n == 0) continue;
      final m = (marks[p.id] ?? <int>[])..sort();
      out.add(
        PrayerTiming(
          prayer: p,
          windowStart: (starts / n).round(),
          windowEnd: nEnd == 0 ? null : (ends / nEnd).round(),
          marks: m.length,
          q1: m.isEmpty ? null : _quantile(m, 0.25),
          median: m.isEmpty ? null : _quantile(m, 0.5),
          q3: m.isEmpty ? null : _quantile(m, 0.75),
        ),
      );
    }
    return List.unmodifiable(out);
  }

  /// Wall-clock minutes from [day]'s midnight to [t] (next day = +1440).
  static int minutesAfter(DateTime day, DateTime t) =>
      DateUtilsX.daysBetween(DateUtilsX.dateOnly(day), DateUtilsX.dateOnly(t)) *
          Duration.minutesPerDay +
      t.hour * 60 +
      t.minute;

  /// The value at [q] of [sorted] (nearest rank).
  static int _quantile(List<int> sorted, double q) =>
      sorted[((sorted.length - 1) * q).round()];
}
