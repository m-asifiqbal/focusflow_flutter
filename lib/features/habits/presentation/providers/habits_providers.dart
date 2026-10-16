/// ============================================================
/// HABITS PROVIDERS — the live data behind screens 14 and 16
/// ============================================================
///
/// Every list is a StreamProvider over a HabitsRepository stream, so a
/// check-in anywhere (card, swipe, actions sheet, Home, a notification
/// action) updates every screen at once.
///
///   habitTodayProvider          the current *habit* day (Settings › Habit
///                               reset time), recomputed by HabitDayTicker
///                               at the next reset boundary and on resume
///   habitsScopeProvider         selected chip of the habits list
///   habitDayStatusesProvider    cards for one chip
///   todayHabitsProvider         today's cards (header, hero, Home)
///   habitsDaySummaryProvider    "2 of 5 done today" + hero ring
///   habitDetailProvider         habit + history + stats (screen 16)
///   habitStreakProvider         one habit's streak
///   perfectDayCelebrationProvider  "Perfect day!" confetti, once a day
///                               (persisted, survives a restart)
///   reorderHabits               drag-to-reorder → repository order
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/domain/services/habit_day.dart';
import 'package:focusflow/features/habits/domain/services/habits_day_summary.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Today's habit day (local midnight), honouring the habit reset time.
/// Habit screens wrap themselves in HabitDayTicker, which invalidates it
/// when the next habit day starts and on resume — so an app left open past
/// midnight (or the reset time) never logs to yesterday. (The timer lives
/// in a widget, not here, so it dies with the screen — no leaked timers.)
final habitTodayProvider = Provider.autoDispose<DateTime>((ref) {
  final reset = ref.watch(settingsProvider.select((s) => s.habitResetMinutes));
  return HabitDay.of(ref.watch(clockProvider).now(), resetMinutes: reset);
});

/// First day of the week from settings (week squares, heatmap, streaks).
final habitWeekStartProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(settingsProvider.select((s) => s.weekStartsOn)),
);

/// The selected chip of the habits list (Today by default).
class HabitsScopeController extends AutoDisposeNotifier<HabitsScope> {
  @override
  HabitsScope build() => HabitsScope.today;

  void select(HabitsScope scope) => state = scope;
}

final habitsScopeProvider =
    NotifierProvider.autoDispose<HabitsScopeController, HabitsScope>(
      HabitsScopeController.new,
    );

/// The habit cards of one chip for today.
final habitDayStatusesProvider = StreamProvider.autoDispose
    .family<List<HabitDayStatus>, HabitsScope>((ref, scope) {
      return ref
          .watch(habitsRepositoryProvider)
          .watchDayStatuses(
            HabitsQuery(scope: scope),
            ref.watch(habitTodayProvider),
            weekStartsOn: ref.watch(habitWeekStartProvider),
          );
    });

/// Today's cards of every active, not paused habit.
final todayHabitsProvider = StreamProvider.autoDispose<List<HabitDayStatus>>((
  ref,
) {
  return ref
      .watch(habitsRepositoryProvider)
      .watchTodayHabits(
        ref.watch(habitTodayProvider),
        weekStartsOn: ref.watch(habitWeekStartProvider),
      );
});

/// "2 of 5 done today", the hero ring and the longest active streak.
final habitsDaySummaryProvider =
    Provider.autoDispose<AsyncValue<HabitsDaySummary>>(
      (ref) => ref.watch(todayHabitsProvider).whenData(HabitsDaySummary.of),
    );

/// One habit with its full history and stats (null once it is gone).
final habitDetailProvider = StreamProvider.autoDispose
    .family<HabitDetail?, String>((ref, id) {
      return ref
          .watch(habitsRepositoryProvider)
          .watchHabitDetail(
            id,
            today: ref.watch(habitTodayProvider),
            weekStartsOn: ref.watch(habitWeekStartProvider),
          );
    });

/// The current / best streak of one habit (null while loading or gone).
final habitStreakProvider = Provider.autoDispose.family<HabitStreak?, String>(
  (ref, id) => ref.watch(habitDetailProvider(id)).valueOrNull?.stats.streak,
);

/// Remembers the habit day the "Perfect day!" confetti last played, so it
/// plays once per day — persisted in SharedPreferences ([prefsKey], a
/// `yyyy-MM-dd` day key), so restarting the app on a finished day doesn't
/// celebrate again.
class PerfectDayCelebration extends Notifier<DateTime?> {
  /// SharedPreferences key of the last celebrated habit day.
  static const String prefsKey = 'habits.perfectDayClaimed';

  @override
  DateTime? build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    if (stored == null) return null;
    try {
      return DateUtilsX.parseDayKey(stored);
    } on Object {
      // Malformed value (FormatException / RangeError): never celebrated.
      return null;
    }
  }

  /// True the first time it is called for [day] (and remembers it, also
  /// across app restarts).
  bool claim(DateTime day) {
    final d = DateUtilsX.dateOnly(day);
    if (state == d) return false;
    state = d;
    // Best effort: a failed write only means a second celebration.
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(prefsKey, DateUtilsX.dayKey(d))
          .catchError((Object _) => false),
    );
    return true;
  }
}

final perfectDayCelebrationProvider =
    NotifierProvider<PerfectDayCelebration, DateTime?>(
      PerfectDayCelebration.new,
    );

/// Drag-to-reorder on the habits list: moves the habit at [oldIndex] of
/// [ids] (the list as shown) so it ends up at [newIndex] (its final
/// position, as `onReorderItem` reports it).
Future<void> reorderHabits(
  HabitsRepository repo,
  List<String> ids,
  int oldIndex,
  int newIndex,
) async {
  if (oldIndex < 0 || oldIndex >= ids.length) return;
  if (newIndex == oldIndex) return;
  final rest = [...ids]..removeAt(oldIndex);
  final at = newIndex.clamp(0, rest.length);
  await repo.reorder(
    ids[oldIndex],
    afterId: at == 0 ? null : rest[at - 1],
    beforeId: at >= rest.length ? null : rest[at],
  );
}
