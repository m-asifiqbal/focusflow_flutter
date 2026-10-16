/// ============================================================
/// HABITS DAY SUMMARY — "2 of 5 done today", the hero ring and best streak
/// ============================================================
///
/// Aggregates today's [HabitDayStatus] cards for the habits list header
/// and hero (screen 14) and Home's habit row. Rules:
///   • only habits due today count (rest days and skipped days are left
///     out — they can't be "missed"); an N× per week habit whose weekly
///     quota is already met is a rest day (HabitSchedule.isDueOn), so it
///     never blocks the perfect day;
///   • a quit habit counts as done while it is clean;
///   • the hero names the habit with the longest *current* streak.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';

@immutable
class HabitsDaySummary {
  const HabitsDaySummary({
    required this.done,
    required this.due,
    required this.total,
    this.longest,
  });

  /// Summarises [statuses] (one per active habit for one day).
  factory HabitsDaySummary.of(List<HabitDayStatus> statuses) {
    var done = 0;
    var due = 0;
    HabitDayStatus? longest;
    for (final s in statuses) {
      if (s.isScheduled && !s.isSkipped) {
        due++;
        if (s.isDone) done++;
      }
      if (s.currentStreak > 0 &&
          (longest == null || s.currentStreak > longest.currentStreak)) {
        longest = s;
      }
    }
    return HabitsDaySummary(
      done: done,
      due: due,
      total: statuses.length,
      longest: longest,
    );
  }

  static const empty = HabitsDaySummary(done: 0, due: 0, total: 0);

  /// Habits due today that are done (quit habits: clean).
  final int done;

  /// Habits due today (not resting, not skipped).
  final int due;

  /// Every habit in the list, rest days included.
  final int total;

  /// The habit with the longest current streak (null when none > 0).
  final HabitDayStatus? longest;

  /// 0…1 for the hero ring.
  double get progress => due == 0 ? 0 : done / due;

  /// Every due habit is done ("Perfect day!").
  bool get isPerfect => due > 0 && done == due;

  @override
  bool operator ==(Object other) =>
      other is HabitsDaySummary &&
      other.done == done &&
      other.due == due &&
      other.total == total &&
      other.longest == longest;

  @override
  int get hashCode => Object.hash(done, due, total, longest);
}
