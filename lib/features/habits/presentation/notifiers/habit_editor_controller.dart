/// ============================================================
/// HABIT EDITOR CONTROLLER — draft state of screen 15 (new / edit)
/// ============================================================
///
/// `habitEditorControllerProvider((id: …, name: …))` loads the habit being
/// edited (or starts a draft for today, optionally named by Quick Add) and
/// keeps the unsaved [Habit] draft. Widgets only call the intent methods
/// below; [save] writes through HabitsRepository. Reminders are scheduled
/// by the notification engine from the saved fields — the editor never
/// touches notifications itself. Editing the schedule only rewrites the
/// habit row, so existing logs stay intact; streaks and stats are
/// recomputed from them under the new schedule, which the screen confirms
/// first ([HabitEditorState.needsScheduleConfirm]).
///
/// Build ⇄ quit on a habit *with history* is refused ([setKind] returns
/// false, [save] refuses too): the same log means a check-in for a build
/// habit and a slip for a quit habit, so switching would silently turn a
/// streak into a run of slips. The screen offers "Reset history & change
/// type" instead (habit_editor_actions.dart).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/habit_templates.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Which habit the editor opens: [id] null = new habit (optionally
/// pre-named by Quick Add with [name]).
typedef HabitEditorArgs = ({String? id, String? name});

/// The four schedule kinds of the Frequency picker.
enum HabitFrequencyKind {
  everyDay('Every day'),
  specificDays('Specific days'),
  timesPerWeek('X times per week'),
  everyNDays('Every N days');

  const HabitFrequencyKind(this.label);

  final String label;

  static HabitFrequencyKind of(HabitFrequency f) => switch (f) {
    EveryDayFrequency() => everyDay,
    SpecificDaysFrequency() => specificDays,
    TimesPerWeekFrequency() => timesPerWeek,
    EveryNDaysFrequency() => everyNDays,
  };
}

@immutable
class HabitEditorState {
  const HabitEditorState({
    required this.draft,
    required this.initial,
    this.original,
    this.saving = false,
    this.hasHistory = false,
  });

  /// The unsaved habit.
  final Habit draft;

  /// The draft as first opened (dirty check).
  final Habit initial;

  /// The stored habit when editing; null for a new habit.
  final Habit? original;
  final bool saving;

  /// The edited habit has at least one log (always false for a new habit).
  /// Refreshed by [HabitEditorController.refreshHistory].
  final bool hasHistory;

  bool get isNew => original == null;

  /// Build ⇄ quit differs from the stored habit.
  bool get changesKind => original != null && draft.kind != original!.kind;

  /// The type change would reinterpret existing logs (see the file header).
  bool get kindChangeBlocked => changesKind && hasHistory;

  /// What of the goal / schedule differs from the stored habit, in words
  /// ("daily target", "schedule", "start date"); empty for a new habit.
  List<String> get scheduleChanges {
    final o = original;
    if (o == null) return const [];
    return [
      if (draft.targetCount != o.targetCount) 'daily target',
      if (draft.frequency != o.frequency) 'schedule',
      if (!_sameDay(draft.startDate, o.startDate)) 'start date',
    ];
  }

  /// Saving re-evaluates existing history with a new goal / schedule, so
  /// the screen asks first.
  bool get needsScheduleConfirm => hasHistory && scheduleChanges.isNotEmpty;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool get isDirty => draft != initial;

  /// Specific days need at least one day.
  bool get hasValidSchedule => switch (draft.frequency) {
    SpecificDaysFrequency(:final weekdaysMask) => weekdaysMask & 0x7F != 0,
    _ => true,
  };

  bool get canSave =>
      !saving && draft.name.trim().isNotEmpty && hasValidSchedule;

  HabitEditorState copyWith({Habit? draft, bool? saving, bool? hasHistory}) =>
      HabitEditorState(
        draft: draft ?? this.draft,
        initial: initial,
        original: original,
        saving: saving ?? this.saving,
        hasHistory: hasHistory ?? this.hasHistory,
      );
}

class HabitEditorController
    extends AutoDisposeFamilyAsyncNotifier<HabitEditorState?, HabitEditorArgs> {
  /// Bounds of the daily target stepper.
  static const int minTarget = 1;
  static const int maxTarget = 999;

  @override
  Future<HabitEditorState?> build(HabitEditorArgs arg) async {
    final id = arg.id;
    if (id != null) {
      final repo = ref.read(habitsRepositoryProvider);
      final habit = await repo.getHabit(id);
      if (habit == null) return null;
      return HabitEditorState(
        draft: habit,
        initial: habit,
        original: habit,
        hasHistory: await _hasLogs(repo, id),
      );
    }
    final draft = Habit.draft(
      startDate: ref.read(habitTodayProvider),
      name: arg.name?.trim() ?? '',
      colorHex: HabitPalette.hexOf(HabitPalette.blue),
    );
    return HabitEditorState(draft: draft, initial: draft);
  }

  HabitEditorState? get _s => state.valueOrNull;

  static Future<bool> _hasLogs(HabitsRepository repo, String id) async =>
      ((await repo.watchHabitWithLogs(id).first)?.logs ?? const []).isNotEmpty;

  /// Re-reads whether the edited habit has logs (they can change while the
  /// editor is open: Undo of a reset, a check-in from a notification).
  /// Returns the fresh value.
  Future<bool> refreshHistory() async {
    final id = _s?.original?.id;
    if (id == null) return false;
    final has = await _hasLogs(ref.read(habitsRepositoryProvider), id);
    final s = _s;
    if (s != null && s.hasHistory != has) {
      state = AsyncData(s.copyWith(hasHistory: has));
    }
    return has;
  }

  /// Applies [change] to the draft.
  void edit(Habit Function(Habit draft) change) {
    final s = _s;
    if (s == null || s.saving) return;
    state = AsyncData(s.copyWith(draft: change(s.draft)));
  }

  void setName(String name) => edit((d) => d.copyWith(name: name));

  void setIcon(String key) => edit((d) => d.copyWith(iconKey: key));

  void setColorHex(String hex) => edit((d) => d.copyWith(colorHex: hex));

  void setCategory(String category) =>
      edit((d) => d.copyWith(category: category));

  /// Time of day: decides which chip (Morning / Evening) lists the habit.
  void setPartOfDay(PartOfDay part) => edit((d) => d.copyWith(partOfDay: part));

  /// Build / quit. Quit habits ignore the schedule (every day counts), so
  /// switching to quit also resets the frequency to "Every day".
  ///
  /// Refused (returns false, draft unchanged) when it would move an
  /// existing habit with history away from its stored type — its logs
  /// would change meaning. Switching back to the stored type is allowed.
  bool setKind(HabitKind kind) {
    final s = _s;
    if (s == null || s.saving) return false;
    if (s.original != null && s.hasHistory && kind != s.original!.kind) {
      return false;
    }
    _applyKind(kind);
    return true;
  }

  void _applyKind(HabitKind kind) => edit(
    (d) => d.copyWith(
      kind: kind,
      frequency: kind == HabitKind.quit
          ? const HabitFrequency.everyDay()
          : null,
      // A quit habit counts slips: one is enough to break the day.
      targetCount: kind == HabitKind.quit ? 1 : null,
      unit: kind == HabitKind.quit
          ? 'slips'
          : (d.unit == 'slips' ? 'times' : null),
    ),
  );

  /// Daily target (clamped to [minTarget]…[maxTarget]).
  void setTarget(int value) => edit(
    (d) => d.copyWith(targetCount: value.clamp(minTarget, maxTarget).toInt()),
  );

  void setUnit(String unit) {
    final u = unit.trim();
    if (u.isNotEmpty) edit((d) => d.copyWith(unit: u));
  }

  /// Switches the schedule kind, keeping sensible defaults.
  void setFrequencyKind(HabitFrequencyKind kind) => edit((d) {
    if (HabitFrequencyKind.of(d.frequency) == kind) return d;
    return d.copyWith(
      frequency: switch (kind) {
        HabitFrequencyKind.everyDay => const HabitFrequency.everyDay(),
        HabitFrequencyKind.specificDays => HabitFrequency.weekdays,
        HabitFrequencyKind.timesPerWeek => const HabitFrequency.timesPerWeek(3),
        HabitFrequencyKind.everyNDays => const HabitFrequency.everyNDays(2),
      },
    );
  });

  /// Toggles [weekday] (`DateTime.monday …`) of a day-based schedule. All
  /// seven days collapse to "Every day".
  void toggleWeekday(int weekday) => edit((d) {
    final mask = switch (d.frequency) {
      SpecificDaysFrequency(:final weekdaysMask) => weekdaysMask & 0x7F,
      _ => 0x7F,
    };
    final next = mask ^ (1 << (weekday - 1));
    return d.copyWith(
      frequency: next == 0x7F
          ? const HabitFrequency.everyDay()
          : HabitFrequency.specificDays(next),
    );
  });

  /// "X times per week" (1–7).
  void setTimesPerWeek(int times) => edit(
    (d) => d.copyWith(
      frequency: HabitFrequency.timesPerWeek(times.clamp(1, 7).toInt()),
    ),
  );

  /// "Every N days" (2–30).
  void setEveryNDays(int days) => edit(
    (d) => d.copyWith(
      frequency: HabitFrequency.everyNDays(days.clamp(2, 30).toInt()),
    ),
  );

  /// Remind me on/off. Turning it on adds a 09:00 time when there is none
  /// and asks for notification permission (best effort).
  void setReminderEnabled(bool on) {
    edit(
      (d) => d.copyWith(
        reminderEnabled: on,
        reminderTimes: on && d.reminderTimes.isEmpty ? const ['09:00'] : null,
      ),
    );
    if (on) unawaited(_askPermission());
  }

  Future<void> _askPermission() async {
    try {
      await requestNotificationPermission(ref);
    } on Object {
      // No plugin (tests) or the OS refused to ask — reminders stay saved
      // and the engine reports the missing permission elsewhere.
    }
  }

  /// Adds [time] (`HH:mm`); times stay sorted and unique.
  void addReminderTime(String time) => edit(
    (d) => d.copyWith(
      reminderEnabled: true,
      reminderTimes: ({...d.reminderTimes, time}.toList()..sort()),
    ),
  );

  void removeReminderTime(String time) => edit((d) {
    final times = [...d.reminderTimes]..remove(time);
    return d.copyWith(reminderTimes: times, reminderEnabled: times.isNotEmpty);
  });

  void setStartDate(DateTime day) =>
      edit((d) => d.copyWith(startDate: DateUtilsX.dateOnly(day)));

  /// Fills every field from [template].
  void applyTemplate(HabitTemplate template) => edit(template.applyTo);

  /// Saves the draft (create or update). Returns the habit id, or null when
  /// the draft can't be saved yet.
  ///
  /// Refused (null) while a build ⇄ quit change would reinterpret existing
  /// history ([HabitEditorState.kindChangeBlocked], re-checked here).
  Future<String?> save() async {
    if (_s?.changesKind ?? false) await refreshHistory();
    final s = _s;
    if (s == null || !s.canSave || s.kindChangeBlocked) return null;
    state = AsyncData(s.copyWith(saving: true));
    try {
      // Times are kept while "Remind me" is off so switching it back on
      // restores them; the engine only schedules enabled reminders.
      return await ref
          .read(habitsRepositoryProvider)
          .save(s.draft.copyWith(name: s.draft.name.trim()));
    } finally {
      final now = _s;
      if (now != null) state = AsyncData(now.copyWith(saving: false));
    }
  }

  /// Editor "Reset history": deletes every log of the edited habit and
  /// returns them, so the Undo snackbar can restore them with
  /// `HabitsRepository.restoreLogs` (the Undo must not depend on this
  /// auto-disposed controller still being alive).
  Future<List<HabitLog>> resetHistory() async {
    final id = _s?.original?.id;
    if (id == null) return const [];
    final repo = ref.read(habitsRepositoryProvider);
    final logs = (await repo.watchHabitWithLogs(id).first)?.logs ?? const [];
    await repo.resetHistory(id);
    final s = _s;
    if (s != null) state = AsyncData(s.copyWith(hasHistory: false));
    return logs;
  }

  /// "Reset history & change type": resets the history (returned for the
  /// Undo) and then switches the draft to [kind].
  Future<List<HabitLog>> resetHistoryAndSetKind(HabitKind kind) async {
    final removed = await resetHistory();
    _applyKind(kind);
    return removed;
  }

  /// Undo of [resetHistory]: writes [logs] back in one transaction.
  Future<void> restoreHistory(List<HabitLog> logs) async {
    await ref.read(habitsRepositoryProvider).restoreLogs(logs);
    final s = _s;
    if (s != null && logs.isNotEmpty) {
      state = AsyncData(s.copyWith(hasHistory: true));
    }
  }
}

final habitEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<HabitEditorController, HabitEditorState?, HabitEditorArgs>(
      HabitEditorController.new,
    );
