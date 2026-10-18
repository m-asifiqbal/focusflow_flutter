/// ============================================================
/// HABIT FORMAT — the words and numbers of the habit editor and detail
/// ============================================================
///
/// Pure string helpers (unit tested) so widgets only lay text out:
/// reminder times ("9:00 · 13:00 · 17:00"), the detail meta line
/// ("Health · Weekdays · 8 glasses"), the ring value ("6/8"), the log
/// button ("Log 1 glass") and the history rows ("6 of 8 glasses", "75%").
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_history.dart';

abstract final class HabitFormat {
  /// `HH:mm` storage form of a time.
  static String storeTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// "09:00" → "9:00" (compact 24 h, as in mockup 15).
  static String time(String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return stored;
    final h = int.tryParse(parts[0]);
    return h == null ? stored : '$h:${parts[1]}';
  }

  /// "9:00 · 13:00 · 17:00".
  static String times(List<String> stored) => stored.map(time).join(' · ');

  /// "Build (do more)" / "Quit (do less)".
  static String kind(HabitKind kind) => switch (kind) {
    HabitKind.build => 'Build (do more)',
    HabitKind.quit => 'Quit (do less)',
  };

  /// "Anytime" / "Morning" / "Afternoon" / "Evening".
  static String partOfDay(PartOfDay part) => switch (part) {
    PartOfDay.anytime => 'Anytime',
    PartOfDay.morning => 'Morning',
    PartOfDay.afternoon => 'Afternoon',
    PartOfDay.evening => 'Evening',
  };

  /// Singular of a unit for "Log 1 glass": glasses → glass, pages → page.
  static String singular(String unit) {
    final u = unit.trim();
    if (u.length > 3 && RegExp(r'(ss|sh|ch|x)es$').hasMatch(u)) {
      return u.substring(0, u.length - 2);
    }
    if (u.length > 1 && u.endsWith('s') && !u.endsWith('ss')) {
      return u.substring(0, u.length - 1);
    }
    return u;
  }

  /// "Health · Weekdays · 8 glasses" (detail header). Quit habits count
  /// every day, so their (ignored) frequency is left out.
  static String meta(Habit habit) => [
    if (habit.category.trim().isNotEmpty) habit.category,
    if (!habit.isQuit) habit.frequency.label,
    if (habit.isQuit)
      'Quit habit'
    else if (!habit.isYesNo)
      '${habit.targetCount} ${habit.unit}',
  ].join(' · ');

  /// The value inside the detail ring: "6/8"; quit habits "Clean" /
  /// "1 slip".
  static String ring(Habit habit, HabitLog? today) {
    if (habit.isQuit) {
      final slips = today == null || today.skipped ? 0 : today.count;
      return slips == 0 ? 'Clean' : slipCount(slips);
    }
    final count = today == null || today.skipped ? 0 : today.count;
    return '$count/${habit.targetCount}';
  }

  /// "1 slip" / "3 slips".
  static String slipCount(int n) => n == 1 ? '1 slip' : '$n slips';

  /// Label of the detail's primary button.
  static String logButton(Habit habit, {required bool doneToday}) {
    if (habit.isQuit) return 'Log a slip';
    if (habit.isYesNo) return doneToday ? 'Done today' : 'Mark done';
    return 'Log 1 ${singular(habit.unit)}';
  }

  /// "75%".
  static String percent(double rate) => '${(rate * 100).round()}%';

  /// History row title: "Today", "Yesterday", "Thu, Jun 11".
  static String historyTitle(DateTime day, DateTime today) =>
      DateUtilsX.relativeDay(day, today);

  /// History row subtitle ("6 of 8 glasses", "Goal reached at 4:10 PM" —
  /// "16:10" with Settings › 24-hour time ([use24h]) —, "Skipped · note:
  /// travel day").
  static String historySubtitle(
    Habit habit,
    HabitHistoryEntry e, {
    bool use24h = false,
  }) {
    final log = e.log;
    final base = switch (e.kind) {
      HabitHistoryKind.skipped => 'Skipped',
      HabitHistoryKind.slip => '${slipCount(log.count)} logged',
      HabitHistoryKind.done when habit.isQuit => 'Clean day',
      HabitHistoryKind.done when habit.isYesNo =>
        'Done at ${clock(log.updatedAt, use24h: use24h)}',
      HabitHistoryKind.done =>
        'Goal reached at ${clock(log.updatedAt, use24h: use24h)}',
      HabitHistoryKind.partial =>
        '${log.count} of ${habit.targetCount} ${habit.unit}',
    };
    final note = log.note?.trim() ?? '';
    return note.isEmpty ? base : '$base · note: $note';
  }

  /// History row trailing value: "75%", "100%", "Skip", "Slip".
  static String historyValue(Habit habit, HabitHistoryEntry e) =>
      switch (e.kind) {
        HabitHistoryKind.skipped => 'Skip',
        HabitHistoryKind.slip => 'Slip',
        HabitHistoryKind.done when habit.isQuit => 'Clean',
        _ => percent(e.progress),
      };

  /// "4:10 PM", or "16:10" when [use24h] (Settings › 24-hour time).
  static String clock(DateTime t, {bool use24h = false}) =>
      DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);
}
