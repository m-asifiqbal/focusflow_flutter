/// ============================================================
/// HABIT DETAIL PROVIDERS — derived views of screen 16
/// ============================================================
///
/// Built on habitDetailProvider (habit + full history + stats, live):
///   habitHeatmapRangeProvider   "Last 4 months" ⇄ "Last year" selector
///   habitHeatmapValuesProvider  day → 0…1 for the heatmap
///   habitHeatmapRestDaysProvider  days the habit wasn't due (rest days)
///   habitHistoryProvider        newest-first History rows
///   habitCsvShareServiceProvider  Export CSV (More sheet)
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/data/export/habit_csv_share_service.dart';
import 'package:focusflow/features/habits/domain/services/habit_history.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';

/// Heatmap span: weeks shown and the selector's label.
enum HabitHeatmapRange {
  months4(17),
  year(53);

  const HabitHeatmapRange(this.weeks);

  final int weeks;

  /// The selector's text, in the active language.
  String get label => switch (this) {
    months4 => tr('Last 4 months'),
    year => tr('Last year'),
  };
}

class HabitHeatmapRangeController
    extends AutoDisposeFamilyNotifier<HabitHeatmapRange, String> {
  @override
  HabitHeatmapRange build(String habitId) => HabitHeatmapRange.months4;

  void toggle() => state = state == HabitHeatmapRange.months4
      ? HabitHeatmapRange.year
      : HabitHeatmapRange.months4;
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
