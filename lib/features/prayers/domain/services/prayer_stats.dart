/// ============================================================
/// PRAYER STATS — streak, on-time rate, month, week grid
/// ============================================================
///
/// What: the "Progress" part of the Prayer tab, from the active prayers and
/// their logs: the streak of complete days, the on-time rate of the last 30
/// days, this month's done / due, congregation and fasting days, dhikr
/// total, and a 7-day grid (one row per prayer).
/// Why: pure and cheap — past days need only the logs (a day without a log
/// after its window is "missed"), so sun times are computed for today only.
/// Fasts and counting practices are counted on their own, never in the
/// streak or the on-time rate (a missed fast is not a missed prayer).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// One cell of the week grid.
enum PrayerCell {
  onTime,
  late,
  madeUp,
  missed,
  excused,

  /// Today, still open or upcoming.
  pending,

  /// Not due that day.
  none,
}

@immutable
class PrayerWeekRow {
  const PrayerWeekRow(this.prayer, this.cells);

  final Prayer prayer;

  /// One per day of [PrayerProgress.weekDays].
  final List<PrayerCell> cells;

  @override
  bool operator ==(Object other) =>
      other is PrayerWeekRow &&
      other.prayer == prayer &&
      listEquals(other.cells, cells);

  @override
  int get hashCode => Object.hash(prayer, Object.hashAll(cells));
}

@immutable
class PrayerProgress {
  const PrayerProgress({
    required this.streakDays,
    required this.bestStreakDays,
    required this.onTimeRate,
    required this.monthDone,
    required this.monthDue,
    required this.congregationThisMonth,
    required this.fastingDaysThisMonth,
    required this.dhikrThisMonth,
    required this.weekDays,
    required this.week,
  });

  static const PrayerProgress empty = PrayerProgress(
    streakDays: 0,
    bestStreakDays: 0,
    onTimeRate: null,
    monthDone: 0,
    monthDue: 0,
    congregationThisMonth: 0,
    fastingDaysThisMonth: 0,
    dhikrThisMonth: 0,
    weekDays: [],
    week: [],
  );

  /// Consecutive complete days up to today (today counts once complete).
  final int streakDays;
  final int bestStreakDays;

  /// On time ÷ resolved (not excused) over the last 30 days; null = none.
  final double? onTimeRate;
  final int monthDone;
  final int monthDue;
  final int congregationThisMonth;
  final int fastingDaysThisMonth;
  final int dhikrThisMonth;

  /// The last 7 days, oldest first (today last).
  final List<DateTime> weekDays;
  final List<PrayerWeekRow> week;

  bool get hasHistory => monthDue > 0 || streakDays > 0;

  @override
  bool operator ==(Object other) =>
      other is PrayerProgress &&
      other.streakDays == streakDays &&
      other.bestStreakDays == bestStreakDays &&
      other.onTimeRate == onTimeRate &&
      other.monthDone == monthDone &&
      other.monthDue == monthDue &&
      other.congregationThisMonth == congregationThisMonth &&
      other.fastingDaysThisMonth == fastingDaysThisMonth &&
      other.dhikrThisMonth == dhikrThisMonth &&
      listEquals(other.weekDays, weekDays) &&
      listEquals(other.week, week);

  @override
  int get hashCode => Object.hash(
    streakDays,
    bestStreakDays,
    onTimeRate,
    monthDone,
    monthDue,
    congregationThisMonth,
    fastingDaysThisMonth,
    dhikrThisMonth,
    Object.hashAll(weekDays),
    Object.hashAll(week),
  );
}

abstract final class PrayerStats {
  /// How far back the streak looks (the repository loads this many days).
  static const int historyDays = 400;

  /// Progress at [now] from [prayers] (active ones count) and their [logs]
  /// (any range; [historyDays] back is enough). [sunToday] / [sunTomorrow]
  /// resolve today's windows (null without a location).
  static PrayerProgress compute({
    required List<Prayer> prayers,
    required List<PrayerLog> logs,
    required DateTime now,
    SolarDay? sunToday,
    SolarDay? sunTomorrow,
  }) {
    final today = DateUtilsX.dateOnly(now);
    final active = [
      for (final p in prayers)
        if (p.isActive) p,
    ];
    final tracked = [
      for (final p in active)
        if (!p.kind.isFast && !p.kind.counts) p,
    ];
    final byId = {for (final l in logs) l.id: l};

    // Today's slots decide whether an unmarked prayer is still pending.
    final todaySlots = {
      for (final s in PrayerSchedule.dayPlan(
        tracked,
        today,
        (d) => DateUtilsX.dateOnly(d) == today ? sunToday : sunTomorrow,
        byId,
      ))
        s.prayer.id: s,
    };

    PrayerCell cell(Prayer p, DateTime day) {
      if (day.isAfter(today) || !PrayerSchedule.isDueOn(p, day)) {
        return PrayerCell.none;
      }
      // A prayer created after that day was not due yet.
      if (day.isBefore(DateUtilsX.dateOnly(p.createdAt))) {
        return PrayerCell.none;
      }
      final log = byId[PrayerLog.idFor(p.id, DateUtilsX.dayKey(day))];
      final status = log?.status;
      if (status != null && status != PrayerStatus.pending) {
        return switch (status) {
          PrayerStatus.onTime => PrayerCell.onTime,
          PrayerStatus.late => PrayerCell.late,
          PrayerStatus.madeUp => PrayerCell.madeUp,
          PrayerStatus.excused => PrayerCell.excused,
          _ => PrayerCell.missed,
        };
      }
      if (day == today) {
        final slot = todaySlots[p.id];
        if (slot == null) return PrayerCell.none;
        return slot.stateAt(now) == PrayerSlotState.missed
            ? PrayerCell.missed
            : PrayerCell.pending;
      }
      return PrayerCell.missed;
    }

    bool isDone(PrayerCell c) =>
        c == PrayerCell.onTime ||
        c == PrayerCell.late ||
        c == PrayerCell.madeUp;

    // Streaks: a day is complete when every due prayer is done or excused;
    // days with nothing due neither count nor break; today counts only
    // once complete, and never breaks the streak while it is still open.
    var streak = 0;
    var best = 0;
    var run = 0;
    var current = true;
    for (var i = 0; i < historyDays; i++) {
      final day = DateUtilsX.addDays(today, -i);
      final cells = [for (final p in tracked) cell(p, day)]
        ..removeWhere((c) => c == PrayerCell.none);
      if (cells.isEmpty) continue;
      final complete = cells.every((c) => isDone(c) || c == PrayerCell.excused);
      final open = cells.any((c) => c == PrayerCell.pending);
      if (complete) {
        run++;
        if (current) streak = run;
        if (run > best) best = run;
      } else if (i == 0 && open && !cells.any((c) => c == PrayerCell.missed)) {
        continue;
      } else {
        current = false;
        run = 0;
      }
    }

    // Last 30 days: on time ÷ resolved (not excused, not pending).
    var onTime = 0;
    var resolved = 0;
    for (var i = 0; i < 30; i++) {
      final day = DateUtilsX.addDays(today, -i);
      for (final p in tracked) {
        final c = cell(p, day);
        if (c == PrayerCell.none ||
            c == PrayerCell.pending ||
            c == PrayerCell.excused) {
          continue;
        }
        resolved++;
        if (c == PrayerCell.onTime) onTime++;
      }
    }

    // This month.
    var monthDone = 0;
    var monthDue = 0;
    final first = DateTime(today.year, today.month);
    for (var d = first; !d.isAfter(today); d = DateUtilsX.addDays(d, 1)) {
      for (final p in tracked) {
        final c = cell(p, d);
        if (c == PrayerCell.none ||
            c == PrayerCell.pending ||
            c == PrayerCell.excused) {
          continue;
        }
        monthDue++;
        if (isDone(c)) monthDone++;
      }
    }
    final kinds = {for (final p in active) p.id: p.kind};
    var congregation = 0;
    var fasting = 0;
    var dhikr = 0;
    for (final l in logs) {
      final d = DateUtilsX.dateOnly(l.day);
      if (d.isBefore(first) || d.isAfter(today)) continue;
      final kind = kinds[l.prayerId];
      if (kind == null) continue;
      if (kind.isFast) {
        if (l.status == PrayerStatus.onTime ||
            l.status == PrayerStatus.madeUp) {
          fasting++;
        }
      } else if (kind.counts) {
        dhikr += l.count;
      } else if (l.congregation && l.status.done) {
        congregation++;
      }
    }

    final weekDays = [
      for (var i = 6; i >= 0; i--) DateUtilsX.addDays(today, -i),
    ];
    final ordered = [...tracked]
      ..sort((a, b) {
        final c = a.start.minutes.compareTo(b.start.minutes);
        return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
      });
    return PrayerProgress(
      streakDays: streak,
      bestStreakDays: best,
      onTimeRate: resolved == 0 ? null : onTime / resolved,
      monthDone: monthDone,
      monthDue: monthDue,
      congregationThisMonth: congregation,
      fastingDaysThisMonth: fasting,
      dhikrThisMonth: dhikr,
      weekDays: weekDays,
      week: [
        for (final p in ordered)
          PrayerWeekRow(p, [for (final d in weekDays) cell(p, d)]),
      ],
    );
  }
}
