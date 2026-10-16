/// ============================================================
/// HOME PROVIDERS — the live data behind the Home dashboard (screen 03)
/// ============================================================
///
/// Every section is a StreamProvider over a repository stream (or a
/// Provider combining them), so completing a task, logging a habit or
/// snoozing a reminder anywhere updates Home immediately.
///
///   homeSelectedDayProvider   day picked in the week strip (null = today)
///   homeDayProvider           the resolved day (selection or today)
///   homeTasksProvider(day)    "Today's Tasks" for a day, ordered
///   homeNextReminderProvider  the soonest upcoming reminder (any day)
///   homeUpNextProvider(day)   the Up Next reminder for a day
///   homeFocusProvider         Today's Focus hero numbers
///   homeDotDaysProvider       day keys with tasks/reminders (strip dots)
///   homeRecentNotesProvider   "Recent Notes" (4)
///   homeUnreadProvider        bell dot (unread inbox entries)
///   homeDisplayNameProvider   greeting name (settings → cloud account)
///   homeGetStartedProvider    the 3-step "Get started" checklist progress
///   homeFirstRunProvider      true when nothing exists yet (any module)
///
/// Time-relative providers (Up Next) rebuild every minute; Riverpod then
/// reports AsyncLoading *with the previous value*, so widgets render with
/// `when(skipLoadingOnReload: true)` / `valueOrNull` and never flash a
/// skeleton once data has arrived.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/entities/task_sections.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The day picked in the week strip; null follows "today" (so the
/// dashboard rolls over at midnight).
class HomeSelectedDay extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Selects [day]; picking today clears the selection.
  void select(DateTime day, {required DateTime today}) => state =
      DateUtilsX.isSameDay(day, today) ? null : DateUtilsX.dateOnly(day);
}

final homeSelectedDayProvider = NotifierProvider<HomeSelectedDay, DateTime?>(
  HomeSelectedDay.new,
);

/// The day the tasks / Up Next sections show.
final homeDayProvider = Provider<DateTime>(
  (ref) => ref.watch(homeSelectedDayProvider) ?? ref.watch(todayProvider),
);

/// Two weeks of strip days from the user's week start.
final homeWeekDaysProvider = Provider<List<DateTime>>((ref) {
  final start = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
  return HomeRules.weekDays(ref.watch(todayProvider), start);
});

/// Tasks due on a day (open + completed), in Home order.
final homeTasksProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, DateTime>(
      (ref, day) => ref
          .watch(tasksRepositoryProvider)
          .watchTasksForDay(day)
          .map(HomeRules.orderTasks),
    );

/// Reminder occurrences on a day.
final homeDayRemindersProvider = StreamProvider.autoDispose
    .family<List<ReminderOccurrence>, DateTime>(
      (ref, day) => ref.watch(remindersRepositoryProvider).watchForDay(day),
    );

/// The soonest upcoming reminder (any day). Re-queried when the minute
/// changes (what is "upcoming" moves with the clock); the previous value
/// stays available while the new query runs.
final homeNextReminderProvider =
    StreamProvider.autoDispose<ReminderOccurrence?>(
      (ref) => ref
          .watch(remindersRepositoryProvider)
          .watchNext(ref.watch(minuteClockProvider)),
    );

/// Up Next for [day]: the next upcoming reminder when [day] is today,
/// otherwise the first pending reminder of that day.
final homeUpNextProvider = Provider.autoDispose
    .family<AsyncValue<ReminderOccurrence?>, DateTime>((ref, day) {
      if (DateUtilsX.isSameDay(day, ref.watch(todayProvider))) {
        return ref.watch(homeNextReminderProvider);
      }
      return mapKeepingValue(
        ref.watch(homeDayRemindersProvider(day)),
        (list) =>
            list.where((o) => !o.isDone && o.reminder.isEnabled).firstOrNull,
      );
    });

/// Like [AsyncValue.whenData], but a reload keeps the mapped previous value
/// (Riverpod's `whenData` drops it, which makes widgets flash a skeleton).
AsyncValue<R> mapKeepingValue<T, R>(AsyncValue<T> v, R Function(T) map) {
  if (v.hasError) return AsyncError<R>(v.error!, v.stackTrace!);
  if (!v.hasValue) return AsyncLoading<R>();
  final data = AsyncData<R>(map(v.requireValue));
  return v.isLoading
      ? AsyncLoading<R>().copyWithPrevious(data, isRefresh: false)
      : data;
}

/// Task KPIs for today (done today / due today / totals).
final homeTaskStatsProvider = StreamProvider.autoDispose<TaskStats>(
  (ref) =>
      ref.watch(tasksRepositoryProvider).watchStats(ref.watch(todayProvider)),
);

/// The Today's Focus hero numbers (always today, whatever day is picked).
final homeFocusProvider = Provider.autoDispose<AsyncValue<HomeFocus>>((ref) {
  final stats = ref.watch(homeTaskStatsProvider);
  final habits = ref.watch(habitsDaySummaryProvider);
  final reminders = ref.watch(
    homeDayRemindersProvider(ref.watch(todayProvider)),
  );
  final now = ref.watch(minuteClockProvider);
  final goal = ref.watch(settingsProvider.select((s) => s.dailyFocusGoal));
  for (final v in [stats, habits, reminders]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace!);
  }
  if (!stats.hasValue || !habits.hasValue || !reminders.hasValue) {
    return const AsyncLoading();
  }
  final s = stats.requireValue;
  final h = habits.requireValue;
  final left = reminders.requireValue
      .where((o) => !o.isDone && o.reminder.isEnabled && !o.at.isBefore(now))
      .length;
  return AsyncData(
    HomeFocus(
      tasksDone: s.doneToday,
      tasksDue: s.dueTodayTotal,
      goal: goal,
      habitsDone: h.done,
      habitsDue: h.due,
      remindersLeft: left,
    ),
  );
});

/// Day keys (yyyy-MM-dd) of the strip days that have open tasks or
/// pending reminders — the strip's dots.
final homeDotDaysProvider = Provider.autoDispose<Set<String>>((ref) {
  final days = ref.watch(homeWeekDaysProvider);
  if (days.isEmpty) return const {};
  final from = days.first;
  final to = DateUtilsX.addDays(days.last, 1);
  final tasks = ref.watch(_rangeTasksProvider((from, to))).valueOrNull;
  final reminders = ref.watch(_rangeRemindersProvider((from, to))).valueOrNull;
  return {
    for (final t in tasks ?? const <TaskItem>[])
      if (!t.isCompleted && t.dueDate != null) DateUtilsX.dayKey(t.dueDate!),
    for (final o in reminders ?? const <ReminderOccurrence>[])
      if (!o.isDone && o.reminder.isEnabled) DateUtilsX.dayKey(o.at),
  };
});

final _rangeTasksProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, (DateTime, DateTime)>(
      (ref, r) =>
          ref.watch(tasksRepositoryProvider).watchTasksInRange(r.$1, r.$2),
    );

final _rangeRemindersProvider = StreamProvider.autoDispose
    .family<List<ReminderOccurrence>, (DateTime, DateTime)>(
      (ref, r) =>
          ref.watch(remindersRepositoryProvider).watchInRange(r.$1, r.$2),
    );

/// The most recently edited notes (pinned first).
final homeRecentNotesProvider = StreamProvider.autoDispose<List<Note>>(
  (ref) => ref
      .watch(notesRepositoryProvider)
      .watchNotes(const NotesQuery(limit: HomeRules.recentNotes)),
);

/// Unread notification-center entries (the bell's red dot).
final homeUnreadProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(inboxRepositoryProvider).watchUnreadCount(),
);

/// Name for the greeting and avatar: Settings › Profile name, else the
/// signed-in account's name, else empty.
final homeDisplayNameProvider = Provider.autoDispose<String>((ref) {
  final local = ref.watch(settingsProvider.select((s) => s.displayName));
  if (local.trim().isNotEmpty) return local.trim();
  return ref.watch(cloudAccountProvider)?.displayName?.trim() ?? '';
});

/// Live library totals (every module, archive and trash).
final _libraryCountsProvider = StreamProvider.autoDispose<LibraryCounts>(
  (ref) => ref.watch(itemsRepositoryProvider).watchLibraryCounts(),
);

/// Progress of the 3-step "Get started" checklist (null while loading).
final homeGetStartedProvider = Provider.autoDispose<HomeGetStarted?>((ref) {
  final c = ref.watch(_libraryCountsProvider).valueOrNull;
  return c == null ? null : HomeGetStarted.of(c);
});

/// True while the library is completely empty — no note, task, reminder,
/// habit or vault item, not even archived or in Recently Deleted.
final homeFirstRunProvider = Provider.autoDispose<bool>((ref) {
  final c = ref.watch(_libraryCountsProvider).valueOrNull;
  if (c == null) return false;
  return c.notesTotal +
          c.tasksTotal +
          c.remindersTotal +
          c.habitsTotal +
          c.vaultTotal +
          c.archived +
          c.trash ==
      0;
});
