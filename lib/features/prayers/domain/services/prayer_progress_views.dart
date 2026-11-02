/// ============================================================
/// PRAYER PROGRESS VIEWS — Day · Week · Month · Year on the Prayer page
/// ============================================================
///
/// What: the data behind the progress card's four views (Week is the
/// 7-day grid of [PrayerStats.compute]):
///   • Day — every prayer of one day with what happened and when it was
///     marked ([dayOf]);
///   • Month — every day of a calendar month with one cell per prayer
///     ([monthOf]);
///   • Year — the share of due prayers prayed on each of the last 53 weeks'
///     days (the heatmap) and each prayer's record over the last 12 months
///     ([yearOf]).
/// Same rules as the rest of Progress ([PrayerStats.cellsFor]): fasts and
/// counting practices are left out; excused and still-open prayers never
/// count as due.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

enum PrayerProgressView { day, week, month, year }

/// One prayer on the Day view.
@immutable
class PrayerDayEntry {
  const PrayerDayEntry({
    required this.prayer,
    required this.cell,
    this.loggedAt,
    this.congregation = false,
  });

  final Prayer prayer;
  final PrayerCell cell;

  /// When it was marked (null = not marked).
  final DateTime? loggedAt;
  final bool congregation;

  @override
  bool operator ==(Object other) =>
      other is PrayerDayEntry &&
      other.prayer == prayer &&
      other.cell == cell &&
      other.loggedAt == loggedAt &&
      other.congregation == congregation;

  @override
  int get hashCode => Object.hash(prayer, cell, loggedAt, congregation);
}

/// One day of the Month view: a cell per prayer due that day.
@immutable
class PrayerMonthDay {
  const PrayerMonthDay(this.day, this.cells);

  final DateTime day;
  final List<PrayerCell> cells;

  @override
  bool operator ==(Object other) =>
      other is PrayerMonthDay &&
      other.day == day &&
      listEquals(other.cells, cells);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(cells));
}

/// Done of due (excused and open prayers are not due).
@immutable
class PrayerRate {
  const PrayerRate(this.done, this.due);

  static const zero = PrayerRate(0, 0);

  final int done;
  final int due;

  /// 0..1, or null when nothing was due.
  double? get rate => due == 0 ? null : done / due;

  PrayerRate add(PrayerCell c) => switch (c) {
    PrayerCell.onTime ||
    PrayerCell.late ||
    PrayerCell.madeUp => PrayerRate(done + 1, due + 1),
    PrayerCell.missed => PrayerRate(done, due + 1),
    _ => this,
  };

  @override
  bool operator ==(Object other) =>
      other is PrayerRate && other.done == done && other.due == due;

  @override
  int get hashCode => Object.hash(done, due);
}

@immutable
class PrayerYear {
  const PrayerYear({
    required this.end,
    required this.daily,
    required this.perPrayer,
    required this.total,
  });

  static const int weeks = 53;

  /// Today (the heatmap's last day).
  final DateTime end;

  /// Share prayed per day (days with something due only).
  final Map<DateTime, double> daily;

  /// Each prayer's record over the last 12 months, in the order of the day.
  final List<(Prayer, PrayerRate)> perPrayer;
  final PrayerRate total;

  bool get isEmpty => total.due == 0;

  @override
  bool operator ==(Object other) =>
      other is PrayerYear &&
      other.end == end &&
      mapEquals(other.daily, daily) &&
      listEquals(other.perPrayer, perPrayer) &&
      other.total == total;

  @override
  int get hashCode =>
      Object.hash(end, daily.length, Object.hashAll(perPrayer), total);
}

abstract final class PrayerProgressViews {
  /// How many months back the Month view pages (the logs cover
  /// [PrayerStats.historyDays]).
  static const int monthsBack = 12;

  /// Prayers (not fasts or counters) in the order of the day.
  static List<Prayer> tracked(List<Prayer> prayers) => [
    for (final p in prayers)
      if (p.isActive && !p.kind.isFast && !p.kind.counts) p,
  ]..sort(_byTimeOfDay);

  static int _byTimeOfDay(Prayer a, Prayer b) {
    final c = a.start.minutes.compareTo(b.start.minutes);
    return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
  }

  /// Every prayer due on [day] with its outcome (pending while open).
  static List<PrayerDayEntry> dayOf({
    required List<Prayer> prayers,
    required List<PrayerLog> logs,
    required DateTime now,
    required DateTime day,
    SolarDay? sunToday,
    SolarDay? sunTomorrow,
    int hijriAdjust = 0,
  }) {
    final list = tracked(prayers);
    final cell = PrayerStats.cellsFor(
      prayers: list,
      logs: logs,
      now: now,
      sunToday: sunToday,
      sunTomorrow: sunTomorrow,
      hijriAdjust: hijriAdjust,
    );
    final byId = {for (final l in logs) l.id: l};
    final key = DateUtilsX.dayKey(day);
    final out = <PrayerDayEntry>[];
    for (final p in list) {
      final c = cell(p, day);
      if (c == PrayerCell.none) continue;
      final log = byId[PrayerLog.idFor(p.id, key)];
      final marked = log == null || log.status == PrayerStatus.pending
          ? null
          : log;
      out.add(
        PrayerDayEntry(
          prayer: p,
          cell: c,
          loggedAt: marked?.loggedAt,
          congregation:
              marked != null && marked.congregation && marked.status.done,
        ),
      );
    }
    return List.unmodifiable(out);
  }

  /// Every day of [month]'s calendar month (the 1st first); days after
  /// today have no cells.
  static List<PrayerMonthDay> monthOf({
    required List<Prayer> prayers,
    required List<PrayerLog> logs,
    required DateTime now,
    required DateTime month,
    SolarDay? sunToday,
    SolarDay? sunTomorrow,
    int hijriAdjust = 0,
  }) {
    final list = tracked(prayers);
    final cell = PrayerStats.cellsFor(
      prayers: list,
      logs: logs,
      now: now,
      sunToday: sunToday,
      sunTomorrow: sunTomorrow,
      hijriAdjust: hijriAdjust,
    );
    final first = DateTime(month.year, month.month);
    final next = DateTime(month.year, month.month + 1);
    return List.unmodifiable([
      for (var d = first; d.isBefore(next); d = DateUtilsX.addDays(d, 1))
        PrayerMonthDay(d, [
          for (final p in list)
            if (cell(p, d) case final c when c != PrayerCell.none) c,
        ]),
    ]);
  }

  /// The heatmap of the last [PrayerYear.weeks] weeks and each prayer's
  /// last 12 months.
  static PrayerYear yearOf({
    required List<Prayer> prayers,
    required List<PrayerLog> logs,
    required DateTime now,
    SolarDay? sunToday,
    SolarDay? sunTomorrow,
    int hijriAdjust = 0,
  }) {
    final list = tracked(prayers);
    final cell = PrayerStats.cellsFor(
      prayers: list,
      logs: logs,
      now: now,
      sunToday: sunToday,
      sunTomorrow: sunTomorrow,
      hijriAdjust: hijriAdjust,
    );
    final today = DateUtilsX.dateOnly(now);
    final yearStart = DateTime(today.year, today.month - 11);
    final rates = {for (final p in list) p.id: PrayerRate.zero};
    final daily = <DateTime, double>{};
    var total = PrayerRate.zero;
    for (var i = 0; i < PrayerYear.weeks * 7; i++) {
      final d = DateUtilsX.addDays(today, -i);
      var day = PrayerRate.zero;
      for (final p in list) {
        final c = cell(p, d);
        day = day.add(c);
        if (!d.isBefore(yearStart)) rates[p.id] = rates[p.id]!.add(c);
      }
      if (day.rate case final r?) daily[d] = r;
      if (!d.isBefore(yearStart)) {
        total = PrayerRate(total.done + day.done, total.due + day.due);
      }
    }
    return PrayerYear(
      end: today,
      daily: Map.unmodifiable(daily),
      perPrayer: List.unmodifiable([
        for (final p in list)
          if (rates[p.id]!.due > 0) (p, rates[p.id]!),
      ]),
      total: total,
    );
  }
}
