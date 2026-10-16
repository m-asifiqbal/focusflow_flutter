/// ============================================================
/// CALENDAR ENTRY — one row of the calendar agenda (screen 26)
/// ============================================================
///
/// What: a module-agnostic view of a task, reminder occurrence, habit or
/// note on a given day — title, time (null = "All day"), the meta line
/// ("Task · High", "Habit · done") and whether it is done.
/// Why: the agenda mixes four modules; flattening them here keeps the
/// widgets free of module-specific branching and makes ordering testable.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';

/// Which calendar layout is shown (segmented control).
enum CalendarMode {
  week('Week'),
  month('Month'),
  agenda('Agenda');

  const CalendarMode(this.label);

  final String label;
}

@immutable
class CalendarEntry {
  const CalendarEntry({
    required this.ref,
    required this.title,
    required this.meta,
    this.time,
    this.done = false,
  });

  /// The item this row opens.
  final ItemRef ref;
  final String title;

  /// When it happens that day; null = all day (habits, all-day tasks).
  final DateTime? time;

  /// The coloured meta line under the title: "Task · High", "Reminder",
  /// "Habit · done".
  final String meta;

  /// Completed task / done reminder occurrence / habit done that day
  /// (the meta line gets a check mark).
  final bool done;

  ItemType get type => ref.type;
  bool get isAllDay => time == null;

  /// Only one-off tasks can be dragged to another day (week view).
  bool get canReschedule => ref.type == ItemType.task;

  @override
  bool operator ==(Object other) =>
      other is CalendarEntry &&
      other.ref == ref &&
      other.title == title &&
      other.time == time &&
      other.meta == meta &&
      other.done == done;

  @override
  int get hashCode => Object.hash(ref, title, time, meta, done);

  @override
  String toString() => 'CalendarEntry(${ref.type.key} "$title" $time $meta)';
}
