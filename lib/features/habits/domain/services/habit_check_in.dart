/// ============================================================
/// HABIT CHECK-IN — what a tap / swipe / "Log today" does to a habit's day
/// ============================================================
///
/// The habit card's round button (screen 14), the swipe "Log" action and
/// the item-actions "Log today" row all change today's log. The rules live
/// here (pure, unit tested) so every entry point behaves the same:
///   • yes/no build habit (target 1) — the button toggles done ⇄ not done;
///   • counted build habit — "+" adds one check-in; once the goal is met
///     the button shows a check and tapping it undoes the last check-in;
///   • quit habit — the button shows "clean" (check) and tapping it logs a
///     slip; tapping again clears the slip.
/// "Log today" (swipe / sheet) never removes progress: it only moves the
/// day forward (adds a check-in, marks done, clears a slip).
/// ============================================================
library;

import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';

/// A change to one day's log.
enum HabitLogChange {
  /// +1 check-in (build) — clears "skipped".
  increment,

  /// −1 check-in (build) — the undo of [increment].
  decrement,

  /// Done ⇄ not done (yes/no build habits), clean ⇄ slip (quit habits).
  toggle,
}

abstract final class HabitCheckIn {
  /// The change a tap on the card's round button makes for [status].
  static HabitLogChange tap(HabitDayStatus status) {
    final habit = status.habit;
    if (habit.isQuit || habit.isYesNo) return HabitLogChange.toggle;
    return status.isDone ? HabitLogChange.decrement : HabitLogChange.increment;
  }

  /// The change "Log today" makes, or null when there is nothing to log
  /// (yes/no habit already done, quit habit already clean).
  static HabitLogChange? logToday(Habit habit, HabitLog? todayLog) {
    final slipped = todayLog != null && !todayLog.skipped && todayLog.count > 0;
    if (habit.isQuit) return slipped ? HabitLogChange.toggle : null;
    if (habit.isYesNo) {
      return habit.isDoneWith(todayLog) ? null : HabitLogChange.toggle;
    }
    return HabitLogChange.increment;
  }

  /// The change of the habit detail's primary button (screen 16): a
  /// counted habit adds one check-in ("Log 1 glass"), a yes/no habit
  /// toggles done ("Mark done" / "Done today"), a quit habit logs a slip.
  static HabitLogChange detailLog(Habit habit) {
    if (habit.isQuit) return HabitLogChange.increment;
    if (habit.isYesNo) return HabitLogChange.toggle;
    return HabitLogChange.increment;
  }

  /// Whether applying [change] to a quit habit records a slip (the UI
  /// offers Undo for that, since it resets the streak).
  static bool logsSlip(Habit habit, HabitLog? todayLog, HabitLogChange change) {
    if (!habit.isQuit) return false;
    final slipped = todayLog != null && !todayLog.skipped && todayLog.count > 0;
    return change == HabitLogChange.increment ||
        (change == HabitLogChange.toggle && !slipped);
  }
}
