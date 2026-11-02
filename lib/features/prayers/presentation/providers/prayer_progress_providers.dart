/// ============================================================
/// PRAYER PROGRESS PROVIDERS — the Prayer page's Day · Week · Month · Year
/// ============================================================
///
/// The picked view (Week by default, kept while the app runs), how far back
/// the Day and Month views are paged (0 = today / this month), and the data
/// of each view over the same prayers and logs as the rest of Progress
/// ([prayersProvider], [prayerLogsProvider]). The Week view is the grid of
/// [prayerProgressProvider].
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_progress_views.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';

class PrayerProgressViewController extends Notifier<PrayerProgressView> {
  @override
  PrayerProgressView build() => PrayerProgressView.week;

  void select(PrayerProgressView v) => state = v;
}

final prayerProgressViewProvider =
    NotifierProvider<PrayerProgressViewController, PrayerProgressView>(
      PrayerProgressViewController.new,
    );

/// Steps back from today / this month (≤ 0), never past [min].
class PrayerPageController extends Notifier<int> {
  PrayerPageController(this.min);

  final int min;

  @override
  int build() => 0;

  /// Moves by [by] (−1 = back), kept within `min … 0`.
  void step(int by) => state = (state + by).clamp(min, 0);

  void reset() => state = 0;
}

/// Days back from today on the Day view.
final prayerDayPageProvider = NotifierProvider<PrayerPageController, int>(
  () => PrayerPageController(-(PrayerStats.historyDays - 1)),
);

/// Months back from this month on the Month view.
final prayerMonthPageProvider = NotifierProvider<PrayerPageController, int>(
  () => PrayerPageController(-PrayerProgressViews.monthsBack),
);

/// The Day view: the day shown and its prayers (null while loading).
final prayerDayViewProvider =
    Provider.autoDispose<(DateTime, List<PrayerDayEntry>)?>((ref) {
      final prayers = ref.watch(prayersProvider).valueOrNull;
      final logs = ref.watch(prayerLogsProvider).valueOrNull;
      if (prayers == null || logs == null) return null;
      final now = ref.watch(minuteClockProvider);
      final sunFor = ref.watch(prayerSunProvider);
      final today = DateUtilsX.dateOnly(now);
      final day = DateUtilsX.addDays(today, ref.watch(prayerDayPageProvider));
      return (
        day,
        PrayerProgressViews.dayOf(
          prayers: prayers,
          logs: logs,
          now: now,
          day: day,
          sunToday: sunFor(today),
          sunTomorrow: sunFor(DateUtilsX.addDays(today, 1)),
          hijriAdjust: ref.watch(prayerPrefsProvider).hijriAdjust,
        ),
      );
    });

/// The Month view: every day of the month shown (null while loading).
final prayerMonthViewProvider = Provider.autoDispose<List<PrayerMonthDay>?>((
  ref,
) {
  final prayers = ref.watch(prayersProvider).valueOrNull;
  final logs = ref.watch(prayerLogsProvider).valueOrNull;
  if (prayers == null || logs == null) return null;
  final now = ref.watch(minuteClockProvider);
  final sunFor = ref.watch(prayerSunProvider);
  final today = DateUtilsX.dateOnly(now);
  final back = ref.watch(prayerMonthPageProvider);
  return PrayerProgressViews.monthOf(
    prayers: prayers,
    logs: logs,
    now: now,
    month: DateTime(today.year, today.month + back),
    sunToday: sunFor(today),
    sunTomorrow: sunFor(DateUtilsX.addDays(today, 1)),
    hijriAdjust: ref.watch(prayerPrefsProvider).hijriAdjust,
  );
});

/// The Year view (null while loading).
final prayerYearViewProvider = Provider.autoDispose<PrayerYear?>((ref) {
  final prayers = ref.watch(prayersProvider).valueOrNull;
  final logs = ref.watch(prayerLogsProvider).valueOrNull;
  if (prayers == null || logs == null) return null;
  final now = ref.watch(minuteClockProvider);
  final sunFor = ref.watch(prayerSunProvider);
  final today = DateUtilsX.dateOnly(now);
  return PrayerProgressViews.yearOf(
    prayers: prayers,
    logs: logs,
    now: now,
    sunToday: sunFor(today),
    sunTomorrow: sunFor(DateUtilsX.addDays(today, 1)),
    hijriAdjust: ref.watch(prayerPrefsProvider).hijriAdjust,
  );
});
