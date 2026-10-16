/// Engine fixes: exact vs inexact is part of the fingerprint (a grant /
/// revoke re-schedules; a revoked exact alarm is not trusted), the ledger
/// merges across isolates, the reserved badge id is never planned, the
/// background maintenance pass records deliveries and refills the window,
/// background isolates ping the app, task reminders follow the zone.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/engine/background_reconcile.dart';
import 'package:focusflow/core/notifications/engine/notification_actions.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/engine/refresh_port.dart';
import 'package:focusflow/core/notifications/engine/task_reminder_zones.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/sync/background_runner.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/test_container.dart';
import 'fake_gateway.dart';
import 'planner_test_data.dart';

void main() {
  final start = DateTime(2026, 10, 13, 9);
  late TestHarness h;
  late FakeGateway os;
  late MemoryLedgerStore ledger;

  final settings = quiet.copyWith(notifyReminders: true, notifyTasks: true);

  setUp(() async {
    os = FakeGateway();
    ledger = MemoryLedgerStore();
    h = await TestHarness.create(
      now: start,
      prefs: {SettingsController.prefsKey: jsonEncode(settings.toJson())},
      overrides: [
        notificationGatewayProvider.overrideWithValue(os),
        notificationLedgerStoreProvider.overrideWithValue(ledger),
      ],
    );
  });
  tearDown(() => h.dispose());

  Future<String> addReminder(DateTime at) => h
      .read(remindersRepositoryProvider)
      .save(Reminder.draft(triggerAt: at, title: 'Call mom'));

  Future<ReconcileResult> pass() async {
    final s = h.read(settingsProvider);
    final input = await h.read(plannerSnapshotLoaderProvider).load(s, tz.UTC);
    return h
        .read(notificationReconcilerProvider)
        .reconcile(input, allowed: true, location: tz.UTC);
  }

  group('exact alarms', () {
    test('grant / revoke changes the fingerprint and re-schedules', () async {
      await addReminder(start.add(const Duration(hours: 1)));
      expect((await pass()).scheduled, 1);
      final id = os.pending.keys.single;
      expect(os.options[id]!.exact, isTrue);
      expect((await pass()).scheduled, 0);

      // Revoked: the plugin still lists it, but it is rescheduled inexact.
      os.exact = ExactAlarmPermission.denied;
      expect((await pass()).scheduled, 1);
      expect(os.options[id]!.exact, isFalse);
      expect(ledger.entries.single.exact, isFalse);
      expect((await pass()).scheduled, 0);

      os.exact = ExactAlarmPermission.granted;
      expect((await pass()).scheduled, 1);
      expect(os.options[id]!.exact, isTrue);
    });

    test('a due exact alarm is not trusted after a revoke', () async {
      final at = start.add(const Duration(minutes: 30));
      await addReminder(at);
      await pass();
      final id = os.pending.keys.single;
      // Past its time, the plugin still lists it, exact was revoked.
      h.clock.set(start.add(const Duration(minutes: 31)));
      os.exact = ExactAlarmPermission.denied;
      final r = await pass();
      expect(r.delivered, 1);
      expect(os.cancelled, contains(id));
      final inbox = await h.read(inboxRepositoryProvider).watch().first;
      expect(inbox.single.createdAt, at);
    });

    test('variant only marks inexact (old ledgers stay valid)', () {
      expect(const DeliveryOptions(exact: true).variant, 'l1');
      expect(const DeliveryOptions(exact: false).variant, 'l1i');
    });

    test('engine re-plans on resume after a revoke', () async {
      await addReminder(start.add(const Duration(hours: 1)));
      final engine =
          h.read(notificationEngineProvider) as ReconcilingNotificationEngine;
      await engine.start();
      final id = os.pending.keys.single;
      expect(os.options[id]!.exact, isTrue);
      expect(
        await h.read(exactAlarmPermissionProvider.future),
        ExactAlarmPermission.granted,
      );
      os.exact = ExactAlarmPermission.denied;
      await engine.onResume();
      expect(os.options[id]!.exact, isFalse);
      expect(
        await h.read(exactAlarmPermissionProvider.future),
        ExactAlarmPermission.denied,
      );
    });
  });

  group('ledger merge', () {
    LedgerEntry entry(int id, DateTime at) => LedgerEntry(
      id: id,
      key: 'rem:$id:1',
      fireAt: at,
      fingerprint: 'f$id',
      kind: InboxKind.reminder,
      title: 't',
    );

    test('a delivery is claimed once across two passes', () async {
      final e = entry(1, start);
      ledger.entries = [e, entry(2, start.add(const Duration(hours: 1)))];
      final first = await ledger.claimDeliveries([e], now: start);
      final second = await ledger.claimDeliveries([e], now: start);
      expect(first, [e]);
      expect(second, isEmpty);
      expect(ledger.entries.map((x) => x.id), [2]);
    });

    test('commit keeps entries another isolate added meanwhile', () async {
      final mine = entry(1, start.add(const Duration(hours: 1)));
      ledger.entries = [mine];
      final base = await ledger.load();
      // The other isolate schedules #3 while this pass runs.
      final theirs = entry(3, start.add(const Duration(hours: 2)));
      ledger.entries = [mine, theirs];
      await ledger.commit(base, [mine], now: start);
      expect(ledger.entries.map((x) => x.id), [1, 3]);
      // Nothing already delivered is written back.
      await ledger.claimDeliveries([theirs], now: start);
      await ledger.commit(base, [mine, theirs], now: start);
      expect(ledger.entries.map((x) => x.id), [1]);
    });

    test('secure encoding keeps delivery markers', () {
      final raw = SecureLedgerStore.encode(
        [entry(1, start)],
        owner: 'a',
        delivered: {'rem:9:1@5'},
      );
      final st = SecureLedgerStore.decodeState(raw, owner: 'a');
      expect(st.entries, hasLength(1));
      expect(st.delivered, {'rem:9:1@5'});
    });
  });

  test('the reserved badge id is never planned', () {
    final at = DateTime.utc(2026, 10, 13, 15);
    final out = NotificationPlanner.plan(
      input(
        now: DateTime.utc(2026, 10, 13, 9),
        settings: quiet.copyWith(notifyReminders: true),
        reminders: [
          reminder('a', at: at, notificationId: reservedNotificationId - 1),
          reminder(
            'b',
            at: at.add(const Duration(minutes: 1)),
            notificationId: reservedNotificationId - 1,
          ),
        ],
      ),
    );
    expect(out.map((n) => n.id), [
      reservedNotificationId - 1,
      reservedNotificationId + 1,
    ]);
  });

  test('maintenance pass records deliveries and refills the window', () async {
    final at = start.add(const Duration(minutes: 30));
    await addReminder(at);
    await pass();
    // Delivered while the app was not running; a new reminder appeared.
    h.clock.set(start.add(const Duration(hours: 1)));
    os.deliverUntil(h.clock.now());
    await addReminder(start.add(const Duration(hours: 5)));

    var initialized = false;
    final ok = await runNotificationMaintenance(h.container.read, () async {
      initialized = true;
    });
    expect(ok, isTrue);
    expect(initialized, isTrue);
    final inbox = await h.read(inboxRepositoryProvider).watch().first;
    expect(inbox.single.createdAt, at);
    expect(
      os.pending.values.single.fireAt,
      start.add(const Duration(hours: 5)),
    );
  });

  test('a background pass pings the running app', () async {
    var pings = 0;
    final port = NotificationRefreshPort.listen(() => pings++);
    addTearDown(() => NotificationRefreshPort.close(port));
    await reconcileInBackground(h.container.read);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pings, 1);
  });

  test(
    'task reminders follow the planning zone (also across launches)',
    () async {
      final tasks = h.read(tasksRepositoryProvider);
      final id = await tasks.save(
        TaskItem.draft(
          now: start,
          title: 'Report',
          dueDate: DateTime(2026, 10, 14),
          dueTimeMinutes: 10 * 60,
        ).copyWith(remindOffsetMinutes: 15),
      );
      final rid = (await tasks.getTask(id))!.reminderId!;
      final prefs = h.read(sharedPreferencesProvider);
      final reminders = h.read(remindersRepositoryProvider);
      NotificationZones.ensureLoaded();
      final kiritimati = tz.getLocation('Pacific/Kiritimati'); // UTC+14
      final adak = tz.getLocation('America/Adak'); // UTC-9/-10

      expect(await TaskReminderZones.align(reminders, prefs, kiritimati), 1);
      expect(
        (await reminders.getReminder(rid))!.triggerAt,
        ZoneCalendar(kiritimati).at(DateTime(2026, 10, 14), 9 * 60 + 45),
      );
      expect(prefs.getString(TaskReminderZones.lastZoneKey), kiritimati.name);

      // Next launch, after travel: the last zone comes from preferences.
      expect(await TaskReminderZones.align(reminders, prefs, adak), 1);
      expect(
        (await reminders.getReminder(rid))!.triggerAt,
        ZoneCalendar(adak).at(DateTime(2026, 10, 14), 9 * 60 + 45),
      );
      expect(await TaskReminderZones.align(reminders, prefs, adak), 0);
    },
  );

  test('payload keys carry the occurrence', () {
    expect(
      NotificationActions.occurrenceOf('rem:abc:1760000000'),
      DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000),
    );
    expect(NotificationActions.occurrenceOf('hab:x:2026-10-13:540'), isNull);
    expect(NotificationButton.open.showsUserInterface, isTrue);
    expect(NotificationButton.done.showsUserInterface, isFalse);
  });
}
