/// ============================================================
/// CALENDAR PROVIDERS — view state, month dots, day agendas (screen 26)
/// ============================================================
///
/// What:
///   • [calendarViewProvider] — mode (Week / Month / Agenda), the selected
///     day and the visible month; keyed by the route's `?date=` so a deep
///     link opens on that day.
///   • [calendarDotsProvider] — module dots per day over a date range
///     (the month grid or the week row), live over the repositories.
///   • [calendarAgendaProvider] — the ordered entries of one day.
/// Why: every list is a stream, so completing a task or checking in a
/// habit anywhere updates the grid and agenda at once. Grid / ordering
/// rules live in [CalendarRules] (pure, unit tested).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/domain/services/calendar_rules.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

// ───────────────────────── View state ─────────────────────────

/// What the calendar screen is showing.
@immutable
class CalendarViewState {
  const CalendarViewState({
    required this.mode,
    required this.selectedDay,
    required this.month,
  });

  final CalendarMode mode;

  /// The day whose agenda is listed (local midnight).
  final DateTime selectedDay;

  /// First day of the visible month (Month view title + grid).
  final DateTime month;

  CalendarViewState copyWith({
    CalendarMode? mode,
    DateTime? selectedDay,
    DateTime? month,
  }) => CalendarViewState(
    mode: mode ?? this.mode,
    selectedDay: selectedDay ?? this.selectedDay,
    month: month ?? this.month,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarViewState &&
      other.mode == mode &&
      other.selectedDay == selectedDay &&
      other.month == month;

  @override
  int get hashCode => Object.hash(mode, selectedDay, month);
}

/// Mode / selection / month navigation. The family argument is the
/// initial day (route `?date=`), null = today.
class CalendarController
    extends AutoDisposeFamilyNotifier<CalendarViewState, DateTime?> {
  @override
  CalendarViewState build(DateTime? initialDay) {
    final day = DateUtilsX.dateOnly(initialDay ?? ref.read(todayProvider));
    return CalendarViewState(
      mode: CalendarMode.month,
      selectedDay: day,
      month: CalendarRules.monthOf(day),
    );
  }

  void setMode(CalendarMode mode) {
    state = state.copyWith(
      mode: mode,
      month: CalendarRules.monthOf(state.selectedDay),
    );
  }

  /// Selects [day] (and shows its month).
  void select(DateTime day) {
    final d = DateUtilsX.dateOnly(day);
    state = state.copyWith(selectedDay: d, month: CalendarRules.monthOf(d));
  }

  /// Month view: shows the previous / next month and selects the same day
  /// number in it (clamped), or today when that month contains today.
  void shiftMonth(int delta) {
    final month = CalendarRules.addMonths(state.month, delta);
    final today = ref.read(todayProvider);
    final DateTime day;
    if (CalendarRules.monthOf(today) == month) {
      day = today;
    } else {
      final last = DateTime(month.year, month.month + 1, 0).day;
      final n = state.selectedDay.day.clamp(1, last);
      day = DateTime(month.year, month.month, n);
    }
    state = state.copyWith(selectedDay: day, month: month);
  }

  /// Week / Agenda view: moves the selection by whole weeks.
  void shiftWeek(int delta) =>
      select(DateUtilsX.addDays(state.selectedDay, 7 * delta));

  void goToToday() => select(ref.read(todayProvider));
}

final calendarViewProvider = NotifierProvider.autoDispose
    .family<CalendarController, CalendarViewState, DateTime?>(
      CalendarController.new,
    );

/// Week-view drag-to-reschedule over the tasks repository.
class CalendarRescheduler {
  const CalendarRescheduler(this._tasks);

  final TasksRepository _tasks;

  /// Moves [entry]'s task to [day] (its time of day and linked reminder
  /// follow). Returns the previous due day for Undo, or null when nothing
  /// changed (not a task, gone, or already on [day]).
  Future<DateTime?> move(CalendarEntry entry, DateTime day) async {
    if (!entry.canReschedule) return null;
    final task = await _tasks.getTask(entry.ref.id);
    final previous = task?.dueDate;
    if (task == null || previous == null) return null;
    if (DateUtilsX.isSameDay(previous, day)) return null;
    await _tasks.reschedule([entry.ref.id], DateUtilsX.dateOnly(day));
    return previous;
  }

  /// Undo of [move]: puts the task back on [previous].
  Future<void> restore(CalendarEntry entry, DateTime previous) =>
      _tasks.reschedule([entry.ref.id], previous);
}

final calendarReschedulerProvider = Provider.autoDispose<CalendarRescheduler>(
  (ref) => CalendarRescheduler(ref.watch(tasksRepositoryProvider)),
);

/// Moves a task row to [day] (week-view drag); returns the previous day
/// for Undo (see [CalendarRescheduler.move]).
Future<DateTime?> rescheduleCalendarEntry(
  WidgetRef ref,
  CalendarEntry entry,
  DateTime day,
) => ref.read(calendarReschedulerProvider).move(entry, day);

// ───────────────────────── Sources ─────────────────────────

/// A half-open day range [from, to).
typedef CalendarRange = ({DateTime from, DateTime to});

/// The range covered by [days] (a month grid or a week row).
CalendarRange calendarRangeOf(List<DateTime> days) =>
    (from: days.first, to: DateUtilsX.addDays(days.last, 1));

/// Active notes (created-at drives their calendar day).
final calendarNotesProvider = StreamProvider.autoDispose<List<Note>>(
  (ref) => ref
      .watch(notesRepositoryProvider)
      .watchNotes(const NotesQuery(sort: NotesSort.created)),
);

final _tasksInRangeProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, CalendarRange>(
      (ref, r) =>
          ref.watch(tasksRepositoryProvider).watchTasksInRange(r.from, r.to),
    );

final _remindersInRangeProvider = StreamProvider.autoDispose
    .family<List<ReminderOccurrence>, CalendarRange>(
      (ref, r) =>
          ref.watch(remindersRepositoryProvider).watchInRange(r.from, r.to),
    );

final _habitLogsInRangeProvider = StreamProvider.autoDispose
    .family<List<HabitLog>, CalendarRange>(
      (ref, r) => ref
          .watch(habitsRepositoryProvider)
          .watchLogsInRange(r.from, DateUtilsX.addDays(r.to, -1)),
    );

final _tasksForDayProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, DateTime>(
      (ref, day) => ref.watch(tasksRepositoryProvider).watchTasksForDay(day),
    );

final _remindersForDayProvider = StreamProvider.autoDispose
    .family<List<ReminderOccurrence>, DateTime>(
      (ref, day) => ref.watch(remindersRepositoryProvider).watchForDay(day),
    );

final _habitsForDayProvider = StreamProvider.autoDispose
    .family<List<HabitDayStatus>, DateTime>((ref, day) {
      final weekStart = ref.watch(
        settingsProvider.select((s) => s.weekStartsOn),
      );
      return ref
          .watch(habitsRepositoryProvider)
          .watchTodayHabits(day, weekStartsOn: weekStart);
    });

// ───────────────────────── Derived ─────────────────────────

/// Combines several async sources: error if any failed, loading while any
/// has no value yet, otherwise [build] over the values.
AsyncValue<T> _combine<T>(
  List<AsyncValue<Object?>> sources,
  T Function() build,
) {
  for (final s in sources) {
    if (s.hasError && !s.hasValue) {
      return AsyncError<T>(s.error!, s.stackTrace ?? StackTrace.empty);
    }
  }
  if (sources.any((s) => !s.hasValue)) return AsyncLoading<T>();
  return AsyncData(build());
}

/// Day key → module dots over [range] (grid or week row).
final calendarDotsProvider = Provider.autoDispose
    .family<AsyncValue<Map<String, List<ItemType>>>, CalendarRange>((ref, r) {
      final tasks = ref.watch(_tasksInRangeProvider(r));
      final reminders = ref.watch(_remindersInRangeProvider(r));
      final logs = ref.watch(_habitLogsInRangeProvider(r));
      final notes = ref.watch(calendarNotesProvider);
      return _combine(
        [tasks, reminders, logs, notes],
        () => CalendarRules.dots(
          tasks: tasks.requireValue,
          reminders: reminders.requireValue,
          habitLogs: logs.requireValue,
          notes: notes.requireValue.where(
            (n) => !n.createdAt.isBefore(r.from) && n.createdAt.isBefore(r.to),
          ),
        ),
      );
    });

/// The ordered agenda of [day] (local midnight).
final calendarAgendaProvider = Provider.autoDispose
    .family<AsyncValue<List<CalendarEntry>>, DateTime>((ref, day) {
      final tasks = ref.watch(_tasksForDayProvider(day));
      final reminders = ref.watch(_remindersForDayProvider(day));
      final habits = ref.watch(_habitsForDayProvider(day));
      final notes = ref.watch(calendarNotesProvider);
      return _combine(
        [tasks, reminders, habits, notes],
        () => CalendarRules.agenda(
          tasks: tasks.requireValue,
          reminders: reminders.requireValue,
          habits: habits.requireValue,
          notes: CalendarRules.notesOn(notes.requireValue, day),
        ),
      );
    });

/// Re-subscribes every source of [day]'s agenda (error state "Retry").
void retryCalendarAgenda(WidgetRef ref, DateTime day) {
  ref
    ..invalidate(_tasksForDayProvider(day))
    ..invalidate(_remindersForDayProvider(day))
    ..invalidate(_habitsForDayProvider(day))
    ..invalidate(calendarNotesProvider);
}

/// Re-subscribes every source of the dots over [range] (error "Retry").
void retryCalendarDots(WidgetRef ref, CalendarRange range) {
  ref
    ..invalidate(_tasksInRangeProvider(range))
    ..invalidate(_remindersInRangeProvider(range))
    ..invalidate(_habitLogsInRangeProvider(range))
    ..invalidate(calendarNotesProvider);
}
