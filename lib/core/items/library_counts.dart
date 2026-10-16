/// ============================================================
/// LIBRARY COUNTS — every number the Library hub (screen 05) shows
/// ============================================================
///
/// "Total" numbers count *active* items (not archived, not deleted).
/// Day-relative numbers (due today, reminders today, habits done today)
/// refer to the day of the `now` passed to watchLibraryCounts.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class LibraryCounts {
  const LibraryCounts({
    this.notesTotal = 0,
    this.notesPinned = 0,
    this.notesLastEditedAt,
    this.tasksTotal = 0,
    this.tasksOpen = 0,
    this.tasksDueToday = 0,
    this.tasksOverdue = 0,
    this.tasksDone = 0,
    this.remindersTotal = 0,
    this.remindersToday = 0,
    this.remindersNextAt,
    this.habitsTotal = 0,
    this.habitsDoneToday = 0,
    this.habitsScheduledToday = 0,
    this.habitsBestStreak = 0,
    this.vaultTotal = 0,
    this.vaultWeak = 0,
    this.vaultBreached = 0,
    this.pinned = 0,
    this.favourites = 0,
    this.tags = 0,
    this.folders = 0,
    this.archived = 0,
    this.trash = 0,
  });

  static const empty = LibraryCounts();

  final int notesTotal;
  final int notesPinned;

  /// Most recent edit of an active note ("Edited 2h ago").
  final DateTime? notesLastEditedAt;

  /// Active tasks including completed ones.
  final int tasksTotal;

  /// Active, not completed.
  final int tasksOpen;
  final int tasksDueToday;
  final int tasksOverdue;
  final int tasksDone;
  final int remindersTotal;

  /// Reminder occurrences on the day (done + pending).
  final int remindersToday;

  /// Next upcoming fire time (≥ now) of any enabled reminder.
  final DateTime? remindersNextAt;
  final int habitsTotal;
  final int habitsDoneToday;
  final int habitsScheduledToday;

  /// Highest *current* streak among active habits ("Longest active streak").
  final int habitsBestStreak;
  final int vaultTotal;

  /// Cached strength ≤ 1 (0–4 scale).
  final int vaultWeak;
  final int vaultBreached;

  /// Active pinned / favourite items across all modules.
  final int pinned;
  final int favourites;
  final int tags;
  final int folders;

  /// Archived (and not deleted) items across all modules.
  final int archived;

  /// Items in Recently Deleted.
  final int trash;

  /// Active items across the five spaces ("113 items across 5 spaces").
  int get totalItems =>
      notesTotal + tasksTotal + remindersTotal + habitsTotal + vaultTotal;

  /// "Tags & Folders (11)".
  int get tagsAndFolders => tags + folders;

  @override
  bool operator ==(Object other) =>
      other is LibraryCounts &&
      other.notesTotal == notesTotal &&
      other.notesPinned == notesPinned &&
      other.notesLastEditedAt == notesLastEditedAt &&
      other.tasksTotal == tasksTotal &&
      other.tasksOpen == tasksOpen &&
      other.tasksDueToday == tasksDueToday &&
      other.tasksOverdue == tasksOverdue &&
      other.tasksDone == tasksDone &&
      other.remindersTotal == remindersTotal &&
      other.remindersToday == remindersToday &&
      other.remindersNextAt == remindersNextAt &&
      other.habitsTotal == habitsTotal &&
      other.habitsDoneToday == habitsDoneToday &&
      other.habitsScheduledToday == habitsScheduledToday &&
      other.habitsBestStreak == habitsBestStreak &&
      other.vaultTotal == vaultTotal &&
      other.vaultWeak == vaultWeak &&
      other.vaultBreached == vaultBreached &&
      other.pinned == pinned &&
      other.favourites == favourites &&
      other.tags == tags &&
      other.folders == folders &&
      other.archived == archived &&
      other.trash == trash;

  @override
  int get hashCode => Object.hashAll([
    notesTotal,
    notesPinned,
    notesLastEditedAt,
    tasksTotal,
    tasksOpen,
    tasksDueToday,
    tasksOverdue,
    tasksDone,
    remindersTotal,
    remindersToday,
    remindersNextAt,
    habitsTotal,
    habitsDoneToday,
    habitsScheduledToday,
    habitsBestStreak,
    vaultTotal,
    vaultWeak,
    vaultBreached,
    pinned,
    favourites,
    tags,
    folders,
    archived,
    trash,
  ]);

  @override
  String toString() =>
      'LibraryCounts(items: $totalItems, archived: $archived, trash: $trash)';
}
