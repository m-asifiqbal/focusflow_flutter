/// Prayer notifications: a start reminder `remindBefore` minutes before the
/// window and a "before it ends" one while not marked; none once marked;
/// a fast's Iftar call even when marked fasted (not when broken); alarm /
/// quiet by priority; discreet titles; the iOS-sized horizon; sun-based
/// windows from the saved location; and Done / Snooze performed from a
/// notification against the real repository.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/prayer_planner.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'planner_test_data.dart';

final _t0 = DateTime.utc(2026);

Prayer _prayer(
  String id, {
  String name = 'Asr',
  PrayerKind kind = PrayerKind.salah,
  PrayerTimeRule start = const PrayerTimeRule.fixed(15 * 60 + 45),
  PrayerTimeRule? end = const PrayerTimeRule.fixed(17 * 60 + 45),
  PrayerPriority priority = PrayerPriority.normal,
  int? remindBefore = 10,
  int? remindBeforeEnd = 20,
}) => Prayer(
  id: id,
  name: name,
  kind: kind,
  start: start,
  end: end,
  priority: priority,
  remindBefore: remindBefore,
  remindBeforeEnd: remindBeforeEnd,
  createdAt: _t0,
  updatedAt: _t0,
);

PrayerLog _log(Prayer p, DateTime day, PrayerStatus status) =>
    PrayerLog(prayerId: p.id, day: day, status: status);

void main() {
  // 07:00 UTC on Oct 23 (the planner works in the UTC zone here).
  final now = DateTime.utc(2026, 10, 23, 7);
  final day = DateTime(2026, 10, 23);

  PlannerInput input(
    List<Prayer> prayers, {
    List<PrayerLog> logs = const [],
    PrayerPrefs prefs = const PrayerPrefs(discreet: false),
    int maxScheduled = 240,
  }) => PlannerInput(
    now: now,
    calendar: zone('UTC'),
    settings: quiet.copyWith(prayer: prefs),
    prayers: prayers,
    prayerLogs: logs,
    horizonDays: 1,
    vitalHorizonDays: 1,
    maxScheduled: maxScheduled,
  );

  List<PlannedNotification> plan(
    List<Prayer> prayers, {
    List<PrayerLog> logs = const [],
    PrayerPrefs prefs = const PrayerPrefs(discreet: false),
  }) => PrayerPlanner.plan(
    input(prayers, logs: logs, prefs: prefs),
    DateTime.utc(2026, 10, 24),
  );

  test('a start reminder and a "before it ends" one', () {
    final p = _prayer('a');
    final out = plan([p]);
    expect(out.map((n) => n.key).toList()..sort(), [
      'pry:2026-10-23:a:e',
      'pry:2026-10-23:a:s',
    ]);
    final start = out.firstWhere((n) => n.key.endsWith(':s'));
    expect(start.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 15, 35));
    expect(start.title, 'Asr in 10 min');
    expect(start.body, '3:45 PM – 5:45 PM');
    expect(start.category, NotificationCategory.prayer);
    expect(start.buttons, [
      NotificationButton.done,
      NotificationButton.snooze,
      NotificationButton.open,
    ]);
    expect(start.payload.day, '2026-10-23');
    expect(NotificationPlanner.isVital(start), isTrue);
    final end = out.firstWhere((n) => n.key.endsWith(':e'));
    expect(end.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 17, 25));
    expect(end.title, 'Asr ends in 20 min');
    expect(end.inbox, isFalse);
    expect(NotificationPlanner.isVital(end), isFalse);
  });

  test('jamaat: a reminder before the congregation, until marked', () {
    final p = _prayer('a', remindBefore: null, remindBeforeEnd: null).copyWith(
      tradition: PrayerTradition.islam,
      jamaat: const PrayerJamaat.at(16 * 60 + 15),
      remindBeforeJamaat: 10,
      place: 'Baitul Mukarram',
    );
    final out = plan([p]);
    expect(out.map((n) => n.key), ['pry:2026-10-23:a:j']);
    final j = out.single;
    expect(j.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 16, 5));
    expect(j.title, 'Asr jamaat in 10 min');
    expect(j.body, 'Jamaat at 4:15 PM · Baitul Mukarram');
    expect(j.inbox, isTrue);
    // Minutes after the start; at the time itself; other traditions.
    final after = plan([
      p.copyWith(
        jamaat: const PrayerJamaat.afterStart(20),
        remindBeforeJamaat: 0,
        tradition: PrayerTradition.christianity,
      ),
    ]).single;
    expect(after.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 16, 5));
    expect(after.title, 'Asr with the congregation now');
    // Discreet: the time only. Marked: nothing.
    expect(
      plan([p], prefs: const PrayerPrefs()).single.title,
      'Reminder · 4:15 PM',
    );
    expect(plan([p], logs: [_log(p, day, PrayerStatus.onTime)]), isEmpty);
    // No reminder chosen: nothing planned.
    expect(plan([p.copyWith(clearRemindBeforeJamaat: true)]), isEmpty);
  });

  test('marked prayers are left alone', () {
    final p = _prayer('a');
    expect(plan([p], logs: [_log(p, day, PrayerStatus.onTime)]), isEmpty);
    expect(plan([p], logs: [_log(p, day, PrayerStatus.excused)]), isEmpty);
    final key = 'pry:2026-10-23:a:s';
    final i = input([p], logs: [_log(p, day, PrayerStatus.onTime)]);
    expect(PrayerPlanner.stillWanted(i, key), isFalse);
    expect(PrayerPlanner.stillWanted(input([p]), key), isTrue);
  });

  test(
    'a fast: Suhoor before the start, Iftar at the end even when fasted',
    () {
      final f = _prayer(
        'f',
        name: 'Ramadan fast',
        kind: PrayerKind.fasting,
        start: const PrayerTimeRule.fixed(5 * 60),
        end: const PrayerTimeRule.fixed(18 * 60),
        remindBefore: 30,
        remindBeforeEnd: 0,
      ).copyWith(tradition: PrayerTradition.islam);
      // 07:00 now: the Suhoor call (04:30) has passed; Iftar remains.
      final fasted = plan([f], logs: [_log(f, day, PrayerStatus.onTime)]);
      expect(fasted.map((n) => n.key), ['pry:2026-10-23:f:e']);
      expect(fasted.single.title, 'Iftar time');
      expect(fasted.single.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 18));
      expect(fasted.single.inbox, isTrue);
      // Broken early / not fasted: no Iftar call.
      expect(plan([f], logs: [_log(f, day, PrayerStatus.late)]), isEmpty);
      expect(plan([f], logs: [_log(f, day, PrayerStatus.missed)]), isEmpty);
    },
  );

  test("a fast ends in the tradition's own words", () {
    String title(PrayerTradition t) {
      final f = _prayer(
        'f',
        kind: PrayerKind.fasting,
        start: const PrayerTimeRule.fixed(5 * 60),
        end: const PrayerTimeRule.fixed(18 * 60),
        remindBefore: null,
        remindBeforeEnd: 0,
      ).copyWith(tradition: t);
      return plan([f]).singleWhere((n) => n.key.endsWith(':e')).title;
    }

    expect(title(PrayerTradition.islam), 'Iftar time');
    expect(title(PrayerTradition.judaism), 'The fast ends');
    expect(title(PrayerTradition.hinduism), 'Time to break the fast');
    expect(title(PrayerTradition.buddhism), 'The observance ends');
  });

  test('priority: high rings as an alarm, low is silent', () {
    final high = plan([_prayer('h', priority: PrayerPriority.high)]);
    expect(
      high.firstWhere((n) => n.key.endsWith(':s')).category,
      NotificationCategory.alarm,
    );
    // The "ends soon" nudge never rings.
    expect(
      high.firstWhere((n) => n.key.endsWith(':e')).category,
      NotificationCategory.prayer,
    );
    final low = plan([_prayer('l', priority: PrayerPriority.low)]);
    expect(low.every((n) => n.isSilent), isTrue);
  });

  test('discreet titles name only the time; reminders off plans nothing', () {
    final out = plan([_prayer('a')], prefs: const PrayerPrefs());
    final start = out.firstWhere((n) => n.key.endsWith(':s'));
    expect(start.title, 'Reminder · 3:45 PM');
    expect(start.body, contains('Asr'));
    expect(
      plan([_prayer('a')], prefs: const PrayerPrefs(notify: false)),
      isEmpty,
    );
  });

  test('a snoozed start reminder comes back under its own key', () {
    final p = _prayer('a');
    final log = PrayerLog(
      prayerId: p.id,
      day: day,
      status: PrayerStatus.pending,
      snoozedUntil: DateTime.utc(2026, 10, 23, 15, 55),
    );
    final out = plan([p], logs: [log]);
    final snoozed = out.firstWhere((n) => n.key.endsWith(':z'));
    expect(snoozed.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 15, 55));
    expect(out.any((n) => n.key.endsWith(':s')), isFalse);
  });

  test('horizon: 3 days where the OS holds little (iOS), 10 on Android', () {
    final p = _prayer('a');
    final far = DateTime.utc(2026, 11, 30);
    int days(int max) => PrayerPlanner.plan(
      input([p], maxScheduled: max),
      far,
    ).where((n) => n.key.endsWith(':s')).length;
    expect(days(PlannerInput.defaultMaxScheduled), 3);
    expect(days(240), 10);
  });

  test('sun-based windows follow the saved location', () {
    final p = _prayer(
      'f',
      name: 'Fajr',
      start: const PrayerTimeRule.auto(SolarEvent.dawn, minutes: 300),
      end: const PrayerTimeRule.auto(SolarEvent.sunrise, minutes: 375),
      remindBefore: 0,
      remindBeforeEnd: null,
    );
    const dhaka = PrayerPrefs(
      latitude: 23.8103,
      longitude: 90.4125,
      discreet: false,
    );
    final i = PlannerInput(
      now: DateTime.utc(2026, 10, 22, 12),
      calendar: zone('Asia/Dhaka'),
      settings: quiet.copyWith(prayer: dhaka),
      prayers: [p],
      horizonDays: 2,
      vitalHorizonDays: 2,
      maxScheduled: 240,
    );
    final out = PrayerPlanner.plan(i, DateTime.utc(2026, 10, 24));
    final sun = PrayerTimes.compute(
      const PrayerCalcSettings(
        location: GeoPoint(23.8103, 90.4125),
        method: PrayerCalcMethod.karachi,
      ),
      DateTime(2026, 10, 23),
    );
    final fajr = out.firstWhere((n) => n.key == 'pry:2026-10-23:f:s');
    expect(fajr.fireAt.isAtSameMomentAs(sun.dawn), isTrue);
  });

  test('Done and Snooze from a notification', () async {
    final h = await TestHarness.create(now: DateTime(2026, 10, 23, 15, 40));
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final id = await repo.save(_prayer('').copyWith());
    final actions = h.read(notificationActionsProvider);
    final payload = NotificationPayload(
      key: 'pry:2026-10-23:$id:s',
      category: NotificationCategory.prayer,
      target: (await repo.getPrayer(id))!.ref,
      snoozeMinutes: 10,
      day: '2026-10-23',
    );
    expect(await actions.perform(NotificationButton.snooze, payload), isTrue);
    final snoozed = await repo.log(id, DateTime(2026, 10, 23));
    expect(snoozed?.status, PrayerStatus.pending);
    expect(snoozed?.snoozedUntil, DateTime(2026, 10, 23, 15, 50));
    expect(await actions.perform(NotificationButton.done, payload), isTrue);
    final done = await repo.log(id, DateTime(2026, 10, 23));
    expect(done?.status, PrayerStatus.onTime);
    expect(done?.snoozedUntil, isNull);
    // Again: nothing more to do.
    expect(await actions.perform(NotificationButton.done, payload), isFalse);
  });
}
