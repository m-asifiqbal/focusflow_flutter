/// The planner's capacity rules: reminders, alarms and task alerts are
/// "vital" and keep their slots no matter how many habit nudges and digests
/// compete, and a reminder's next occurrence is planned further ahead than
/// the routine horizon — with the app closed nothing rolls the window
/// forward, so a reminder set for next week must already be with the OS.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';

import 'planner_test_data.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 9); // Tue
  final today = DateTime(2026, 10, 13);
  // Digests + habit check-ins on, so routine notifications compete.
  final busy = quiet.copyWith(
    notifyReminders: true,
    notifyHabits: true,
    morningBriefing: true,
    eveningReview: true,
  );

  List<PlannedNotification> plan(
    List<Reminder> rs, {
    int maxScheduled = 60,
    int vitalHorizonDays = 14,
    int horizonDays = 14,
  }) => NotificationPlanner.plan(
    input(
      now: now,
      settings: busy,
      reminders: rs,
      habits: [
        for (var i = 0; i < 4; i++)
          habit('h$i', today, times: const ['09:30', '13:00', '18:00']),
      ],
      horizonDays: horizonDays,
      vitalHorizonDays: vitalHorizonDays,
      maxScheduled: maxScheduled,
    ),
    maxCount: maxScheduled,
  );

  test('routine notifications alone would fill the whole cap', () {
    final out = plan(const []);
    expect(out, hasLength(60));
    // 4 habits × 3 times + 2 digests per day: the cap is reached in a few
    // days, well before the 14-day horizon.
    expect(out.last.fireAt.isBefore(DateTime.utc(2026, 10, 20)), isTrue);
  });

  test('a reminder inside the horizon is never crowded out', () {
    final at = DateTime.utc(2026, 10, 24, 8); // day 11, past the cap's reach
    final out = plan([reminder('far', at: at, notificationId: 7)]);
    expect(out, hasLength(60));
    expect(
      out.where((n) => n.reminderId == 'far'),
      hasLength(1),
      reason: 'vital notifications take their slots first',
    );
    // …and the list stays soonest-first.
    final times = out.map((n) => n.fireAt).toList();
    expect([...times]..sort(), times);
  });

  test('vital notifications beyond the cap keep the soonest ones', () {
    final rs = [
      for (var i = 0; i < 80; i++)
        reminder(
          'r$i',
          at: DateTime.utc(2026, 10, 13, 10).add(Duration(minutes: i * 30)),
        ),
    ];
    final out = plan(rs);
    expect(out, hasLength(60));
    expect(out.every(NotificationPlanner.isVital), isTrue);
    expect(
      out.last.fireAt,
      DateTime.utc(2026, 10, 13, 10).add(const Duration(minutes: 59 * 30)),
    );
  });

  test('the next occurrence is planned up to the vital horizon', () {
    final at = DateTime.utc(2026, 11, 20, 8); // 38 days out
    final r = reminder('later', at: at, notificationId: 9);
    expect(plan([r]).where((n) => n.reminderId == 'later'), isEmpty);
    expect(
      plan([r], vitalHorizonDays: 60).where((n) => n.reminderId == 'later'),
      hasLength(1),
    );
  });

  test('later repeats stay inside the routine horizon', () {
    final r = reminder(
      'daily',
      at: DateTime.utc(2026, 10, 14, 18),
      repeat: 'FREQ=DAILY',
      notificationId: 11,
    );
    final out = plan([r], vitalHorizonDays: 90, maxScheduled: 400);
    final mine = out.where((n) => n.reminderId == 'daily').toList();
    // Oct 14 … Oct 26 inside the 14-day routine horizon, not 90 days of
    // them: only the *next* occurrence reaches further.
    expect(mine, hasLength(13));
  });

  test('Android gets more room than iOS', () {
    expect(
      PlannerLimits.android.maxScheduled,
      greaterThan(PlannerLimits.conservative.maxScheduled),
    );
    expect(PlannerLimits.android.maxScheduled, lessThan(500));
    expect(
      PlannerLimits.android.vitalHorizonDays,
      greaterThan(PlannerLimits.android.horizonDays),
    );
  });
}
