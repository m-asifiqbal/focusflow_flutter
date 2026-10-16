/// ============================================================
/// DIGEST PLANNER — morning briefing, evening review, weekly report,
/// overdue-tasks summary and the app-icon badge
/// ============================================================
///
/// * Morning briefing (at its time, every day): today's open tasks,
///   reminders and scheduled habits.
/// * Evening review (at its time, every day): today's progress; later days
///   get a generic "plan tomorrow" line (their numbers aren't known yet —
///   the plan is rebuilt as data changes, so today's text stays current).
/// * Weekly report (chosen weekday, 18:00) → Insights.
/// * Overdue tasks (Tasks switch, at the morning-briefing time): "2 tasks
///   are overdue · Submit tax documents, Renew gym…" with Reschedule / View
///   in the inbox (screen 27). Overdue is day-based, like the tasks list.
/// * Badge: overdue count / due today + overdue / none (Settings ›
///   App icon badge), predicted for the day each notification fires.
/// ============================================================
library;

import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

abstract final class DigestPlanner {
  static List<PlannedNotification> plan(PlannerInput input, DateTime until) {
    final s = input.settings;
    final cal = input.calendar;
    final result = <PlannedNotification>[];
    for (var day = input.today; ; day = ZoneCalendar.addDays(day, 1)) {
      if (!cal.at(day, 0).isBefore(until)) break;
      final dayKey = ZoneCalendar.dayKey(day);
      PlannedNotification? at(
        int minutes,
        String prefix,
        PlannedNotification Function(String key, DateTime fireAt) build,
      ) {
        final fireAt = cal.at(day, minutes);
        if (!fireAt.isAfter(input.now) || !fireAt.isBefore(until)) return null;
        return build('$prefix:$dayKey', fireAt);
      }

      if (s.notifyTasks) {
        final overdue = overdueOn(input.tasks, day);
        if (overdue.isNotEmpty) {
          final n = at(
            s.morningBriefingMinutes,
            'ovd',
            (key, fireAt) => _overdue(key, fireAt, overdue),
          );
          if (n != null) result.add(n);
        }
      }
      if (s.morningBriefing) {
        final n = at(
          s.morningBriefingMinutes,
          'dgm',
          (key, fireAt) => _digest(
            key,
            fireAt,
            title: 'Good morning',
            body: _morningBody(input, day),
            route: AppRoutes.home,
          ),
        );
        if (n != null) result.add(n);
      }
      if (s.eveningReview) {
        final n = at(
          s.eveningReviewMinutes,
          'dge',
          (key, fireAt) => _digest(
            key,
            fireAt,
            title: 'Evening review',
            body: day == input.today
                ? _eveningBody(input, day)
                : 'Look back on your day and plan tomorrow.',
            route: AppRoutes.home,
          ),
        );
        if (n != null) result.add(n);
      }
      if (s.weeklyReport && day.weekday == s.weeklyReportWeekday) {
        final n = at(
          PlannerTimes.weeklyReportMinutes,
          'dgw',
          (key, fireAt) => _digest(
            key,
            fireAt,
            title: 'Your weekly report',
            body: 'See how your week went — tasks, habits and focus time.',
            route: AppRoutes.insights,
          ),
        );
        if (n != null) result.add(n);
      }
    }
    return result;
  }

  // ───────────────────────── Tasks maths ─────────────────────────

  static bool _open(TaskItem t) => t.isActive && !t.isCompleted;

  /// Open tasks due before [day] (overdue on that day), oldest first.
  static List<TaskItem> overdueOn(List<TaskItem> tasks, DateTime day) => [
    for (final t in tasks)
      if (_open(t) &&
          t.dueDate != null &&
          DateUtilsX.daysBetween(t.dueDate!, day) > 0)
        t,
  ]..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

  /// Open tasks due on [day].
  static List<TaskItem> dueOn(List<TaskItem> tasks, DateTime day) => [
    for (final t in tasks)
      if (_open(t) &&
          t.dueDate != null &&
          DateUtilsX.daysBetween(t.dueDate!, day) == 0)
        t,
  ];

  /// App icon badge on [day] for [mode] (null = no badge).
  static int? badgeOn(List<TaskItem> tasks, DateTime day, BadgeMode mode) =>
      switch (mode) {
        BadgeMode.none => null,
        BadgeMode.overdue => overdueOn(tasks, day).length,
        BadgeMode.today =>
          overdueOn(tasks, day).length + dueOn(tasks, day).length,
      };

  // ───────────────────────── Content ─────────────────────────

  static PlannedNotification _overdue(
    String key,
    DateTime fireAt,
    List<TaskItem> overdue,
  ) {
    final n = overdue.length;
    return PlannedNotification(
      id: notificationIdForKey(key),
      key: key,
      fireAt: fireAt,
      category: NotificationCategory.task,
      title: n == 1 ? '1 task is overdue' : '$n tasks are overdue',
      body: overdue
          .map((t) => t.title.trim())
          .where((t) => t.isNotEmpty)
          .join(', '),
      payload: NotificationPayload(
        key: key,
        category: NotificationCategory.task,
        route: AppRoutes.tasks,
      ),
      inboxActions: const [InboxActions.reschedule, InboxActions.view],
    );
  }

  static PlannedNotification _digest(
    String key,
    DateTime fireAt, {
    required String title,
    required String body,
    required String route,
  }) => PlannedNotification(
    id: notificationIdForKey(key),
    key: key,
    fireAt: fireAt,
    category: NotificationCategory.digest,
    title: title,
    body: body,
    payload: NotificationPayload(
      key: key,
      category: NotificationCategory.digest,
      route: route,
    ),
    inboxActions: const [InboxActions.open],
  );

  static String _morningBody(PlannerInput input, DateTime day) {
    final cal = input.calendar;
    final tasks = dueOn(input.tasks, day).length;
    final from = cal.at(day, 0);
    final to = cal.at(ZoneCalendar.addDays(day, 1), 0);
    var reminders = 0;
    for (final r in input.reminders) {
      reminders += ReminderSchedule.between(
        r,
        from,
        to,
      ).where((o) => !o.isDone).length;
    }
    final habits = input.habits
        .where((s) => HabitSchedule.isScheduledOn(s.habit, day))
        .length;
    final parts = [
      if (tasks > 0) _count(tasks, 'task'),
      if (reminders > 0) _count(reminders, 'reminder'),
      if (habits > 0) _count(habits, 'habit'),
    ];
    if (parts.isEmpty) return 'Nothing scheduled today — a fresh start.';
    return '${_join(parts)} today.';
  }

  static String _eveningBody(PlannerInput input, DateTime day) {
    final cal = input.calendar;
    final done = input.tasks
        .where(
          (t) =>
              t.isActive &&
              t.completedAt != null &&
              cal.dayOf(t.completedAt!) == day,
        )
        .length;
    final open = dueOn(input.tasks, day).length;
    final scheduled = input.habits.where((s) => s.isScheduled).toList();
    final habitsDone = scheduled.where((s) => s.isDone).length;
    final parts = [
      if (done + open > 0) 'You finished $done of ${done + open} tasks',
      if (scheduled.isNotEmpty)
        '$habitsDone of ${scheduled.length} habits done',
    ];
    if (parts.isEmpty) return 'Look back on your day and plan tomorrow.';
    return '${parts.join(' · ')}. Plan tomorrow?';
  }

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

  static String _join(List<String> parts) => parts.length == 1
      ? parts.first
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
