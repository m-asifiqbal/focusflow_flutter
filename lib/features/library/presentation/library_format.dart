/// ============================================================
/// LIBRARY FORMAT — the copy on the Library hub's module cards and the
/// mixed collection rows
/// ============================================================
///
/// What: turns [LibraryCounts] (+ vault lock state) into the card lines
/// ("48 Notes · 3 pinned · Edited 2h ago") and [ItemSummary]s into row
/// meta ("Task · Due today 5:00 PM"). Why: pure functions, so the copy is
/// unit-tested without widgets and every screen words things the same.
/// The vault line never says anything about secrets — only counts and
/// "Locked" / "Unlocked".
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';

/// The three text lines of one module card.
@immutable
class LibraryCardLines {
  const LibraryCardLines({
    required this.count,
    required this.highlight,
    required this.meta,
  });

  final int count;

  /// Module-ink line ("7 due today").
  final String highlight;

  /// Muted line ("2 overdue").
  final String meta;
}

abstract final class LibraryFormat {
  /// Copy of an empty module ("0 Notes · Create your first").
  static const String createFirst = 'Create your first';

  /// "113 items across 5 spaces".
  static String headerSubtitle(int items, {int spaces = 5}) =>
      '$items ${items == 1 ? 'item' : 'items'} across $spaces '
      '${spaces == 1 ? 'space' : 'spaces'}';

  /// Card lines of [type] for [c]. [now] is the device time; [vault] the
  /// live lock state (vault card only).
  static LibraryCardLines card(
    ItemType type,
    LibraryCounts c, {
    required DateTime now,
    VaultStatus vault = VaultStatus.locked,
    bool use24h = false,
  }) => switch (type) {
    ItemType.note => LibraryCardLines(
      count: c.notesTotal,
      highlight: c.notesTotal == 0
          ? createFirst
          : c.notesPinned > 0
          ? '${c.notesPinned} pinned'
          : 'None pinned',
      meta: c.notesLastEditedAt == null
          ? 'No notes yet'
          : edited(c.notesLastEditedAt!, now),
    ),
    ItemType.task => LibraryCardLines(
      count: c.tasksTotal,
      highlight: c.tasksTotal == 0
          ? createFirst
          : c.tasksDueToday > 0
          ? '${c.tasksDueToday} due today'
          : c.tasksOpen > 0
          ? '${c.tasksOpen} open'
          : 'All done',
      meta: c.tasksTotal == 0
          ? 'No tasks yet'
          : c.tasksOverdue > 0
          ? '${c.tasksOverdue} overdue'
          : c.tasksDueToday > 0
          ? '${c.tasksOpen} open'
          : '${c.tasksDone} done',
    ),
    ItemType.reminder => LibraryCardLines(
      count: c.remindersTotal,
      highlight: c.remindersTotal == 0
          ? createFirst
          : c.remindersToday > 0
          ? '${c.remindersToday} today'
          : 'None today',
      meta: c.remindersNextAt == null
          ? 'Nothing upcoming'
          : 'Next ${nextTime(c.remindersNextAt!, now, use24h: use24h)}',
    ),
    ItemType.habit => LibraryCardLines(
      count: c.habitsTotal,
      highlight: c.habitsTotal == 0
          ? createFirst
          : c.habitsScheduledToday > 0
          ? '${c.habitsDoneToday}/${c.habitsScheduledToday} done today'
          : 'Rest day',
      meta: c.habitsBestStreak > 0
          ? 'Best streak ${c.habitsBestStreak}d'
          : 'No streak yet',
    ),
    ItemType.vault => LibraryCardLines(
      count: c.vaultTotal,
      highlight: vault == VaultStatus.notSetUp
          ? 'Set up your vault'
          : c.vaultTotal == 0
          ? createFirst
          : c.vaultBreached > 0
          ? '${c.vaultBreached} breached'
          : c.vaultWeak > 0
          ? '${c.vaultWeak} weak'
          : 'All strong',
      meta: vaultState(vault),
    ),
  };

  /// "Locked" / "Unlocked" / "Not set up".
  static String vaultState(VaultStatus s) => switch (s) {
    VaultStatus.locked => 'Locked',
    VaultStatus.unlocked => 'Unlocked',
    VaultStatus.notSetUp => 'Not set up',
  };

  /// "10:00 AM" today, "Tomorrow 9:00 AM", else "Jun 3".
  static String nextTime(DateTime at, DateTime now, {bool use24h = false}) {
    final days = DateUtilsX.daysBetween(now, at);
    final time = _time(at, use24h);
    if (days == 0) return time;
    if (days == 1) return 'tomorrow $time';
    return DateUtilsX.relativeDay(at, now).replaceFirst(RegExp(r'^\w+, '), '');
  }

  /// "Edited 2h ago", "Edited just now", "Edited yesterday" (sentence
  /// case mid-line), "Edited Jun 3".
  static String edited(DateTime t, DateTime now) {
    final ago = DateUtilsX.ago(t, now);
    final mid = ago == 'Just now' || ago == 'Yesterday';
    return 'Edited ${mid ? ago.toLowerCase() : ago}';
  }

  /// Meta of a mixed-list row: "Note · Edited 2h ago", "Task · Due Today
  /// 5:00 PM", "Password · Login" (never a secret).
  static String rowMeta(ItemSummary s, DateTime now, {bool use24h = false}) {
    final parts = <String>[s.type.label];
    final at = s.scheduledAt;
    if (s.isCompleted) {
      parts.add('completed');
    } else if (at != null) {
      final day = DateUtilsX.relativeDay(at, now);
      final when = day == 'Today' || day == 'Tomorrow'
          ? '$day ${_time(at, use24h)}'
          : day;
      parts.add(s.type == ItemType.task ? 'Due $when' : when);
    } else if (s.type == ItemType.vault || s.type == ItemType.habit) {
      if (s.meta.isNotEmpty) parts.add(s.meta);
    } else {
      parts.add(edited(s.updatedAt, now));
    }
    if (s.folderName != null && s.folderName!.isNotEmpty) {
      parts.add(s.folderName!);
    }
    return parts.join(' · ');
  }

  /// "9 items" / "1 item".
  static String items(int n) => '$n ${n == 1 ? 'item' : 'items'}';

  static String _time(DateTime t, bool use24h) {
    final s = DateUtilsX.time(t, use24h: use24h);
    // "09:00 AM" → "9:00 AM" (12-hour clock reads without the zero).
    return use24h || !s.startsWith('0') ? s : s.substring(1);
  }
}
