/// ============================================================
/// WIDGET SNAPSHOT BUILDER — what Android home-screen widgets show
/// ============================================================
///
/// What: turns today's data (tasks, reminders, habits, medicine doses,
/// recent notes) into ONE small JSON document that the native widgets render
/// without ever opening the encrypted database: the app pushes it to the
/// launcher side ([HomeWidgetChannel]) whenever something changes.
/// Why: the SQLite file is encrypted with a Keystore key — native code
/// cannot read it, and must not (rule 2). The snapshot holds only what a
/// widget shows (titles, times, counts, ids for taps), never a vault item,
/// a note's body beyond a short preview (and none for locked notes, or when
/// "Show note text" is off), nor any key.
/// Every user-visible word is in [labels] (already translated), so the
/// native side needs no string resources of its own and follows the app's
/// language. Colours come from the app's module / accent tokens.
/// Lifecycle (rule 3): archived and deleted items never appear — the
/// repositories' active queries already exclude them.
/// ============================================================
library;

import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:flutter/painting.dart' show Color;

/// The widget kinds (provider classes natively); [today] shows several
/// sections together, the others one each.
abstract final class WidgetKinds {
  static const today = 'today';
  static const tasks = 'tasks';
  static const habits = 'habits';
  static const medicines = 'medicines';
  static const reminders = 'reminders';
  static const notes = 'notes';

  static const all = [today, tasks, habits, medicines, reminders, notes];

  /// The sections a widget can hold, in display order.
  static const sections = [tasks, habits, medicines, reminders, notes];
}

/// Bumped when the document's shape changes (the native side ignores a
/// version it does not know and keeps its last good snapshot).
const int widgetSnapshotVersion = 1;

class WidgetSnapshotBuilder {
  const WidgetSnapshotBuilder({
    required this.tasks,
    required this.reminders,
    required this.habits,
    required this.medicines,
    required this.notes,
    required this.settings,
    required this.now,
  });

  final TasksRepository tasks;
  final RemindersRepository reminders;
  final HabitsRepository habits;
  final MedicinesRepository medicines;
  final NotesRepository notes;
  final AppSettings settings;
  final DateTime now;

  /// Most items a widget list carries per section.
  static const int maxItems = 10;

  /// Longest note preview (characters).
  static const int previewChars = 90;

  Future<Map<String, Object?>> build() async {
    final today = DateUtilsX.dateOnly(now);
    final (taskList, reminderList, habitList, medDay, noteList) = await (
      tasks.watchTasks(TasksQuery(scope: TasksScope.today, day: today)).first,
      reminders.watchForDay(today).first,
      habits.watchTodayHabits(today, weekStartsOn: settings.weekStartsOn).first,
      medicines.watchDay(today).first,
      notes.watchNotes(const NotesQuery(limit: maxItems)).first,
    ).wait;
    return compose(
      taskList: taskList,
      reminderList: [
        for (final o in reminderList)
          if (!o.isDone && o.reminder.isEnabled) o,
      ],
      habitList: habitList,
      slots: medDay.slots,
      noteList: noteList,
    );
  }

  /// Pure assembly (tests feed it directly).
  Map<String, Object?> compose({
    required List<TaskItem> taskList,
    required List<ReminderOccurrence> reminderList,
    required List<HabitDayStatus> habitList,
    required List<DoseSlot> slots,
    required List<Note> noteList,
  }) {
    final use24h = settings.use24HourTime;
    String time(DateTime t) =>
        DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);
    String minutes(int m) =>
        time(DateUtilsX.atMinutes(DateUtilsX.dateOnly(now), m));
    final today = DateUtilsX.dateOnly(now);

    // ── tasks: overdue first, then today by time, completed last ──
    final ordered = HomeRules.orderTasks(taskList);
    bool overdue(TaskItem t) => t.isOverdue(now);
    final taskItems = [
      ...ordered.where((t) => !t.isCompleted && overdue(t)),
      ...ordered.where((t) => !t.isCompleted && !overdue(t)),
      if (settings.widgetsShowCompleted) ...ordered.where((t) => t.isCompleted),
    ];
    final openTasks = taskList.where((t) => !t.isCompleted).length;

    // ── habits ──
    final dueHabits = [
      for (final s in habitList)
        if (s.isScheduled && !s.habit.isPaused) s,
    ];
    final habitsDone = dueHabits.where((s) => s.isDone).length;

    // ── medicines ──
    final doses = [
      for (final s in slots)
        if (!s.isAsNeeded) s,
    ];
    int taken = 0;
    final doseItems = <Map<String, Object?>>[];
    for (final s in doses) {
      final state = s.stateAt(now);
      if (state == DoseState.taken) taken++;
      doseItems.add({
        'id': s.medicine.id,
        't': s.medicine.displayName,
        'sub': minutes(s.minutes),
        'st': state.name,
        'day': DateUtilsX.dayKey(s.day),
        'min': s.minutes,
        'r': AppRoutes.medicine(s.medicine.id),
      });
    }

    final remindersLeft = reminderList.length;
    return {
      'v': widgetSnapshotVersion,
      'day': DateUtilsX.dayKey(today),
      'at': now.millisecondsSinceEpoch,
      'prefs': {
        'theme': settings.widgetsTheme.name,
        'appTheme': settings.themeMode.name,
        'accent': _hex(settings.accent.primary),
        'noteText': settings.widgetsShowNoteText,
        'done': settings.widgetsShowCompleted,
      },
      'colors': {
        WidgetKinds.tasks: _hex(ModuleStyle.tasks.solid),
        WidgetKinds.habits: _hex(ModuleStyle.habits.solid),
        WidgetKinds.medicines: _hex(ModuleStyle.medicines.solid),
        WidgetKinds.reminders: _hex(ModuleStyle.reminders.solid),
        WidgetKinds.notes: _hex(ModuleStyle.notes.solid),
      },
      'labels': labels(),
      'routes': {
        'home': AppRoutes.home,
        WidgetKinds.tasks: AppRoutes.tasks,
        WidgetKinds.habits: AppRoutes.habits,
        WidgetKinds.medicines: AppRoutes.medicines,
        WidgetKinds.reminders: AppRoutes.reminders,
        WidgetKinds.notes: AppRoutes.notes,
        'add:${WidgetKinds.tasks}': AppRoutes.newTaskPath,
        'add:${WidgetKinds.habits}': AppRoutes.newHabitPath,
        'add:${WidgetKinds.medicines}': AppRoutes.newMedicinePath,
        'add:${WidgetKinds.reminders}': AppRoutes.newReminderPath,
        'add:${WidgetKinds.notes}': AppRoutes.newNote,
        'add:${WidgetKinds.today}': AppRoutes.newTaskPath,
      },
      WidgetKinds.tasks: {
        'n': openTasks,
        'items': [
          for (final t in taskItems.take(maxItems))
            {
              'id': t.id,
              't': t.title.trim().isEmpty ? tr('Untitled task') : t.title,
              'sub': overdue(t) && !t.isCompleted
                  ? tr('Overdue')
                  : (t.dueTimeMinutes == null
                        ? ''
                        : minutes(t.dueTimeMinutes!)),
              'done': t.isCompleted,
              'od': overdue(t) && !t.isCompleted,
              'r': AppRoutes.task(t.id),
            },
        ],
      },
      WidgetKinds.habits: {
        'n': dueHabits.length - habitsDone,
        'total': dueHabits.length,
        'done': habitsDone,
        'items': [
          for (final s in dueHabits.take(maxItems))
            {
              'id': s.habit.id,
              't': s.habit.name,
              'sub': s.progressLabel,
              'done': s.isDone,
              'c': s.count,
              'g': s.habit.isYesNo ? 1 : s.habit.targetCount,
              'p': s.progress,
              'streak': s.currentStreak,
              'r': AppRoutes.habit(s.habit.id),
            },
        ],
      },
      WidgetKinds.medicines: {
        'n': doses.length - taken,
        'total': doses.length,
        'done': taken,
        'items': doseItems.take(maxItems).toList(),
      },
      WidgetKinds.reminders: {
        'n': remindersLeft,
        'items': [
          for (final o in reminderList.take(maxItems))
            {
              'id': o.reminder.id,
              't': o.reminder.title.trim().isEmpty
                  ? tr('Untitled reminder')
                  : o.reminder.title,
              'sub': time(o.at),
              'od': o.at.isBefore(now),
              'r': AppRoutes.open(ItemRef(ItemType.reminder, o.reminder.id)),
            },
        ],
      },
      WidgetKinds.notes: {
        'n': noteList.length,
        'items': [for (final n in noteList.take(maxItems)) _note(n)],
      },
    };
  }

  Map<String, Object?> _note(Note n) {
    final locked = n.isLocked;
    final title = locked
        ? tr('Locked note')
        : (n.title.trim().isEmpty ? tr('Untitled note') : n.title);
    final text = locked || !settings.widgetsShowNoteText
        ? ''
        : n.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return {
      'id': n.id,
      't': title,
      'sub': text.length > previewChars
          ? '${text.substring(0, previewChars)}…'
          : text,
      'pin': n.isPinned,
      'lock': locked,
      'r': AppRoutes.note(n.id),
    };
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Every word the native side shows, in the app's language. Placeholders
  /// are `{n}`.
  static Map<String, String> labels() => {
    'app': AppInfo.name,
    'today': tr('Today'),
    'overview': tr('Overview'),
    WidgetKinds.tasks: tr('Tasks'),
    WidgetKinds.habits: tr('Habits'),
    WidgetKinds.medicines: tr('Medicine'),
    WidgetKinds.reminders: tr('Reminders'),
    WidgetKinds.notes: tr('Notes'),
    'add': tr('Add'),
    // The native side fills the number in: keep the placeholder as text.
    'left': tr('{n} left', {'n': '{n}'}),
    'allDone': tr('All done'),
    'empty.${WidgetKinds.tasks}': tr('Nothing due today'),
    'empty.${WidgetKinds.habits}': tr('No habits for today'),
    'empty.${WidgetKinds.medicines}': tr('No doses today'),
    'empty.${WidgetKinds.reminders}': tr('No reminders left today'),
    'empty.${WidgetKinds.notes}': tr('No notes yet'),
    'empty.all': tr('Nothing planned. Enjoy your day!'),
    'noData': tr('Open FocusFlow to set up this widget'),
    'config.title': tr('Widget settings'),
    'config.theme': tr('Theme'),
    'config.themeApp': tr('Follow the app'),
    'config.themeLight': tr('Light'),
    'config.themeDark': tr('Dark'),
    'config.background': tr('Background'),
    'config.bgSolid': tr('Solid'),
    'config.bgSoft': tr('Soft'),
    'config.bgClear': tr('Clear'),
    'config.sections': tr('Sections'),
    'config.save': tr('Save'),
  };
}
