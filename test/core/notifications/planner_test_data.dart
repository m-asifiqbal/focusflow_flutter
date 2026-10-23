/// Builders for the notification planner tests: plain entities (no DB) and
/// a [PlannerInput] in a named IANA zone.
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;

ZoneCalendar zone(String name) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  return ZoneCalendar(tz.getLocation(name));
}

final DateTime t0 = DateTime.utc(2020);

Reminder reminder(
  String id, {
  required DateTime at,
  String title = 'Call mom',
  String? repeat,
  AlertStyle style = AlertStyle.notification,
  DateTime? snoozedUntil,
  ItemRef? linked,
  bool enabled = true,
  DateTime? completedAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
  int notificationId = 0,
}) => Reminder(
  id: id,
  title: title,
  triggerAt: at,
  repeatRule: repeat,
  alertStyle: style,
  snoozedUntil: snoozedUntil,
  linkedRef: linked,
  isEnabled: enabled,
  completedAt: completedAt,
  archivedAt: archivedAt,
  deletedAt: deletedAt,
  notificationId: notificationId,
  createdAt: t0,
  updatedAt: t0,
);

TaskItem task(
  String id, {
  String title = 'Task',
  DateTime? due,
  DateTime? completedAt,
  DateTime? archivedAt,
}) => TaskItem(
  id: id,
  title: title,
  dueDate: due,
  completedAt: completedAt,
  archivedAt: archivedAt,
  createdAt: t0,
  updatedAt: t0,
);

HabitDayStatus habit(
  String id,
  DateTime day, {
  String name = 'Drink water',
  List<String> times = const ['09:00'],
  int target = 8,
  int count = 0,
  bool done = false,
  int streak = 0,
  HabitKind kind = HabitKind.build,
  bool remind = true,
}) {
  final h = Habit(
    id: id,
    name: name,
    kind: kind,
    targetCount: target,
    unit: 'glasses',
    reminderEnabled: remind,
    reminderTimes: times,
    startDate: DateTime(2020),
    createdAt: t0,
    updatedAt: t0,
  );
  return HabitDayStatus(
    habit: h,
    day: day,
    log: count == 0
        ? null
        : HabitLog(
            id: 'log-$id',
            habitId: id,
            date: day,
            count: count,
            createdAt: t0,
            updatedAt: t0,
          ),
    progress: count / target,
    isDone: done,
    isScheduled: true,
    streak: HabitStreak(current: streak, best: streak),
    week: const [],
  );
}

/// Every switch off — tests turn on what they look at.
const AppSettings quiet = AppSettings(
  morningBriefing: false,
  eveningReview: false,
  weeklyReport: false,
  notifyReminders: false,
  notifyTasks: false,
  notifyHabits: false,
  notifyStreakRisk: false,
  notifyMedicines: false,
  quietHours: false,
  badgeMode: BadgeMode.none,
);

PlannerInput input({
  required DateTime now,
  ZoneCalendar? calendar,
  AppSettings settings = quiet,
  List<Reminder> reminders = const [],
  List<TaskItem> tasks = const [],
  List<HabitDayStatus> habits = const [],
  int horizonDays = 14,
  int vitalHorizonDays = 14,
  int maxScheduled = PlannerInput.defaultMaxScheduled,
}) => PlannerInput(
  now: now,
  calendar: calendar ?? zone('UTC'),
  settings: settings,
  reminders: reminders,
  tasks: tasks,
  habits: habits,
  horizonDays: horizonDays,
  vitalHorizonDays: vitalHorizonDays,
  maxScheduled: maxScheduled,
);
