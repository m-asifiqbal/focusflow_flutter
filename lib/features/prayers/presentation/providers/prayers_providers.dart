/// ============================================================
/// PRAYERS PROVIDERS — the live data of the Prayer tab, Home and Calendar
/// ============================================================
///
/// What: the active prayers, the logs of the last [PrayerStats.historyDays]
/// days, the saved prayer settings, a memoised "sun times of a day", and
/// derived values: today's plan ([PrayerToday]: slots, the hero slot, fasts,
/// counting practices), progress (PrayerStats) and today's Hijri date.
/// Why: lists are StreamProviders over repository streams, so a mark from a
/// notification, another screen or a sync updates every screen; the day and
/// the minute come from the shared minute clock (MinuteTicker), so windows
/// open and close on screen without a restart.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/prayer_prefs.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_sun.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The saved prayer settings.
final prayerPrefsProvider = Provider<PrayerPrefs>(
  (ref) => ref.watch(settingsProvider.select((s) => s.prayer)),
);

/// Sun times of a day for the saved settings (null without a location).
final prayerSunProvider = Provider<SolarDay? Function(DateTime)>(
  (ref) => PrayerSun.dayFn(ref.watch(prayerPrefsProvider)),
);

/// Active prayers (paused included), pinned first then manual order.
final prayersProvider = StreamProvider.autoDispose<List<Prayer>>(
  (ref) =>
      ref.watch(prayersRepositoryProvider).watchPrayers(PrayersScope.active),
);

/// One prayer (editor), any lifecycle state.
final prayerProvider = StreamProvider.autoDispose.family<Prayer?, String>(
  (ref, id) => ref.watch(prayersRepositoryProvider).watchPrayer(id),
);

/// Logs from [PrayerStats.historyDays] ago to tomorrow (a window may end
/// tomorrow); re-subscribes only when the day changes.
final prayerLogsProvider = StreamProvider.autoDispose<List<PrayerLog>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(prayersRepositoryProvider)
      .watchLogs(
        DateUtilsX.addDays(today, -PrayerStats.historyDays),
        DateUtilsX.addDays(today, 1),
      );
});

/// Everything the Prayer tab shows for today.
@immutable
class PrayerToday {
  const PrayerToday({
    required this.now,
    required this.slots,
    required this.focus,
    required this.hasPrayers,
  });

  final DateTime now;

  /// Today's prayers and practices, soonest first.
  final List<PrayerSlot> slots;

  /// The hero: the open prayer, else the next one (null = day done).
  final PrayerSlot? focus;

  /// Any active prayer at all (else the setup / empty state).
  final bool hasPrayers;

  /// Prayers that are neither fasts nor counting practices.
  List<PrayerSlot> get prayers => [
    for (final s in slots)
      if (!s.prayer.kind.isFast && !s.prayer.kind.counts) s,
  ];

  List<PrayerSlot> get fasts => [
    for (final s in slots)
      if (s.prayer.kind.isFast) s,
  ];

  List<PrayerSlot> get counters => [
    for (final s in slots)
      if (s.prayer.kind.counts) s,
  ];

  @override
  bool operator ==(Object other) =>
      other is PrayerToday &&
      other.now == now &&
      listEquals(other.slots, slots) &&
      other.focus == focus &&
      other.hasPrayers == hasPrayers;

  @override
  int get hashCode =>
      Object.hash(now, Object.hashAll(slots), focus, hasPrayers);
}

PrayerToday _todayOf(
  List<Prayer> prayers,
  List<PrayerLog> logs,
  DateTime now,
  SolarDay? Function(DateTime) sunFor,
) {
  final byId = {for (final l in logs) l.id: l};
  final today = DateUtilsX.dateOnly(now);
  final slots = PrayerSchedule.dayPlan(prayers, today, sunFor, byId);
  return PrayerToday(
    now: now,
    slots: slots,
    focus: PrayerSchedule.focus(slots, now),
    hasPrayers: prayers.isNotEmpty,
  );
}

/// Today's plan (recomputed every minute and on every write).
final prayerTodayProvider = Provider.autoDispose<AsyncValue<PrayerToday>>((
  ref,
) {
  final prayers = ref.watch(prayersProvider);
  final logs = ref.watch(prayerLogsProvider);
  final now = ref.watch(minuteClockProvider);
  final sunFor = ref.watch(prayerSunProvider);
  if (prayers.hasError) {
    return AsyncValue.error(prayers.error!, prayers.stackTrace!);
  }
  final p = prayers.valueOrNull;
  final l = logs.valueOrNull;
  if (p == null || l == null) return const AsyncValue.loading();
  return AsyncValue.data(_todayOf(p, l, now, sunFor));
});

/// Streak, on-time rate, month and the week grid.
final prayerProgressProvider = Provider.autoDispose<PrayerProgress>((ref) {
  final prayers = ref.watch(prayersProvider).valueOrNull;
  final logs = ref.watch(prayerLogsProvider).valueOrNull;
  if (prayers == null || logs == null) return PrayerProgress.empty;
  final now = ref.watch(minuteClockProvider);
  final sunFor = ref.watch(prayerSunProvider);
  final today = DateUtilsX.dateOnly(now);
  return PrayerStats.compute(
    prayers: prayers,
    logs: logs,
    now: now,
    sunToday: sunFor(today),
    sunTomorrow: sunFor(DateUtilsX.addDays(today, 1)),
  );
});

/// Today's Hijri date ("10 Jumada al-Ula 1448") with the saved correction;
/// null unless the Islamic preset is in use.
final prayerHijriProvider = Provider.autoDispose<String?>((ref) {
  final prefs = ref.watch(prayerPrefsProvider);
  if (PrayerTradition.fromKey(prefs.tradition) != PrayerTradition.islam) {
    return null;
  }
  final today = ref.watch(todayProvider);
  return HijriDate.fromGregorian(today, adjustDays: prefs.hijriAdjust).format();
});
