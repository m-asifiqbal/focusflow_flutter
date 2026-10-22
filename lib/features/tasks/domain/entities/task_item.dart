/// ============================================================
/// TASK ITEM — a to-do with schedule, priority, subtasks and repeat
/// ============================================================
///
/// Plain immutable entity (named TaskItem so it never clashes with the
/// Drift table class `Tasks` / row `TaskRow` or other `Task` symbols).
/// Due dates are local calendar days ([dueDate] at midnight) plus an
/// optional time ([dueTimeMinutes] after midnight); [dueAt] combines them.
/// "Overdue" is day-based: a task due earlier *today* is still "today".
/// A new, unsaved task has an empty [id] ([isNew]).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';

/// Stored as 0 none · 1 low · 2 medium · 3 high ([index]).
enum TaskPriority {
  none,
  low,
  medium,
  high;

  /// Display name in the active language (a getter so a language switch is
  /// picked up).
  String get label => switch (this) {
    TaskPriority.none => tr('None'),
    TaskPriority.low => tr('Low'),
    TaskPriority.medium => tr('Medium'),
    TaskPriority.high => tr('High'),
  };

  static TaskPriority fromValue(int v) =>
      v >= 0 && v < values.length ? values[v] : TaskPriority.none;
}

@immutable
class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    this.done = false,
    this.sortOrder = 0,
  });

  /// A new subtask for the editor (empty id; created on save).
  const Subtask.draft(this.title, {this.done = false}) : id = '', sortOrder = 0;

  final String id;
  final String title;
  final bool done;
  final double sortOrder;

  bool get isNew => id.isEmpty;

  Subtask copyWith({String? title, bool? done, double? sortOrder}) => Subtask(
    id: id,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      other is Subtask &&
      other.id == id &&
      other.title == title &&
      other.done == done &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, title, done, sortOrder);

  @override
  String toString() => 'Subtask($title${done ? ' ✓' : ''})';
}

@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.dueDate,
    this.dueTimeMinutes,
    this.priority = TaskPriority.none,
    this.repeatRule,
    this.remindOffsetMinutes,
    this.reminderId,
    this.linkedNoteId,
    this.linkedNoteTitle,
    this.listId,
    this.listName,
    this.tags = const [],
    this.subtasks = const [],
    this.completedAt,
    this.isPinned = false,
    this.isFavorite = false,
    this.colorHex,
    this.sortOrder = 0,
    this.boardStatus = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  /// An unsaved task for the editor / quick add (empty id).
  factory TaskItem.draft({
    required DateTime now,
    String title = '',
    DateTime? dueDate,
    int? dueTimeMinutes,
    TaskPriority priority = TaskPriority.none,
    String? listId,
    List<Tag> tags = const [],
  }) => TaskItem(
    id: '',
    title: title,
    dueDate: dueDate == null ? null : DateUtilsX.dateOnly(dueDate),
    dueTimeMinutes: dueTimeMinutes,
    priority: priority,
    listId: listId,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );

  final String id;
  final String title;
  final String notes;

  /// Local calendar day (midnight) the task is due; null = no date.
  final DateTime? dueDate;

  /// Minutes after midnight (09:00 → 540); null = all day.
  final int? dueTimeMinutes;
  final TaskPriority priority;

  /// RRULE (`FREQ=WEEKLY;BYDAY=TU`); null = no repeat.
  final String? repeatRule;

  /// "Remind me N min before" (the repository keeps a linked reminder in
  /// sync); null = no reminder.
  final int? remindOffsetMinutes;

  /// The linked "Remind me" reminder (managed by the repository).
  final String? reminderId;
  final String? linkedNoteId;
  final String? linkedNoteTitle;

  /// Task list = folder (module `task`).
  final String? listId;
  final String? listName;

  /// Tags; on save only the names matter (missing tags are created).
  final List<Tag> tags;

  /// In display order; on save the list order becomes the sort order.
  final List<Subtask> subtasks;
  final DateTime? completedAt;
  final bool isPinned;
  final bool isFavorite;
  final String? colorHex;
  final double sortOrder;

  /// Board column (v1.1): 0 to do · 1 doing · 2 done.
  final int boardStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemRef get ref => ItemRef(ItemType.task, id);
  bool get isNew => id.isEmpty;
  bool get isCompleted => completedAt != null;
  bool get isRepeating => RecurrenceRule.tryParse(repeatRule) != null;
  bool get hasDueTime => dueDate != null && dueTimeMinutes != null;
  bool get hasReminder => remindOffsetMinutes != null && dueDate != null;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;

  /// Due date + time (midnight for all-day tasks); null without a date.
  DateTime? get dueAt {
    final d = dueDate;
    if (d == null) return null;
    return dueTimeMinutes == null
        ? d
        : DateUtilsX.atMinutes(d, dueTimeMinutes!);
  }

  /// When the "Remind me" reminder should fire, in the device zone: see
  /// [reminderWallTime].
  DateTime? get reminderAt {
    final w = reminderWallTime;
    return w == null ? null : DateUtilsX.atMinutes(w.day, w.minutes);
  }

  /// The reminder as a *wall* time — (calendar day, minutes after
  /// midnight): [dueAt] minus the offset, counted on the calendar
  /// ("1 day before 09:00" is 09:00 the day before, even across a DST
  /// change, where subtracting 1440 minutes would land on 08:00 / 10:00).
  /// All-day tasks use 09:00 of the due day as the reference time. Like
  /// the due day it floats: the notification engine turns it into an
  /// instant in the planning zone (and re-derives it when the zone
  /// changes).
  ({DateTime day, int minutes})? get reminderWallTime {
    final d = dueDate;
    final offset = remindOffsetMinutes;
    if (d == null || offset == null) return null;
    final total = (dueTimeMinutes ?? allDayReminderMinutes) - offset;
    const perDay = 24 * 60;
    final days = (total / perDay).floor();
    return (
      day: DateTime(d.year, d.month, d.day + days),
      minutes: total - days * perDay,
    );
  }

  /// Reference time (09:00) for reminders of all-day tasks.
  static const int allDayReminderMinutes = 9 * 60;

  int get subtaskDone => subtasks.where((s) => s.done).length;
  int get subtaskTotal => subtasks.length;

  /// 0…1 subtask progress (0 without subtasks).
  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : subtaskDone / subtaskTotal;

  /// "Weekly · Tue" / "Once".
  String get repeatLabel => Recurrence.label(repeatRule, start: dueDate);

  /// Not completed and due on a day before [now]'s day.
  bool isOverdue(DateTime now) {
    final d = dueDate;
    return !isCompleted && d != null && d.isBefore(DateUtilsX.dateOnly(now));
  }

  /// Due on the calendar day of [day].
  bool isDueOn(DateTime day) {
    final d = dueDate;
    return d != null && DateUtilsX.isSameDay(d, day);
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? dueTimeMinutes,
    bool clearDueTime = false,
    TaskPriority? priority,
    String? repeatRule,
    bool clearRepeatRule = false,
    int? remindOffsetMinutes,
    bool clearRemindOffset = false,
    String? reminderId,
    bool clearReminderId = false,
    String? linkedNoteId,
    String? linkedNoteTitle,
    bool clearLinkedNote = false,
    String? listId,
    String? listName,
    bool clearList = false,
    List<Tag>? tags,
    List<Subtask>? subtasks,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isPinned,
    bool? isFavorite,
    String? colorHex,
    bool clearColor = false,
    double? sortOrder,
    int? boardStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => TaskItem(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    dueTimeMinutes: clearDueTime || clearDueDate
        ? null
        : (dueTimeMinutes ?? this.dueTimeMinutes),
    priority: priority ?? this.priority,
    repeatRule: clearRepeatRule ? null : (repeatRule ?? this.repeatRule),
    remindOffsetMinutes: clearRemindOffset
        ? null
        : (remindOffsetMinutes ?? this.remindOffsetMinutes),
    reminderId: clearReminderId ? null : (reminderId ?? this.reminderId),
    linkedNoteId: clearLinkedNote ? null : (linkedNoteId ?? this.linkedNoteId),
    linkedNoteTitle: clearLinkedNote
        ? null
        : (linkedNoteTitle ?? this.linkedNoteTitle),
    listId: clearList ? null : (listId ?? this.listId),
    listName: clearList ? null : (listName ?? this.listName),
    tags: tags ?? this.tags,
    subtasks: subtasks ?? this.subtasks,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    sortOrder: sortOrder ?? this.sortOrder,
    boardStatus: boardStatus ?? this.boardStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  static const _tagsEq = ListEquality<Tag>();
  static const _subEq = ListEquality<Subtask>();

  @override
  bool operator ==(Object other) =>
      other is TaskItem &&
      other.id == id &&
      other.title == title &&
      other.notes == notes &&
      other.dueDate == dueDate &&
      other.dueTimeMinutes == dueTimeMinutes &&
      other.priority == priority &&
      other.repeatRule == repeatRule &&
      other.remindOffsetMinutes == remindOffsetMinutes &&
      other.reminderId == reminderId &&
      other.linkedNoteId == linkedNoteId &&
      other.linkedNoteTitle == linkedNoteTitle &&
      other.listId == listId &&
      other.listName == listName &&
      _tagsEq.equals(other.tags, tags) &&
      _subEq.equals(other.subtasks, subtasks) &&
      other.completedAt == completedAt &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      other.colorHex == colorHex &&
      other.sortOrder == sortOrder &&
      other.boardStatus == boardStatus &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    notes,
    dueDate,
    dueTimeMinutes,
    priority,
    repeatRule,
    remindOffsetMinutes,
    reminderId,
    linkedNoteId,
    linkedNoteTitle,
    listId,
    listName,
    _tagsEq.hash(tags),
    _subEq.hash(subtasks),
    completedAt,
    isPinned,
    isFavorite,
    colorHex,
    sortOrder,
    boardStatus,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  @override
  String toString() =>
      'TaskItem($id, $title, due: $dueAt${isCompleted ? ', done' : ''})';
}
