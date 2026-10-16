/// ============================================================
/// INSIGHTS PROVIDERS — live analytics for the Insights tab (screen 25)
/// ============================================================
///
///   insightsRangeProvider   the selected range chip (7 Days by default)
///   insightsProvider(range) the InsightsSnapshot of a range, live
///
/// Why: [insightsProvider] combines one repository stream per source
/// (tasks due / completed, focus sessions, habits + logs, notes, reminders,
/// today's habit cards) over the current *and* previous window, and runs
/// the pure InsightsAggregator on every emission — completing a task or
/// logging a habit anywhere updates the charts immediately.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/data/stream_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/insights/domain/entities/focus_session.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/domain/services/insights_aggregator.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// The selected range; kept while the app runs (switching tabs keeps it).
class InsightsRangeController extends Notifier<InsightsRange> {
  @override
  InsightsRange build() => InsightsRange.initial;

  void select(InsightsRange range) => state = range;
}

final insightsRangeProvider =
    NotifierProvider<InsightsRangeController, InsightsRange>(
      InsightsRangeController.new,
    );

/// Live snapshot of [range] (deltas against the previous equal window).
final insightsProvider = StreamProvider.autoDispose
    .family<InsightsSnapshot, InsightsRange>((ref, range) {
      final today = ref.watch(todayProvider);
      final clock = ref.watch(clockProvider);
      final window = range.resolve(today);
      final from = window.previous.start;
      final to = window.end;
      final tasks = ref.watch(tasksRepositoryProvider);
      final habits = ref.watch(habitsRepositoryProvider);
      final streams = <Stream<Object?>>[
        tasks.watchTasksInRange(from, to),
        tasks.watchCompletedInRange(from, to),
        ref.watch(focusSessionsRepositoryProvider).watchRange(from, to),
        habits.watchHabits(const HabitsQuery()),
        habits.watchLogsInRange(from, window.lastDay),
        ref.watch(notesRepositoryProvider).watchCreatedInRange(from, to),
        ref.watch(remindersRepositoryProvider).watchInRange(window.start, to),
        habits.watchTodayHabits(
          ref.watch(habitTodayProvider),
          weekStartsOn: ref.watch(habitWeekStartProvider),
        ),
      ];
      const aggregator = InsightsAggregator();
      return combineLatestList(
        streams,
        (v) => aggregator.compute(
          InsightsSources(
            tasksDue: v[0]! as List<TaskItem>,
            tasksCompleted: v[1]! as List<TaskItem>,
            focusSessions: v[2]! as List<FocusSession>,
            habits: v[3]! as List<Habit>,
            habitLogs: v[4]! as List<HabitLog>,
            notesCreated: v[5]! as List<DateTime>,
            reminders: v[6]! as List<ReminderOccurrence>,
            habitStatuses: v[7]! as List<HabitDayStatus>,
          ),
          window,
          clock.now(),
        ),
      );
    });
