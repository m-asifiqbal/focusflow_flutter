/// ============================================================
/// INSIGHTS TIPS — the rule-based "Weekly tip" (no network, no ML)
/// ============================================================
///
/// Rules, first match wins (each needs enough data to be meaningful):
///   1. Time of day — ≥ [minTimedTasks] tasks completed: when one half of
///      the day (before / after noon) has ≥ 1.5× the other, say so; an
///      afternoon/evening lead names the bigger of the two.
///   2. Weekday — window ≥ 7 days and ≥ [minWeekdayActions] actions: the
///      weekday with strictly the most actions (tasks + check-ins).
///   3. Habits — consistency below 50 % over ≥ 5 measured days.
///   4. Focus — ≥ 3 tasks completed but no focus session yet.
///   5. Otherwise a generic, data-free tip.
/// ============================================================
library;

import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';

abstract final class InsightsTips {
  static const int minTimedTasks = 5;
  static const int minWeekdayActions = 10;
  static const double leadRatio = 1.5;

  static const String generic =
      'Pick your top three tasks the evening before. Small wins early '
      'build momentum for the whole day.';

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// The tip for a window. [completedAt]: completion instants of tasks in
  /// the window; [daily]: one point per day of the window.
  static InsightsTip pick({
    required InsightsWindow window,
    required List<DateTime> completedAt,
    required List<ProductivityPoint> daily,
    required RatioMetric consistency,
    required int focusMinutes,
  }) =>
      _timeOfDay(completedAt) ??
      _weekday(window, daily) ??
      _habits(consistency) ??
      _focus(completedAt.length, focusMinutes) ??
      const InsightsTip(kind: TipKind.generic, body: generic);

  static InsightsTip? _timeOfDay(List<DateTime> completedAt) {
    if (completedAt.length < minTimedTasks) return null;
    final morning = completedAt.where((t) => t.hour < 12).length;
    final evening = completedAt.where((t) => t.hour >= 17).length;
    final later = completedAt.length - morning;
    final afternoon = later - evening;
    if (morning >= later * leadRatio) {
      return InsightsTip(
        kind: TipKind.morning,
        body: later == 0
            ? 'You complete all your tasks before noon. Schedule '
                  'high-priority work in the morning.'
            : 'You complete ${_ratio(morning / later)} more tasks before '
                  'noon. Schedule high-priority work in the morning.',
      );
    }
    if (later >= morning * leadRatio) {
      final lead = morning == 0
          ? 'You complete all your tasks after noon.'
          : 'You complete ${_ratio(later / morning)} more tasks after noon.';
      return evening > afternoon
          ? InsightsTip(
              kind: TipKind.evening,
              body:
                  '$lead Evenings are your peak: protect them for '
                  'focused work.',
            )
          : InsightsTip(
              kind: TipKind.afternoon,
              body: '$lead Save deep work for the afternoon.',
            );
    }
    return null;
  }

  static InsightsTip? _weekday(
    InsightsWindow window,
    List<ProductivityPoint> daily,
  ) {
    if (window.days < 7) return null;
    final byWeekday = List<int>.filled(7, 0);
    var total = 0;
    for (final p in daily) {
      byWeekday[p.start.weekday - 1] += p.score;
      total += p.score;
    }
    if (total < minWeekdayActions) return null;
    var best = 0;
    for (var i = 1; i < 7; i++) {
      if (byWeekday[i] > byWeekday[best]) best = i;
    }
    final tied = byWeekday.where((v) => v == byWeekday[best]).length > 1;
    if (tied) return null;
    final name = _weekdays[best];
    return InsightsTip(
      kind: TipKind.weekday,
      body:
          '$name is your most productive day. Plan your toughest tasks '
          'for ${name}s.',
    );
  }

  static InsightsTip? _habits(RatioMetric consistency) {
    final rate = consistency.rate;
    if (rate == null || consistency.total < 5 || rate >= 0.5) return null;
    return InsightsTip(
      kind: TipKind.habits,
      body:
          'You kept ${(rate * 100).round()}% of your scheduled habit '
          'days. Fewer habits, each with a reminder time, are easier to keep.',
    );
  }

  static InsightsTip? _focus(int tasksDone, int focusMinutes) {
    if (tasksDone < 3 || focusMinutes > 0) return null;
    return const InsightsTip(
      kind: TipKind.focus,
      body:
          'Try a 25-minute focus session before your next task. Tap Focus '
          'hours to start one.',
    );
  }

  /// 2 → "2×", 1.5 → "1.5×", 2.04 → "2×".
  static String _ratio(double r) {
    final rounded = (r * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    return '$text×';
  }
}
