/// ============================================================
/// PRAYER INSIGHTS PROVIDERS — Insights › Prayer
/// ============================================================
///
/// The picked period (Daily · Monthly · Yearly, kept while the app runs)
/// and the live [PrayerInsights] of it: the active prayers, their logs from
/// the start of the previous window, today's sun times. "Now" moves in
/// 15-minute steps, like Insights › Medicine — often enough for a prayer
/// to turn "missed" when its window ends.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

class PrayerPeriodController extends Notifier<PrayerPeriod> {
  @override
  PrayerPeriod build() => PrayerPeriod.daily;

  void select(PrayerPeriod p) => state = p;
}

final prayerPeriodProvider =
    NotifierProvider<PrayerPeriodController, PrayerPeriod>(
      PrayerPeriodController.new,
    );

/// [minuteClockProvider] rounded down to a quarter hour.
final _quarterHourProvider = Provider.autoDispose<DateTime>((ref) {
  final t = ref.watch(minuteClockProvider);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute - t.minute % 15);
});

/// Logs from the start of [period]'s previous window to tomorrow.
final _periodLogsProvider = StreamProvider.autoDispose
    .family<List<PrayerLog>, PrayerPeriod>((ref, period) {
      final today = ref.watch(todayProvider);
      final win = PrayerInsightsCalculator.window(period, today);
      final from = PrayerInsightsCalculator.previousWindow(period, win).$1;
      return ref
          .watch(prayersRepositoryProvider)
          .watchLogs(from, DateUtilsX.addDays(today, 1));
    });

final prayerInsightsProvider = Provider.autoDispose
    .family<AsyncValue<PrayerInsights>, PrayerPeriod>((ref, period) {
      final prayers = ref.watch(prayersProvider);
      final logs = ref.watch(_periodLogsProvider(period));
      final now = ref.watch(_quarterHourProvider);
      final sunFor = ref.watch(prayerSunProvider);
      if (prayers.hasError) {
        return AsyncValue.error(prayers.error!, prayers.stackTrace!);
      }
      if (logs.hasError) return AsyncValue.error(logs.error!, logs.stackTrace!);
      final p = prayers.valueOrNull;
      final l = logs.valueOrNull;
      if (p == null || l == null) return const AsyncValue.loading();
      return AsyncValue.data(
        PrayerInsightsCalculator.compute(
          prayers: p,
          logs: l,
          period: period,
          now: now,
          sunToday: sunFor(now),
          sunTomorrow: sunFor(DateUtilsX.addDays(now, 1)),
          hijriAdjust: ref.watch(prayerPrefsProvider).hijriAdjust,
          sunFor: sunFor,
        ),
      );
    });
