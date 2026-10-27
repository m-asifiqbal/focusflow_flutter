/// ============================================================
/// HABIT DETAIL PROVIDERS — derived views of screen 16
/// ============================================================
///
/// Built on habitDetailProvider (habit + full history + stats, live):
///   habitHeatmapRangeProvider   This week (default) · This month · Last 4
///                               months · Last year selector
///   habitHeatmapValuesProvider  day → 0…1 for the heatmap
///   habitHeatmapRestDaysProvider  days the habit wasn't due (rest days)
///   habitHistoryProvider        newest-first History rows
///   habitCsvShareServiceProvider  Export CSV (More sheet)
/// ============================================================
library;

import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/data/export/habit_csv_share_service.dart';
import 'package:focusflow/features/habits/domain/services/habit_history.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';

/// Heatmap span, shortest first (the selector steps through them in order).
enum HabitHeatmapRange {
  week,
  month,
  months4,
  year;

  /// The selector's text, in the active language.
  String get label => switch (this) {
    week => tr('This week'),
    month => tr('This month'),
    months4 => tr('Last 4 months'),
    year => tr('Last year'),
  };

  /// Glyph of the range in the picker sheet.
  IconData get icon => switch (this) {
    week => FontAwesomeIcons.calendarWeek,
    month => FontAwesomeIcons.calendarDays,
    months4 => FontAwesomeIcons.tableCells,
    year => FontAwesomeIcons.calendar,
  };

  /// Week and month are drawn as a calendar (weeks as rows), the longer
  /// ranges as the GitHub-style grid (weeks as columns).
  bool get isCalendar => this == week || this == month;

  /// The next range, wrapping from the longest back to the shortest.
  HabitHeatmapRange get next => values[(index + 1) % values.length];

  /// Week rows / columns the grid needs for the day [today]: 1 for the
  /// week, the weeks the current month spans for the month (its 1st's week
  /// to today's), 17 and 53 for the long ranges.
  int weeksFor(DateTime today, int weekStart) => switch (this) {
    week => 1,
    month =>
      (DateUtilsX.daysBetween(
                _weekStartOf(DateTime(today.year, today.month), weekStart),
                _weekStartOf(today, weekStart),
              ) ~/
              7) +
          1,
    months4 => 17,
    year => 53,
  };

  /// First day shown: the 1st for the month calendar, else no limit.
  DateTime? firstDay(DateTime today) =>
      this == month ? DateTime(today.year, today.month) : null;

  static DateTime _weekStartOf(DateTime d, int weekStart) =>
      DateUtilsX.addDays(d, -((d.weekday - weekStart + 7) % 7));
}

class HabitHeatmapRangeController
    extends AutoDisposeFamilyNotifier<HabitHeatmapRange, String> {
  @override
  HabitHeatmapRange build(String habitId) => HabitHeatmapRange.week;

  void select(HabitHeatmapRange range) => state = range;

  /// Steps to the next range (week → month → 4 months → year → week).
  void toggle() => state = state.next;
}

/// Selected heatmap range of one habit's detail screen.
final habitHeatmapRangeProvider = NotifierProvider.autoDispose
    .family<HabitHeatmapRangeController, HabitHeatmapRange, String>(
      HabitHeatmapRangeController.new,
    );

/// Day (local midnight) → 0…1 progress, from the detail stats (365 days).
final habitHeatmapValuesProvider = Provider.autoDispose
    .family<Map<DateTime, double>, String>((ref, id) {
      final heatmap = ref
          .watch(habitDetailProvider(id))
          .valueOrNull
          ?.stats
          .heatmap;
      if (heatmap == null) return const {};
      return {
        for (final e in heatmap.entries) DateUtilsX.parseDayKey(e.key): e.value,
      };
    });

/// Days (local midnight) of the heatmap range the habit wasn't due — drawn
/// as rest days, not misses.
final habitHeatmapRestDaysProvider = Provider.autoDispose
    .family<Set<DateTime>, String>((ref, id) {
      final rest = ref
          .watch(habitDetailProvider(id))
          .valueOrNull
          ?.stats
          .restDays;
      if (rest == null || rest.isEmpty) return const {};
      return {for (final k in rest) DateUtilsX.parseDayKey(k)};
    });

/// Every History row of a habit, newest first.
final habitHistoryProvider = Provider.autoDispose
    .family<List<HabitHistoryEntry>, String>((ref, id) {
      final d = ref.watch(habitDetailProvider(id)).valueOrNull;
      if (d == null) return const [];
      return HabitHistory.entries(d.habit, d.logs, d.today);
    });

final habitCsvShareServiceProvider = Provider<HabitCsvShareService>(
  (ref) => const HabitCsvShareService(),
);
