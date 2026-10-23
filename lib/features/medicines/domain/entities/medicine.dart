/// ============================================================
/// MEDICINE — something the user takes on a schedule (or as needed)
/// ============================================================
///
/// Plain immutable domain entity (no Drift). A medicine has:
///   • what it is: [name], [strength] ("500 mg"), [form] (tablet, liquid…),
///     [foodTiming] (before / with / after food) and a free [note];
///   • when it is taken: a [schedule] (every day, specific weekdays, every
///     N days, or as needed) and one [DoseTime] per time of day, each with
///     its own amount, inside a course from [startDate] to [endDate]
///     (null = ongoing);
///   • the pack: [stockLeft] units (null = not tracked), the refill alert
///     threshold [refillAt] and the last refill amount [packSize];
///   • how it alerts: [reminderEnabled], [alarmStyle] (full screen),
///     [snoozeMinutes] and [followUpMinutes] ("remind again if not taken").
/// Taken / skipped doses live in DoseLog rows (medicine_dose.dart).
/// A new, unsaved medicine has an empty [id] (see [isNew]).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';

/// Stored in `medicines.form` as the index — append only.
enum MedicineForm { tablet, capsule, liquid, drops, injection, inhaler, other }

/// Stored in `medicines.food_timing` as the index — append only.
enum FoodTiming { anyTime, beforeFood, withFood, afterFood }

/// Stored in `medicines.schedule_type` as the index — append only.
enum MedicineScheduleType { everyDay, specificDays, everyNDays, asNeeded }

/// One time of day a dose is due, with its amount ("8:00 · 1 tablet").
@immutable
class DoseTime implements Comparable<DoseTime> {
  const DoseTime(this.minutes, [this.quantity = 1]);

  /// Minutes after midnight (0–1439).
  final int minutes;

  /// Units of the medicine's form (tablets, ml …); may be fractional.
  final double quantity;

  /// `HH:mm` (storage, dose ids).
  String get hhmm =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  /// `HH:mm` → minutes after midnight (null when malformed).
  static int? parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  DoseTime copyWith({int? minutes, double? quantity}) =>
      DoseTime(minutes ?? this.minutes, quantity ?? this.quantity);

  @override
  int compareTo(DoseTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is DoseTime &&
      other.minutes == minutes &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(minutes, quantity);

  @override
  String toString() => 'DoseTime($hhmm × $quantity)';
}

@immutable
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    this.strength = '',
    this.form = MedicineForm.tablet,
    this.note = '',
    this.foodTiming = FoodTiming.anyTime,
    this.schedule = MedicineScheduleType.everyDay,
    this.weekdaysMask = 127,
    this.everyNDays = 2,
    this.doses = const [],
    required this.startDate,
    this.endDate,
    this.stockLeft,
    this.refillAt,
    this.packSize,
    this.reminderEnabled = true,
    this.alarmStyle = false,
    this.snoozeMinutes = 10,
    this.followUpMinutes = 30,
    this.isPaused = false,
    this.colorHex,
    this.isPinned = false,
    this.isFavorite = false,
    this.tags = const [],
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  /// An unsaved medicine for the editor: one 8:00 dose of 1 unit, every
  /// day from [startDate].
  factory Medicine.draft({required DateTime startDate, String name = ''}) {
    final day = DateTime(startDate.year, startDate.month, startDate.day);
    return Medicine(
      id: '',
      name: name,
      doses: const [DoseTime(8 * 60)],
      startDate: day,
      createdAt: day,
      updatedAt: day,
    );
  }

  final String id;
  final String name;
  final String strength;
  final MedicineForm form;
  final String note;
  final FoodTiming foodTiming;
  final MedicineScheduleType schedule;

  /// Bit 0 = Monday … bit 6 = Sunday ([MedicineScheduleType.specificDays]).
  final int weekdaysMask;

  /// Interval for [MedicineScheduleType.everyNDays] (≥ 2).
  final int everyNDays;

  /// Dose times of a scheduled medicine, sorted (empty when as needed).
  final List<DoseTime> doses;

  /// First day of the course (local midnight).
  final DateTime startDate;

  /// Last day of the course (local midnight, inclusive); null = ongoing.
  final DateTime? endDate;
  final double? stockLeft;
  final double? refillAt;
  final double? packSize;
  final bool reminderEnabled;
  final bool alarmStyle;
  final int snoozeMinutes;

  /// Minutes after a dose to ask again when it is not taken; 0 = off.
  final int followUpMinutes;
  final bool isPaused;
  final String? colorHex;
  final bool isPinned;
  final bool isFavorite;
  final List<Tag> tags;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemRef get ref => ItemRef(ItemType.medicine, id);
  bool get isNew => id.isEmpty;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;
  bool get isAsNeeded => schedule == MedicineScheduleType.asNeeded;
  bool get tracksStock => stockLeft != null;

  /// Stock at or below the refill threshold.
  bool get isLow {
    final left = stockLeft;
    final at = refillAt;
    return left != null && at != null && left <= at;
  }

  /// The course ended before [day].
  bool hasEndedBy(DateTime day) {
    final end = endDate;
    if (end == null) return false;
    return DateTime(day.year, day.month, day.day).isAfter(end);
  }

  /// "Metformin 500 mg" (name alone when there is no strength).
  String get displayName {
    final n = name.trim();
    final s = strength.trim();
    return s.isEmpty ? n : '$n $s';
  }

  /// The amount of the dose due at [minutes] (1 when it is not a dose time).
  double quantityAt(int minutes) =>
      doses.firstWhereOrNull((d) => d.minutes == minutes)?.quantity ?? 1;

  Medicine copyWith({
    String? id,
    String? name,
    String? strength,
    MedicineForm? form,
    String? note,
    FoodTiming? foodTiming,
    MedicineScheduleType? schedule,
    int? weekdaysMask,
    int? everyNDays,
    List<DoseTime>? doses,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    double? stockLeft,
    bool clearStock = false,
    double? refillAt,
    bool clearRefillAt = false,
    double? packSize,
    bool? reminderEnabled,
    bool? alarmStyle,
    int? snoozeMinutes,
    int? followUpMinutes,
    bool? isPaused,
    String? colorHex,
    bool? isPinned,
    bool? isFavorite,
    List<Tag>? tags,
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    DateTime? deletedAt,
  }) => Medicine(
    id: id ?? this.id,
    name: name ?? this.name,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    note: note ?? this.note,
    foodTiming: foodTiming ?? this.foodTiming,
    schedule: schedule ?? this.schedule,
    weekdaysMask: weekdaysMask ?? this.weekdaysMask,
    everyNDays: everyNDays ?? this.everyNDays,
    doses: doses ?? this.doses,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    stockLeft: clearStock ? null : (stockLeft ?? this.stockLeft),
    refillAt: clearRefillAt || clearStock ? null : (refillAt ?? this.refillAt),
    packSize: packSize ?? this.packSize,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    alarmStyle: alarmStyle ?? this.alarmStyle,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    followUpMinutes: followUpMinutes ?? this.followUpMinutes,
    isPaused: isPaused ?? this.isPaused,
    colorHex: colorHex ?? this.colorHex,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    tags: tags ?? this.tags,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt ?? this.archivedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  static const _dosesEq = ListEquality<DoseTime>();
  static const _tagsEq = ListEquality<Tag>();

  @override
  bool operator ==(Object other) =>
      other is Medicine &&
      other.id == id &&
      other.name == name &&
      other.strength == strength &&
      other.form == form &&
      other.note == note &&
      other.foodTiming == foodTiming &&
      other.schedule == schedule &&
      other.weekdaysMask == weekdaysMask &&
      other.everyNDays == everyNDays &&
      _dosesEq.equals(other.doses, doses) &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.stockLeft == stockLeft &&
      other.refillAt == refillAt &&
      other.packSize == packSize &&
      other.reminderEnabled == reminderEnabled &&
      other.alarmStyle == alarmStyle &&
      other.snoozeMinutes == snoozeMinutes &&
      other.followUpMinutes == followUpMinutes &&
      other.isPaused == isPaused &&
      other.colorHex == colorHex &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      _tagsEq.equals(other.tags, tags) &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    strength,
    form,
    note,
    foodTiming,
    schedule,
    weekdaysMask,
    everyNDays,
    _dosesEq.hash(doses),
    startDate,
    endDate,
    stockLeft,
    refillAt,
    packSize,
    reminderEnabled,
    alarmStyle,
    snoozeMinutes,
    followUpMinutes,
    isPaused,
    colorHex,
    isPinned,
    isFavorite,
    _tagsEq.hash(tags),
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  @override
  String toString() => 'Medicine($id, $name, ${schedule.name})';
}
