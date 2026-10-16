/// ============================================================
/// INSIGHTS SNAPSHOT — every number of the Insights screen (25)
/// ============================================================
///
/// Plain immutable values produced by InsightsAggregator: the four KPIs
/// with their previous-window baselines, the productivity series, the
/// "where your time went" split, habit streak rows and the weekly tip.
/// Formatting (%, "24.5", ▲/▼) is presentation's job; these carry raw
/// counts so tests can reconcile them with the data they came from.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';

/// done / total for one window; [rate] is null when nothing was measured.
@immutable
class RatioMetric {
  const RatioMetric({required this.done, required this.total});

  static const RatioMetric zero = RatioMetric(done: 0, total: 0);

  final int done;
  final int total;

  /// 0…1, or null when [total] is 0 ("no data", not 0 %).
  double? get rate => total == 0 ? null : done / total;

  @override
  bool operator ==(Object other) =>
      other is RatioMetric && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'RatioMetric($done/$total)';
}

/// A KPI for the current window and the previous equal one.
@immutable
class Kpi<T> {
  const Kpi({required this.current, required this.previous});

  final T current;
  final T previous;

  @override
  bool operator ==(Object other) =>
      other is Kpi<T> && other.current == current && other.previous == previous;

  @override
  int get hashCode => Object.hash(current, previous);

  @override
  String toString() => 'Kpi($current, prev $previous)';
}

/// One point of the productivity chart: a day (or a week on 90-day
/// ranges) and what happened in it.
@immutable
class ProductivityPoint {
  const ProductivityPoint({
    required this.start,
    required this.days,
    required this.tasks,
    required this.habits,
  });

  /// First day of the bucket (local midnight).
  final DateTime start;

  /// Bucket length in days (1, or 7 for long ranges; the last bucket may
  /// be shorter).
  final int days;

  /// Tasks completed in the bucket.
  final int tasks;

  /// Habit check-ins in the bucket.
  final int habits;

  /// The plotted score: tasks completed + habit check-ins.
  int get score => tasks + habits;

  @override
  bool operator ==(Object other) =>
      other is ProductivityPoint &&
      other.start == start &&
      other.days == days &&
      other.tasks == tasks &&
      other.habits == habits;

  @override
  int get hashCode => Object.hash(start, days, tasks, habits);

  @override
  String toString() => 'ProductivityPoint($start ×$days: $tasks+$habits)';
}

/// "Where your time went": actions per module in the window.
@immutable
class TimeSplit {
  const TimeSplit({
    this.tasks = 0,
    this.habits = 0,
    this.notes = 0,
    this.reminders = 0,
  });

  /// Tasks completed.
  final int tasks;

  /// Habit check-ins.
  final int habits;

  /// Notes created.
  final int notes;

  /// Reminders marked done.
  final int reminders;

  int get total => tasks + habits + notes + reminders;

  /// Whole-number percentages in legend order (tasks, habits, notes,
  /// reminders) that always add up to 100 (largest-remainder rounding);
  /// all zero when [total] is 0.
  List<int> get percents {
    final values = [tasks, habits, notes, reminders];
    if (total == 0) return const [0, 0, 0, 0];
    final exact = [for (final v in values) v * 100 / total];
    final result = [for (final e in exact) e.floor()];
    var left = 100 - result.sum;
    final order = List<int>.generate(4, (i) => i)
      ..sort((a, b) {
        final ra = exact[a] - result[a];
        final rb = exact[b] - result[b];
        return rb.compareTo(ra);
      });
    for (final i in order) {
      if (left <= 0) break;
      result[i]++;
      left--;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is TimeSplit &&
      other.tasks == tasks &&
      other.habits == habits &&
      other.notes == notes &&
      other.reminders == reminders;

  @override
  int get hashCode => Object.hash(tasks, habits, notes, reminders);

  @override
  String toString() => 'TimeSplit($tasks, $habits, $notes, $reminders)';
}

/// One row of "Habit streaks".
@immutable
class StreakRow {
  const StreakRow({
    required this.habitId,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    required this.streak,
    required this.progress,
  });

  final String habitId;
  final String name;
  final String iconKey;
  final String? colorHex;
  final HabitStreak streak;

  /// 0…1 bar length, relative to the longest streak in the list (weeks
  /// count as 7 days so daily and weekly habits compare fairly).
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is StreakRow &&
      other.habitId == habitId &&
      other.name == name &&
      other.iconKey == iconKey &&
      other.colorHex == colorHex &&
      other.streak == streak &&
      other.progress == progress;

  @override
  int get hashCode =>
      Object.hash(habitId, name, iconKey, colorHex, streak, progress);
}

/// Which rule produced the tip (tests and analytics-free debugging).
enum TipKind { morning, afternoon, evening, weekday, habits, focus, generic }

@immutable
class InsightsTip {
  const InsightsTip({required this.kind, required this.body});

  final TipKind kind;
  final String body;

  /// False for the generic tip shown without enough data.
  bool get isPersonal => kind != TipKind.generic;

  @override
  bool operator ==(Object other) =>
      other is InsightsTip && other.kind == kind && other.body == body;

  @override
  int get hashCode => Object.hash(kind, body);

  @override
  String toString() => 'InsightsTip($kind: $body)';
}

/// Everything the Insights screen renders for one range.
@immutable
class InsightsSnapshot {
  const InsightsSnapshot({
    required this.window,
    required this.taskCompletion,
    required this.focusMinutes,
    required this.habitConsistency,
    required this.notesCreated,
    required this.series,
    required this.split,
    required this.streaks,
    required this.hasHabits,
    required this.tip,
  });

  final InsightsWindow window;

  /// Tasks due in the window: completed / due.
  final Kpi<RatioMetric> taskCompletion;

  /// Focus minutes of sessions started in the window.
  final Kpi<int> focusMinutes;

  /// Scheduled habit days done / measured, across active habits.
  final Kpi<RatioMetric> habitConsistency;
  final Kpi<int> notesCreated;

  /// Oldest first; one point per day (≤ 31 days) or per week.
  final List<ProductivityPoint> series;
  final TimeSplit split;

  /// Longest current streaks first (at most 3).
  final List<StreakRow> streaks;

  /// Whether any active habit exists (streak empty state vs. zero rows).
  final bool hasHabits;
  final InsightsTip tip;

  /// The chart needs at least two points and some activity to draw a
  /// trend.
  bool get hasSeriesData =>
      series.length >= 2 && series.any((p) => p.score > 0);

  bool get hasSplitData => split.total > 0;

  static const _seriesEq = ListEquality<ProductivityPoint>();
  static const _streakEq = ListEquality<StreakRow>();

  @override
  bool operator ==(Object other) =>
      other is InsightsSnapshot &&
      other.window == window &&
      other.taskCompletion == taskCompletion &&
      other.focusMinutes == focusMinutes &&
      other.habitConsistency == habitConsistency &&
      other.notesCreated == notesCreated &&
      _seriesEq.equals(other.series, series) &&
      other.split == split &&
      _streakEq.equals(other.streaks, streaks) &&
      other.hasHabits == hasHabits &&
      other.tip == tip;

  @override
  int get hashCode => Object.hash(
    window,
    taskCompletion,
    focusMinutes,
    habitConsistency,
    notesCreated,
    _seriesEq.hash(series),
    split,
    _streakEq.hash(streaks),
    hasHabits,
    tip,
  );
}
