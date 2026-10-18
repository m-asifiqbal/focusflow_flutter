/// ============================================================
/// HABIT ROW MAPPER — Drift rows ⇄ habit domain entities
/// ============================================================
///
/// Kept apart from the repository so the repository file only holds
/// queries and writes. Storage details live here: the frequency columns
/// (frequencyType + weekdaysMask / timesPerWeek / everyNDays), reminder
/// times as a JSON array of `HH:mm` strings and days as `yyyy-MM-dd`.
/// ============================================================
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';

abstract final class HabitRowMapper {
  /// Reminder times from the stored JSON (invalid JSON → none).
  static List<String> decodeTimes(String json) {
    try {
      final list = jsonDecode(json);
      return list is List
          ? List.unmodifiable(list.whereType<String>())
          : const [];
    } on FormatException {
      return const [];
    }
  }

  /// Row + its tags → [Habit].
  static Habit habit(HabitRow r, List<Tag> tags) => Habit(
    id: r.id,
    name: r.name,
    iconKey: r.iconKey,
    colorHex: r.colorHex,
    category: r.category,
    kind: r.habitType == 1 ? HabitKind.quit : HabitKind.build,
    targetCount: r.targetCount < 1 ? 1 : r.targetCount,
    unit: r.unit,
    frequency: HabitFrequency.fromStorage(
      type: r.frequencyType,
      weekdaysMask: r.weekdaysMask,
      timesPerWeek: r.timesPerWeek,
      everyNDays: r.everyNDays,
    ),
    partOfDay:
        PartOfDay.values[r.partOfDay.clamp(0, PartOfDay.values.length - 1)],
    reminderEnabled: r.reminderEnabled,
    reminderTimes: decodeTimes(r.reminderTimesJson),
    startDate: DateUtilsX.parseDayKey(r.startDate),
    isPaused: r.isPaused,
    isPinned: r.isPinned,
    isFavorite: r.isFavorite,
    tags: tags,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    archivedAt: r.archivedAt,
    deletedAt: r.deletedAt,
  );

  static HabitLog log(HabitLogRow r) => HabitLog.keyed(
    id: r.id,
    habitId: r.habitId,
    dayKey: r.date,
    count: r.count,
    skipped: r.skipped,
    note: r.note,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  /// Every column of a new habit [h] (no id, timestamps or sync fields):
  /// [editorContent] plus the paused / pinned / favourite flags.
  static HabitsCompanion content(Habit h) => editorContent(h).copyWith(
    isPaused: Value(h.isPaused),
    isPinned: Value(h.isPinned),
    isFavorite: Value(h.isFavorite),
  );

  /// The columns the habit editor owns (name, look, type, goal, schedule,
  /// reminders, start date). Updates write only these, so saving the
  /// editor never reverts a pause / pin / favourite changed meanwhile
  /// (detail More sheet, swipe, another device) — those flags have their
  /// own writers.
  static HabitsCompanion editorContent(Habit h) {
    final f = h.frequency;
    return HabitsCompanion(
      name: Value(h.name.trim()),
      iconKey: Value(h.iconKey),
      colorHex: Value(h.colorHex),
      category: Value(h.category),
      habitType: Value(h.kind.index),
      targetCount: Value(h.targetCount < 1 ? 1 : h.targetCount),
      unit: Value(h.unit),
      frequencyType: Value(f.typeCode),
      weekdaysMask: Value(f is SpecificDaysFrequency ? f.weekdaysMask : 127),
      timesPerWeek: Value(f is TimesPerWeekFrequency ? f.times : 3),
      everyNDays: Value(f is EveryNDaysFrequency ? f.days : 2),
      partOfDay: Value(h.partOfDay.index),
      reminderEnabled: Value(h.reminderEnabled),
      reminderTimesJson: Value(jsonEncode(h.reminderTimes)),
      startDate: Value(DateUtilsX.dayKey(h.startDate)),
    );
  }
}
