/// ============================================================
/// CALENDAR RULES — pure grid / dot / agenda logic (screen 26)
/// ============================================================
///
/// What: the month grid for a week start, the per-day module dots, and
/// the conversion of tasks, reminder occurrences, habit day statuses and
/// notes into ordered [CalendarEntry] rows.
/// Why: kept out of widgets and providers so it is unit tested without a
/// database, and so Week / Month / Agenda views agree on what a day holds.
///
/// Decisions:
///   • Reminders linked to a task are skipped — the task row stands for
///     them (otherwise every "Remind me" task would appear twice).
///   • Habit dots mark days with a check-in (a log with count > 0); a dot
///     for every scheduled day would paint every cell for daily habits.
///     The agenda still lists every habit scheduled that day.
///   • Notes appear on the day they were created.
///   • Medicine dots mark days with a dose taken (like habits); the agenda
///     lists every dose of the day with how it went.
///   • Timed rows first (by time), then all-day rows, module order
///     Tasks · Reminders · Habits · Notes (as in the mockup).
/// ============================================================
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

abstract final class CalendarRules {
  /// Legend / dot order.
  static const List<ItemType> modules = [
    ItemType.task,
    ItemType.reminder,
    ItemType.habit,
    ItemType.medicine,
    ItemType.note,
  ];

  /// A day cell shows at most this many dots.
  static const int maxDots = 3;

  /// First day of [d]'s month.
  static DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

  /// [month] shifted by [n] months (first of month).
  static DateTime addMonths(DateTime month, int n) =>
      DateTime(month.year, month.month + n);

  /// Whole weeks covering [month] (4–6 rows × 7 days), starting on
  /// [weekStart] (DateTime.monday … DateTime.sunday).
  static List<DateTime> monthGrid(DateTime month, int weekStart) {
    final first = monthOf(month);
    final last = DateTime(first.year, first.month + 1, 0);
    final start = DateUtilsX.startOfWeek(first, weekStart);
    final days = DateUtilsX.daysBetween(start, last) + 1;
    final cells = ((days + 6) ~/ 7) * 7;
    return [for (var i = 0; i < cells; i++) DateUtilsX.addDays(start, i)];
  }

  /// The route's `?date=yyyy-MM-dd` as a local day; null when missing,
  /// malformed or impossible (`2023-02-30`) — the screen then opens on
  /// today instead of failing.
  static DateTime? tryParseDay(String? key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key ?? '');
    if (m == null) return null;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    final day = DateTime(y, mo, d);
    // DateTime normalises overflow (Feb 30 → Mar 2); reject it.
    if (day.year != y || day.month != mo || day.day != d) return null;
    return day;
  }

  /// Weekday numbers (1 = Monday … 7 = Sunday) in column order.
  static List<int> weekdayColumns(int weekStart) => [
    for (var i = 0; i < 7; i++) (weekStart - 1 + i) % 7 + 1,
  ];

  /// Whether a reminder occurrence gets its own calendar row / dot.
  static bool showsReminder(ReminderOccurrence o) =>
      o.reminder.linkedRef?.type != ItemType.task;

  /// Day key → module types with something that day, in [modules] order,
  /// capped at [maxDots].
  static Map<String, List<ItemType>> dots({
    Iterable<TaskItem> tasks = const [],
    Iterable<ReminderOccurrence> reminders = const [],
    Iterable<HabitLog> habitLogs = const [],
    Iterable<DoseLog> doseLogs = const [],
    Iterable<Note> notes = const [],
  }) {
    final byDay = <String, Set<ItemType>>{};
    void add(DateTime? day, ItemType type) {
      if (day == null) return;
      (byDay[DateUtilsX.dayKey(day)] ??= <ItemType>{}).add(type);
    }

    for (final t in tasks) {
      add(t.dueDate, ItemType.task);
    }
    for (final o in reminders) {
      if (showsReminder(o)) add(o.at, ItemType.reminder);
    }
    for (final l in habitLogs) {
      if (l.count > 0 && !l.skipped) add(l.date, ItemType.habit);
    }
    for (final l in doseLogs) {
      if (l.isTaken) add(DateUtilsX.parseDayKey(l.dayKey), ItemType.medicine);
    }
    for (final n in notes) {
      add(n.createdAt, ItemType.note);
    }
    return {
      for (final e in byDay.entries)
        e.key: [
          for (final m in modules)
            if (e.value.contains(m)) m,
        ].take(maxDots).toList(),
    };
  }

  /// Notes created on [day].
  static Iterable<Note> notesOn(Iterable<Note> notes, DateTime day) =>
      notes.where((n) => DateUtilsX.isSameDay(n.createdAt, day));

  /// The ordered agenda of one day.
  static List<CalendarEntry> agenda({
    Iterable<TaskItem> tasks = const [],
    Iterable<ReminderOccurrence> reminders = const [],
    Iterable<HabitDayStatus> habits = const [],
    Iterable<DoseSlot> doses = const [],
    DateTime? now,
    Iterable<Note> notes = const [],
  }) {
    final entries = <CalendarEntry>[
      for (final d in doses) doseEntry(d, now ?? DateTime.now()),
      ...tasks.map(taskEntry),
      ...reminders.where(showsReminder).map(reminderEntry),
      ...habits.where((h) => h.isScheduled).map(habitEntry),
      ...notes.map(noteEntry),
    ];
    entries.sort(compare);
    return entries;
  }

  /// Timed before all-day; then time, module order, title.
  static int compare(CalendarEntry a, CalendarEntry b) {
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? 1 : -1;
    if (!a.isAllDay) {
      final c = a.time!.compareTo(b.time!);
      if (c != 0) return c;
    }
    final m = modules.indexOf(a.type).compareTo(modules.indexOf(b.type));
    if (m != 0) return m;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static String _meta(ItemType type, String? detail) =>
      detail == null || detail.isEmpty ? type.label : '${type.label} · $detail';

  /// "Task · High" (high priority), else "Task · `list or first tag`";
  /// completed tasks read "Task · done".
  static CalendarEntry taskEntry(TaskItem t) {
    final String? detail;
    if (t.isCompleted) {
      detail = tr('done');
    } else if (t.priority == TaskPriority.high) {
      detail = t.priority.label;
    } else {
      detail = t.listName ?? t.tags.firstOrNull?.name;
    }
    return CalendarEntry(
      ref: t.ref,
      title: t.title.trim().isEmpty ? tr('Untitled task') : t.title.trim(),
      time: t.hasDueTime ? t.dueAt : null,
      meta: _meta(ItemType.task, detail),
      done: t.isCompleted,
    );
  }

  static CalendarEntry reminderEntry(ReminderOccurrence o) => CalendarEntry(
    ref: o.reminder.ref,
    title: o.reminder.title.trim().isEmpty
        ? tr('Reminder')
        : o.reminder.title.trim(),
    time: o.at,
    meta: _meta(ItemType.reminder, o.isDone ? tr('done') : null),
    done: o.isDone,
  );

  static CalendarEntry habitEntry(HabitDayStatus s) {
    final String? detail;
    if (s.isDone) {
      detail = tr('done');
    } else if (s.isSkipped) {
      detail = tr('skipped');
    } else if (s.count > 0 && !s.habit.isYesNo) {
      detail = s.progressLabel;
    } else {
      detail = null;
    }
    return CalendarEntry(
      ref: s.habit.ref,
      title: s.habit.name,
      meta: _meta(ItemType.habit, detail),
      done: s.isDone,
    );
  }

  /// "Medicine · 1 tablet · taken".
  static CalendarEntry doseEntry(DoseSlot s, DateTime now) {
    final state = s.stateAt(now);
    final m = s.medicine;
    final detail = [
      MedicineWords.amount(s.quantity, m.form),
      switch (state) {
        DoseState.taken => tr('taken'),
        DoseState.skipped => tr('skipped'),
        DoseState.missed => tr('missed'),
        DoseState.snoozed => tr('snoozed'),
        DoseState.due => tr('due now'),
        DoseState.upcoming => null,
      },
    ].nonNulls.join(' · ');
    return CalendarEntry(
      ref: m.ref,
      title: m.name.trim().isEmpty ? tr('Untitled medicine') : m.name.trim(),
      time: s.at,
      meta: _meta(ItemType.medicine, detail),
      done: state == DoseState.taken,
    );
  }

  static CalendarEntry noteEntry(Note n) => CalendarEntry(
    ref: ItemRef(ItemType.note, n.id),
    title: n.displayTitle,
    time: n.createdAt,
    meta: _meta(ItemType.note, n.folderName),
  );
}
