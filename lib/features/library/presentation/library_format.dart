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
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/services/habit_words.dart';
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
  static String get createFirst => tr('Create your first');

  /// "113 items across 5 spaces".
  static String headerSubtitle(int items, {int spaces = 6}) => tr(
    '{items, plural, one {# item} other {# items}} across '
    '{spaces, plural, one {# space} other {# spaces}}',
    {'items': items, 'spaces': spaces},
  );

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
          ? tr('{n} pinned', {'n': c.notesPinned})
          : tr('None pinned'),
      meta: c.notesLastEditedAt == null
          ? tr('No notes yet')
          : edited(c.notesLastEditedAt!, now),
    ),
    ItemType.task => LibraryCardLines(
      count: c.tasksTotal,
      highlight: c.tasksTotal == 0
          ? createFirst
          : c.tasksDueToday > 0
          ? tr('{n} due today', {'n': c.tasksDueToday})
          : c.tasksOpen > 0
          ? tr('{n} open', {'n': c.tasksOpen})
          : tr('All done'),
      meta: c.tasksTotal == 0
          ? tr('No tasks yet')
          : c.tasksOverdue > 0
          ? tr('{n} overdue', {'n': c.tasksOverdue})
          : c.tasksDueToday > 0
          ? tr('{n} open', {'n': c.tasksOpen})
          : tr('{n} done', {'n': c.tasksDone}),
    ),
    ItemType.reminder => LibraryCardLines(
      count: c.remindersTotal,
      highlight: c.remindersTotal == 0
          ? createFirst
          : c.remindersToday > 0
          ? tr('{n} today', {'n': c.remindersToday})
          : tr('None today'),
      meta: c.remindersNextAt == null
          ? tr('Nothing upcoming')
          : tr('Next {time}', {
              'time': nextTime(c.remindersNextAt!, now, use24h: use24h),
            }),
    ),
    ItemType.habit => LibraryCardLines(
      count: c.habitsTotal,
      highlight: c.habitsTotal == 0
          ? createFirst
          : c.habitsScheduledToday > 0
          ? tr('{done}/{total} done today', {
              'done': c.habitsDoneToday,
              'total': c.habitsScheduledToday,
            })
          : tr('Rest day'),
      meta: c.habitsBestStreak > 0
          ? tr('Best streak {n}d', {'n': c.habitsBestStreak})
          : tr('No streak yet'),
    ),
    ItemType.medicine => LibraryCardLines(
      count: c.medicinesTotal,
      highlight: c.medicinesTotal == 0
          ? createFirst
          : c.medicinesDueToday > 0
          ? tr('{done}/{total} doses taken', {
              'done': c.medicinesTakenToday,
              'total': c.medicinesDueToday,
            })
          : tr('No doses today'),
      meta: c.medicinesLow > 0
          ? tr('{n} to refill', {'n': c.medicinesLow})
          : c.medicinesTotal == 0
          ? tr('No medicines yet')
          : tr('Stock OK'),
    ),
    ItemType.vault => LibraryCardLines(
      count: c.vaultTotal,
      highlight: vault == VaultStatus.notSetUp
          ? tr('Set up your vault')
          : c.vaultTotal == 0
          ? createFirst
          : c.vaultBreached > 0
          ? tr('{n} breached', {'n': c.vaultBreached})
          : c.vaultWeak > 0
          ? tr('{n} weak', {'n': c.vaultWeak})
          : tr('All strong'),
      meta: vaultState(vault),
    ),
  };

  /// "Locked" / "Unlocked" / "Not set up".
  static String vaultState(VaultStatus s) => switch (s) {
    VaultStatus.locked => tr('Locked'),
    VaultStatus.unlocked => tr('Unlocked'),
    VaultStatus.notSetUp => tr('Not set up'),
  };

  /// "10:00 AM" today, "Tomorrow 9:00 AM", else "Jun 3".
  static String nextTime(DateTime at, DateTime now, {bool use24h = false}) {
    final days = DateUtilsX.daysBetween(now, at);
    final time = _time(at, use24h);
    if (days == 0) return time;
    if (days == 1) return tr('tomorrow {time}', {'time': time});
    return DateUtilsX.relativeDay(at, now).replaceFirst(RegExp(r'^\w+, '), '');
  }

  /// "Edited 2h ago", "Edited just now", "Edited yesterday" (sentence
  /// case mid-line), "Edited Jun 3".
  static String edited(DateTime t, DateTime now) {
    // The two day-level phrases read lowercase mid-line. Decided from the
    // dates (mirrors DateUtilsX.ago), never by comparing its text, so it holds
    // in every language.
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return tr('Edited just now');
    final recent =
        diff.inMinutes < 60 ||
        (diff.inHours < 24 && DateUtilsX.isSameDay(t, now));
    if (!recent && DateUtilsX.isSameDay(t, DateUtilsX.addDays(now, -1))) {
      return tr('Edited yesterday');
    }
    return tr('Edited {when}', {'when': DateUtilsX.ago(t, now)});
  }

  /// Meta of a mixed-list row: "Note · Edited 2h ago", "Task · Due Today
  /// 5:00 PM", "Password · Login" (never a secret).
  static String rowMeta(ItemSummary s, DateTime now, {bool use24h = false}) {
    final parts = <String>[s.type.label];
    final at = s.scheduledAt;
    if (s.isCompleted) {
      parts.add(tr('completed'));
    } else if (at != null) {
      final day = DateUtilsX.relativeDay(at, now);
      // Today / tomorrow (the words relativeDay uses) get the time appended.
      final days = DateUtilsX.daysBetween(now, at);
      final when = days == 0 || days == 1 ? '$day ${_time(at, use24h)}' : day;
      parts.add(
        s.type == ItemType.task ? tr('Due {when}', {'when': when}) : when,
      );
    } else if (s.type == ItemType.vault ||
        s.type == ItemType.habit ||
        s.type == ItemType.medicine) {
      if (s.meta.isNotEmpty) {
        // A habit's category is stored in English; shown in the active language.
        parts.add(s.type == ItemType.habit ? HabitWords.shown(s.meta) : s.meta);
      }
    } else {
      parts.add(edited(s.updatedAt, now));
    }
    if (s.folderName != null && s.folderName!.isNotEmpty) {
      parts.add(s.folderName!);
    }
    return parts.join(' · ');
  }

  /// "9 items" / "1 item".
  static String items(int n) =>
      tr('{count, plural, one {# item} other {# items}}', {'count': n});

  static String _time(DateTime t, bool use24h) {
    final s = DateUtilsX.time(t, use24h: use24h);
    // "09:00 AM" → "9:00 AM" (12-hour clock reads without the zero).
    return use24h || !s.startsWith('0') ? s : s.substring(1);
  }
}
