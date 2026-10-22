/// ============================================================
/// REMINDERS LIST PROVIDERS — screen 12 state
/// ============================================================
///
/// What: the selected chip ([reminderFilterProvider]) and week-strip day
/// ([reminderDayProvider]), the live timeline
/// ([remindersTimelineProvider]((day, scope))), the week dots, the next
/// reminder and the header subtitle.
/// Why: every list is a StreamProvider over RemindersRepository, so a
/// toggle / snooze / edit anywhere updates the timeline at once (rule 5).
/// Time-relative queries (missed, upcoming, snoozed) take "now" from
/// [minuteClockProvider] so they refresh every minute; the timeline keeps
/// its last value while the new minute's query loads (no skeleton flash,
/// no scroll jump). Chip and picked day are autoDispose: leaving the
/// screen resets them, and picking today means "follow today".
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_labels.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_timeline.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Chips of screen 12, in order, with their labels (a getter so the labels
/// follow the active language).
List<(RemindersScope, String)> get reminderFilters => [
  (RemindersScope.today, tr('Today')),
  (RemindersScope.upcoming, tr('Upcoming')),
  (RemindersScope.recurring, tr('Recurring')),
  (RemindersScope.location, tr('Location')),
  (RemindersScope.snoozed, tr('Snoozed')),
];

class ReminderFilterNotifier extends AutoDisposeNotifier<RemindersScope> {
  @override
  RemindersScope build() => RemindersScope.today;

  void set(RemindersScope scope) => state = scope;
}

/// The selected chip.
final reminderFilterProvider =
    NotifierProvider.autoDispose<ReminderFilterNotifier, RemindersScope>(
      ReminderFilterNotifier.new,
    );

/// Day picked in the week strip; null = follow today (also after midnight).
class SelectedReminderDay extends AutoDisposeNotifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Picks [day]; picking today stores null so the strip keeps following
  /// [todayProvider] when the date changes.
  void select(DateTime day) {
    final picked = DateUtilsX.dateOnly(day);
    state = DateUtilsX.isSameDay(picked, ref.read(todayProvider))
        ? null
        : picked;
  }
}

final selectedReminderDayProvider =
    NotifierProvider.autoDispose<SelectedReminderDay, DateTime?>(
      SelectedReminderDay.new,
    );

/// The day shown by the Today chip (midnight).
final reminderDayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(selectedReminderDayProvider) ?? ref.watch(todayProvider),
);

/// Raw repository query (one subscription per distinct query).
final reminderOccurrencesProvider = StreamProvider.autoDispose
    .family<List<ReminderOccurrence>, RemindersQuery>(
      (ref, query) =>
          ref.watch(remindersRepositoryProvider).watchReminders(query),
    );

/// The timeline for (day, chip). While a new minute's query loads it
/// keeps the previous timeline (as loading-with-previous), so the list
/// never flashes the skeleton on the minute tick.
class RemindersTimelineNotifier
    extends
        AutoDisposeFamilyNotifier<
          AsyncValue<ReminderTimeline>,
          (DateTime, RemindersScope)
        > {
  @override
  AsyncValue<ReminderTimeline> build((DateTime, RemindersScope) key) {
    final next = _timeline(key);
    final previous = stateOrNull;
    if (next.isLoading && !next.hasValue && (previous?.hasValue ?? false)) {
      return const AsyncLoading<ReminderTimeline>().copyWithPrevious(previous!);
    }
    return next;
  }

  AsyncValue<ReminderTimeline> _timeline((DateTime, RemindersScope) key) {
    final (day, scope) = key;
    final now = ref.watch(minuteClockProvider);
    AsyncValue<List<ReminderOccurrence>> q(RemindersQuery query) =>
        ref.watch(reminderOccurrencesProvider(query));

    if (scope != RemindersScope.today) {
      return q(
        RemindersQuery(scope: scope, now: now),
      ).whenData((items) => ReminderTimeline.byDay(items, now));
    }
    final isToday = DateUtilsX.isSameDay(day, now);
    final parts = [
      q(RemindersQuery(day: day)),
      q(RemindersQuery(day: DateUtilsX.addDays(day, 1))),
      if (isToday) q(RemindersQuery(scope: RemindersScope.missed, now: now)),
    ];
    return _combine(parts).whenData(
      (lists) => ReminderTimeline.forDay(
        day: day,
        now: now,
        dayItems: lists[0],
        nextDayItems: lists[1],
        missed: isToday ? lists[2] : const [],
      ),
    );
  }
}

final remindersTimelineProvider = NotifierProvider.autoDispose
    .family<
      RemindersTimelineNotifier,
      AsyncValue<ReminderTimeline>,
      (DateTime, RemindersScope)
    >(RemindersTimelineNotifier.new);

/// Data when every part has data; the first error otherwise; else loading.
AsyncValue<List<T>> _combine<T>(List<AsyncValue<T>> parts) {
  for (final p in parts) {
    if (p.hasError && !p.hasValue) {
      return AsyncError<List<T>>(p.error!, p.stackTrace ?? StackTrace.empty);
    }
  }
  if (parts.every((p) => p.hasValue)) {
    return AsyncData([for (final p in parts) p.requireValue]);
  }
  return const AsyncLoading();
}

/// Day keys (`yyyy-MM-dd`) with pending, enabled reminders in the week
/// starting at the given day — the week strip dots.
final reminderWeekDotsProvider = StreamProvider.autoDispose
    .family<Set<String>, DateTime>((ref, weekStart) {
      final end = DateUtilsX.addDays(weekStart, 7);
      return ref
          .watch(remindersRepositoryProvider)
          .watchInRange(weekStart, end)
          .map(
            (items) => {
              for (final o in items)
                if (!o.isDone && o.reminder.isEnabled) DateUtilsX.dayKey(o.at),
            },
          );
    });

/// The soonest upcoming reminder occurrence.
final nextReminderProvider = StreamProvider.autoDispose<ReminderOccurrence?>(
  (ref) => ref
      .watch(remindersRepositoryProvider)
      .watchNext(ref.watch(minuteClockProvider)),
);

/// "3 today · next in 25 min" (null while loading).
final remindersSubtitleProvider = Provider.autoDispose<String?>((ref) {
  final now = ref.watch(minuteClockProvider);
  final today = ref.watch(
    reminderOccurrencesProvider(RemindersQuery(day: ref.watch(todayProvider))),
  );
  final next = ref.watch(nextReminderProvider);
  final items = today.valueOrNull;
  if (items == null || !next.hasValue) return null;
  final count = items.where((o) => !o.isDone && o.reminder.isEnabled).length;
  return ReminderLabels.headerSubtitle(
    today: count,
    next: next.valueOrNull?.at,
    now: now,
  );
});
