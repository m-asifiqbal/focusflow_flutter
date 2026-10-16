/// ============================================================
/// HOME FOCUS — pure rules behind the Home dashboard (screen 03)
/// ============================================================
///
/// What: the "Today's Focus" hero numbers ([HomeFocus]), the time-aware
/// greeting, the week-strip days, the order of "Today's Tasks" and the
/// "in 25 min · 10:00 AM" label of the Up Next card, and the progress of
/// the first-run "Get started" checklist ([HomeGetStarted]).
/// Why: kept out of widgets (no business logic in presentation) and pure
/// Dart, so every rule is unit-testable without Flutter.
/// ============================================================
library;

import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

/// Numbers of the Today's Focus hero card.
class HomeFocus {
  const HomeFocus({
    required this.tasksDone,
    required this.tasksDue,
    required this.goal,
    required this.habitsDone,
    required this.habitsDue,
    required this.remindersLeft,
  });

  /// Tasks completed today.
  final int tasksDone;

  /// Tasks due today, open or completed.
  final int tasksDue;

  /// Settings › Daily focus goal (tasks per day that make the hero 100%).
  final int goal;
  final int habitsDone;
  final int habitsDue;

  /// Reminders still to come today.
  final int remindersLeft;

  /// 0..1 — tasks done against the daily goal.
  double get progress => goal <= 0 ? 0 : (tasksDone / goal).clamp(0.0, 1.0);

  /// Denominator of the "4/7" tile: today's tasks, or the goal when
  /// nothing is due today.
  int get tasksTarget => tasksDue > 0 ? tasksDue : goal;

  /// Whole percent shown in the pill ("57%").
  int get percent => (progress * 100).round();

  /// The dynamic encouragement line under the title.
  String get encouragement {
    if (percent >= 100) return 'Goal reached — amazing work!';
    if (percent >= 50) return "You're doing great — keep it up!";
    if (tasksDone > 0) return 'Nice start — keep the momentum!';
    return "Let's make today count.";
  }
}

/// The "Get started" checklist: write a note, add a task, set up a
/// reminder or a habit. Each step is done once such an item exists, so the
/// card fills itself in as the user explores (no extra stored state).
class HomeGetStarted {
  const HomeGetStarted({
    required this.hasNote,
    required this.hasTask,
    required this.hasRoutine,
  });

  /// Derived from the live library totals (active items only).
  factory HomeGetStarted.of(LibraryCounts c) => HomeGetStarted(
    hasNote: c.notesTotal > 0,
    hasTask: c.tasksTotal > 0,
    hasRoutine: c.remindersTotal + c.habitsTotal > 0,
  );

  final bool hasNote;
  final bool hasTask;

  /// A reminder or a habit exists.
  final bool hasRoutine;

  static const int steps = 3;

  int get doneCount => [hasNote, hasTask, hasRoutine].where((d) => d).length;

  bool get isComplete => doneCount == steps;

  @override
  bool operator ==(Object other) =>
      other is HomeGetStarted &&
      other.hasNote == hasNote &&
      other.hasTask == hasTask &&
      other.hasRoutine == hasRoutine;

  @override
  int get hashCode => Object.hash(hasNote, hasTask, hasRoutine);
}

/// Greeting, week strip and list ordering.
abstract final class HomeRules {
  /// Rows shown in "Today's Tasks" before "View all".
  static const int maxTasks = 5;

  /// Notes in "Recent Notes" (two rows of two).
  static const int recentNotes = 4;

  /// Rings in the Habit Tracker card before it scrolls.
  static const int habitRings = 4;

  /// "Good morning" (5–11), "Good afternoon" (12–16), "Good evening".
  static String greeting(DateTime now, String name) {
    final h = now.hour;
    final part = h >= 5 && h < 12
        ? 'morning'
        : h >= 12 && h < 17
        ? 'afternoon'
        : 'evening';
    final first = firstName(name);
    return first.isEmpty ? 'Good $part' : 'Good $part, $first';
  }

  /// First word of a display name ("Asif Iqbal" → "Asif").
  static String firstName(String name) {
    final t = name.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  /// Two weeks of day pills starting on the user's week start, so the
  /// strip shows this week and the next one.
  static List<DateTime> weekDays(DateTime today, int weekStartsOn) {
    final start = DateUtilsX.startOfWeek(today, weekStartsOn);
    return [for (var i = 0; i < 14; i++) DateUtilsX.addDays(start, i)];
  }

  /// Open tasks first (timed by time, then untimed, pinned first within
  /// equal times), completed ones last — like the mockup.
  static List<TaskItem> orderTasks(List<TaskItem> tasks) {
    int key(TaskItem t) => t.dueTimeMinutes ?? 24 * 60;
    final sorted = [...tasks]
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        final byTime = key(a).compareTo(key(b));
        if (byTime != 0) return byTime;
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return sorted;
  }

  /// "in 25 min" today, otherwise "Tomorrow" / "Wed, Jun 14".
  static String relative(DateTime at, DateTime now) {
    if (DateUtilsX.isSameDay(at, now)) return DateUtilsX.until(at, now);
    return DateUtilsX.relativeDay(at, now);
  }
}
