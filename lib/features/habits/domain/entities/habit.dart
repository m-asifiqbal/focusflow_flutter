/// ============================================================
/// HABIT — a recurring behaviour to build (Drink water) or quit (No sugar)
/// ============================================================
///
/// Plain immutable domain entity (no Drift). Day-level semantics live here
/// ([isDoneWith], [progressWith]) so every screen and the pure services
/// (HabitSchedule, StreakCalculator, HabitStatsCalculator) agree:
///   • build habit — done when the day's count ≥ [targetCount].
///   • quit habit  — the log count is *slips*; a day is clean (done) when
///     no slip is logged. "Days since last slip" is the streak.
/// A new, unsaved habit has an empty [id] (see [isNew]).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';

/// 0 build · 1 quit (stored in `habits.habit_type`).
enum HabitKind { build, quit }

/// List filter chips; stored in `habits.part_of_day` as the index.
enum PartOfDay { anytime, morning, afternoon, evening }

@immutable
class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.iconKey = 'star',
    this.colorHex,
    this.category = 'Health',
    this.kind = HabitKind.build,
    this.targetCount = 1,
    this.unit = 'times',
    this.frequency = const HabitFrequency.everyDay(),
    this.partOfDay = PartOfDay.anytime,
    this.reminderEnabled = false,
    this.reminderTimes = const [],
    required this.startDate,
    this.isPaused = false,
    this.isPinned = false,
    this.isFavorite = false,
    this.tags = const [],
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  /// An unsaved habit for the editor (empty id; timestamps = [startDate]).
  factory Habit.draft({
    required DateTime startDate,
    String name = '',
    String iconKey = 'star',
    String? colorHex,
    String category = 'Health',
    HabitKind kind = HabitKind.build,
    int targetCount = 1,
    String unit = 'times',
    HabitFrequency frequency = const HabitFrequency.everyDay(),
    PartOfDay partOfDay = PartOfDay.anytime,
  }) => Habit(
    id: '',
    name: name,
    iconKey: iconKey,
    colorHex: colorHex,
    category: category,
    kind: kind,
    targetCount: targetCount,
    unit: unit,
    frequency: frequency,
    partOfDay: partOfDay,
    startDate: DateTime(startDate.year, startDate.month, startDate.day),
    createdAt: startDate,
    updatedAt: startDate,
  );

  final String id;
  final String name;

  /// Key into the habit icon catalogue (features/habits/presentation).
  final String iconKey;

  /// `RRGGBB`; null = module default (indigo).
  final String? colorHex;
  final String category;
  final HabitKind kind;

  /// Daily goal (8 glasses). 1 = a simple yes/no habit.
  final int targetCount;

  /// Unit label for [targetCount] ("glasses", "min", "pages", "times").
  final String unit;
  final HabitFrequency frequency;
  final PartOfDay partOfDay;
  final bool reminderEnabled;

  /// Reminder times as `HH:mm` strings (24 h).
  final List<String> reminderTimes;

  /// First day the habit counts (local midnight).
  final DateTime startDate;
  final bool isPaused;
  final bool isPinned;
  final bool isFavorite;
  final List<Tag> tags;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemRef get ref => ItemRef(ItemType.habit, id);
  bool get isNew => id.isEmpty;
  bool get isQuit => kind == HabitKind.quit;

  /// Yes/no habit (target 1): the list button toggles instead of counting.
  bool get isYesNo => targetCount <= 1;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;

  /// The goal of one due day, as in the editor preview (mockup 15):
  /// "8 glasses daily" (counted), "Every day" / "Weekdays" (yes/no — the
  /// schedule is the goal), "Quit habit".
  String get goalLabel {
    if (isQuit) return 'Quit habit';
    if (isYesNo) return frequency.label;
    return '$targetCount $unit daily';
  }

  /// Whether [log] (the log of one day, or null) counts as done for this
  /// habit. Build: count ≥ target and not skipped. Quit: no slip logged
  /// (a skipped quit day counts as clean).
  bool isDoneWith(HabitLog? log) {
    if (isQuit) return log == null || log.skipped || log.count <= 0;
    return log != null && !log.skipped && log.count >= targetCount;
  }

  /// 0…1 progress of one day. Build: count / target (capped);
  /// quit: 1 when clean, 0 after a slip.
  double progressWith(HabitLog? log) {
    if (isQuit) return isDoneWith(log) ? 1 : 0;
    if (log == null || log.skipped || targetCount <= 0) return 0;
    return (log.count / targetCount).clamp(0, 1).toDouble();
  }

  Habit copyWith({
    String? id,
    String? name,
    String? iconKey,
    String? colorHex,
    bool clearColor = false,
    String? category,
    HabitKind? kind,
    int? targetCount,
    String? unit,
    HabitFrequency? frequency,
    PartOfDay? partOfDay,
    bool? reminderEnabled,
    List<String>? reminderTimes,
    DateTime? startDate,
    bool? isPaused,
    bool? isPinned,
    bool? isFavorite,
    List<Tag>? tags,
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Habit(
    id: id ?? this.id,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    category: category ?? this.category,
    kind: kind ?? this.kind,
    targetCount: targetCount ?? this.targetCount,
    unit: unit ?? this.unit,
    frequency: frequency ?? this.frequency,
    partOfDay: partOfDay ?? this.partOfDay,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderTimes: reminderTimes ?? this.reminderTimes,
    startDate: startDate ?? this.startDate,
    isPaused: isPaused ?? this.isPaused,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    tags: tags ?? this.tags,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  static const _listEq = ListEquality<Object?>();

  @override
  bool operator ==(Object other) =>
      other is Habit &&
      other.id == id &&
      other.name == name &&
      other.iconKey == iconKey &&
      other.colorHex == colorHex &&
      other.category == category &&
      other.kind == kind &&
      other.targetCount == targetCount &&
      other.unit == unit &&
      other.frequency == frequency &&
      other.partOfDay == partOfDay &&
      other.reminderEnabled == reminderEnabled &&
      _listEq.equals(other.reminderTimes, reminderTimes) &&
      other.startDate == startDate &&
      other.isPaused == isPaused &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      _listEq.equals(other.tags, tags) &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    iconKey,
    colorHex,
    category,
    kind,
    targetCount,
    unit,
    frequency,
    partOfDay,
    reminderEnabled,
    _listEq.hash(reminderTimes),
    startDate,
    isPaused,
    isPinned,
    isFavorite,
    _listEq.hash(tags),
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  @override
  String toString() => 'Habit($id, $name, ${kind.name}, ${frequency.label})';
}
