/// ============================================================
/// ARCHIVE FORMAT — copy of the Archive (23) and Recently Deleted (24) rows
/// ============================================================
///
/// Pure string helpers (no widgets, no providers) so the copy is unit
/// tested and identical on both screens: "Note · archived Jun 2",
/// "Task · completed · archived May 28", "Habit · 34-day streak saved",
/// "Reminder · deleted yesterday", "29 days".
/// ============================================================
library;

import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

abstract final class ArchiveFormat {
  /// Module name on a row: "Note", "Task", "Reminder", "Habit", "Vault".
  static String typeName(ItemType t) =>
      t == ItemType.vault ? tr('Vault') : t.label;

  /// "today", "yesterday", "Jun 2", "Mar 3, 2025" (mid-sentence casing).
  static String day(DateTime t, DateTime now) {
    final ago = DateUtilsX.daysBetween(t, now);
    if (ago == 0) return tr('today');
    if (ago == 1) return tr('yesterday');
    if (t.year == now.year) return DateFormats.of('MMM d').format(t);
    return DateFormats.of('MMM d, y').format(t);
  }

  /// "34-day streak saved" / "5-week streak saved"; null without a streak.
  static String? streakSaved(HabitStreak? streak) {
    if (streak == null || streak.current <= 0) return null;
    return streak.unit == StreakUnit.weeks
        ? tr('{n}-week streak saved', {'n': streak.current})
        : tr('{n}-day streak saved', {'n': streak.current});
  }

  /// Second line of an Archive row. [streak] (habits) replaces the date.
  static String archivedMeta(ItemSummary s, DateTime now, {String? streak}) {
    final at = s.archivedAt ?? s.updatedAt;
    return [
      typeName(s.type),
      if (s.type == ItemType.task && s.isCompleted) tr('completed'),
      streak ?? tr('archived {when}', {'when': day(at, now)}),
    ].join(' · ');
  }

  /// Second line of a Recently Deleted row: "Note · deleted today".
  static String deletedMeta(ItemSummary s, DateTime now) =>
      '${typeName(s.type)} · '
      '${tr('deleted {when}', {'when': day(s.deletedAt ?? s.updatedAt, now)})}';

  /// Whole days an item stays in Recently Deleted before the purge, counted
  /// in calendar days like design/24: deleted today → 29, yesterday → 28;
  /// 0 on its last day.
  static int daysLeftOf(ItemSummary s, DateTime now, {int retention = 30}) {
    final ago = DateUtilsX.daysBetween(s.deletedAt ?? s.updatedAt, now);
    final left = retention - 1 - ago;
    return left < 0 ? 0 : left;
  }

  /// Days before the purge: "29 days", "1 day", "Today".
  static String daysLeft(int days) => switch (days) {
    <= 0 => tr('Today'),
    _ => tr('{count, plural, one {# day} other {# days}}', {'count': days}),
  };

  /// Screen-reader form of [daysLeft].
  static String daysLeftSemantics(int days) => days <= 0
      ? tr('deleted permanently today')
      : tr('{days} until deleted permanently', {'days': daysLeft(days)});

  /// Search hint: "Search 37 archived items…".
  static String searchHint(int total) => total == 0
      ? tr('Search archived items…')
      : tr(
          'Search {count, plural, one {# archived item} other {# archived items}}…',
          {'count': total},
        );

  /// "5 items" / "2 selected · 5 items" (shown upper-case).
  static String countLabel(int total, {int? selected}) {
    final items = tr('{count, plural, one {# item} other {# items}}', {
      'count': total,
    });
    return selected == null
        ? items
        : tr('{selected} selected · {items}', {
            'selected': selected,
            'items': items,
          });
  }

  /// "Restore (2)".
  static String withCount(String verb, int n) => '$verb ($n)';
}
