/// Notification engine over a real (keyed temp) database and a fake OS:
/// reconcile schedules / skips / cancels, deliveries become inbox entries
/// and stamp `lastFiredAt`, permission and the master switch gate
/// everything, actions (Done / Snooze / Check in) and the running engine.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/engine/notification_actions.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/system_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
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

  final settings = quiet.copyWith(
    notifyReminders: true,
    notifyTasks: true,
    notifyHabits: true,
  );

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

  Future<String> addReminder(
    DateTime at, {
    String title = 'Call mom',
    ItemRef? link,
  }) => h
      .read(remindersRepositoryProvider)
      .save(Reminder.draft(triggerAt: at, title: title, linkedRef: link));

  Future<ReconcileResult> pass({bool allowed = true}) async {
    final s = h.read(settingsProvider);
    final input = await h.read(plannerSnapshotLoaderProvider).load(s, tz.UTC);
    return h
        .read(notificationReconcilerProvider)
        .reconcile(input, allowed: allowed, location: tz.UTC);
  }

  group('reconciler', () {
    test('schedules once, skips unchanged, reschedules on edit', () async {
      final id = await addReminder(start.add(const Duration(hours: 1)));
      final r1 = await pass();
      expect(r1.scheduled, 1);
      expect(os.pending, hasLength(1));
      final r = await h.read(remindersRepositoryProvider).getReminder(id);
      expect(os.pending.keys.single, r!.notificationId);
      expect(ledger.entries.single.title, 'Call mom');

      final r2 = await pass();
      expect(r2.scheduled, 0);
      expect(r2.cancelled, 0);

      await h
          .read(remindersRepositoryProvider)
          .reschedule(id, start.add(const Duration(hours: 2)));
      final r3 = await pass();
      expect(r3.scheduled, 1);
      expect(
        os.pending.values.single.fireAt,
        start.add(const Duration(hours: 2)),
      );
    });

    test('a delivered notification becomes an inbox entry once', () async {
      final at = start.add(const Duration(minutes: 30));
      final id = await addReminder(at);
      await pass();

      h.clock.set(start.add(const Duration(hours: 1)));
      os.deliverUntil(h.clock.now());
      final r = await pass();
      expect(r.delivered, 1);

      final entries = await h.read(inboxRepositoryProvider).watch().first;
      expect(entries, hasLength(1));
      expect(entries.single.kind, InboxKind.reminder);
      expect(entries.single.title, 'Call mom');
      expect(entries.single.createdAt, at);
      expect(entries.single.actions, [InboxActions.done, InboxActions.snooze]);
      final rem = await h.read(remindersRepositoryProvider).getReminder(id);
      expect(rem!.lastFiredAt, at);

      expect((await pass()).delivered, 0);
      expect(await h.read(inboxRepositoryProvider).watch().first, hasLength(1));
    });

    test(
      'archived / trashed items and their reminders are cancelled',
      () async {
        final taskId = await h
            .read(tasksRepositoryProvider)
            .save(TaskItem.draft(now: start, title: 'Pay rent'));
        final link = ItemRef(ItemType.task, taskId);
        await addReminder(start.add(const Duration(hours: 3)), link: link);
        final other = await addReminder(start.add(const Duration(hours: 4)));
        await pass();
        expect(os.pending, hasLength(2));

        await h.read(itemsRepositoryProvider).archive([link]);
        await h.read(itemsRepositoryProvider).moveToTrash([
          ItemRef(ItemType.reminder, other),
        ]);
        final r = await pass();
        expect(r.cancelled, 2);
        expect(os.pending, isEmpty);
        expect(ledger.entries, isEmpty);
      },
    );

    test('no permission or master switch off → nothing pending', () async {
      await addReminder(start.add(const Duration(hours: 1)));
      await pass();
      expect(os.pending, hasLength(1));
      await pass(allowed: false);
      expect(os.pending, isEmpty);

      await pass();
      expect(os.pending, hasLength(1));
      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(notificationsEnabled: false));
      await pass();
      expect(os.pending, isEmpty);
    });

    test('badge follows the badge mode', () async {
      await h
          .read(tasksRepositoryProvider)
          .save(
            TaskItem.draft(
              now: start,
              title: 'Late',
              dueDate: DateTime(2026, 10, 10),
            ),
          );
      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(badgeMode: BadgeMode.overdue));
      expect((await pass()).badge, 1);
      expect(os.badge, 1);
      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(badgeMode: BadgeMode.none));
      await pass();
      expect(os.badge, 0);
    });
  });

  group('actions', () {
    test('snooze moves the pending occurrence', () async {
      final id = await addReminder(start.subtract(const Duration(minutes: 1)));
      final ok = await h
          .read(notificationActionsProvider)
          .snooze(ItemRef(ItemType.reminder, id), minutes: 15);
      expect(ok, isTrue);
      final r = await h.read(remindersRepositoryProvider).getReminder(id);
      expect(r!.snoozedUntil, start.add(const Duration(minutes: 15)));
      await pass();
      expect(
        os.pending.values.single.fireAt,
        start.add(const Duration(minutes: 15)),
      );
    });

    test('done completes the reminder and its task', () async {
      final taskId = await h
          .read(tasksRepositoryProvider)
          .save(TaskItem.draft(now: start, title: 'Pay rent'));
      final id = await addReminder(start, link: ItemRef(ItemType.task, taskId));
      const payloadOf = NotificationPayload.decode;
      final payload = payloadOf(
        NotificationPayload(
          key: 'rem:$id:1',
          category: NotificationCategory.task,
          target: ItemRef(ItemType.reminder, id),
        ).encode(),
      )!;
      final ok = await h
          .read(notificationActionsProvider)
          .perform(NotificationButton.done, payload);
      expect(ok, isTrue);
      final r = await h.read(remindersRepositoryProvider).getReminder(id);
      expect(r!.isCompleted, isTrue);
      final t = await h.read(tasksRepositoryProvider).getTask(taskId);
      expect(t!.isCompleted, isTrue);
    });

    test(
      'check in logs one habit check-in; trashed items are ignored',
      () async {
        final habits = h.read(habitsRepositoryProvider);
        final id = await habits.save(
          Habit.draft(
            startDate: DateTime(2026, 10, 1),
            name: 'Water',
            targetCount: 8,
          ),
        );
        final actions = h.read(notificationActionsProvider);
        final ref = ItemRef(ItemType.habit, id);
        expect(await actions.checkIn(ref, day: DateTime(2026, 10, 13)), isTrue);
        final today = await habits
            .watchTodayHabits(DateTime(2026, 10, 13))
            .first;
        expect(today.single.count, 1);

        await h.read(itemsRepositoryProvider).moveToTrash([ref]);
        expect(await actions.checkIn(ref), isFalse);
      },
    );

    test('tap routes: item first, then the payload route', () {
      expect(
        NotificationActions.tapRoute(
          const NotificationPayload(
            key: 'k',
            category: NotificationCategory.reminder,
            target: ItemRef(ItemType.reminder, 'r'),
            open: ItemRef(ItemType.task, 't'),
          ),
        ),
        AppRoutes.open(const ItemRef(ItemType.task, 't')),
      );
      expect(
        NotificationActions.tapRoute(
          const NotificationPayload(
            key: 'k',
            category: NotificationCategory.digest,
            route: AppRoutes.insights,
          ),
        ),
        AppRoutes.insights,
      );
    });
  });

  group('engine', () {
    test('start reconciles; an action tap snoozes and re-plans', () async {
      final id = await addReminder(start.add(const Duration(hours: 1)));
      final engine =
          h.read(notificationEngineProvider) as ReconcilingNotificationEngine;
      await engine.start();
      expect(os.pending, hasLength(1));
      expect(
        await h.read(notificationPermissionProvider.future),
        NotificationPermission.granted,
      );

      final planned = os.pending.values.single;
      os.onTap!(
        NotificationTap(
          payload: planned.payload.encode(),
          actionId: NotificationButton.snooze.id,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await engine.reconcileNow();
      final r = await h.read(remindersRepositoryProvider).getReminder(id);
      expect(r!.snoozedUntil, start.add(const Duration(minutes: 10)));
      expect(
        os.pending.values.single.fireAt,
        start.add(const Duration(minutes: 10)),
      );
    });

    test('changing the digest time reschedules on its own', () async {
      final notifier = h.read(settingsProvider.notifier);
      await notifier.update(
        (s) => s.copyWith(morningBriefing: true, morningBriefingMinutes: 600),
      );
      final engine =
          h.read(notificationEngineProvider) as ReconcilingNotificationEngine;
      await engine.start();
      List<DateTime> digests() => [
        for (final n in os.pending.values)
          if (n.category == NotificationCategory.digest) n.fireAt.toUtc(),
      ];
      expect(digests(), isNotEmpty);
      expect(digests().every((t) => t.hour == 10 && t.minute == 0), isTrue);

      // Settings › Notifications writes the setting; nothing else is called.
      await notifier.update((s) => s.copyWith(morningBriefingMinutes: 7 * 60));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(digests(), isNotEmpty);
      expect(digests().every((t) => t.hour == 7 && t.minute == 0), isTrue);

      await notifier.update((s) => s.copyWith(morningBriefing: false));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(digests(), isEmpty);
    });

    test('a new reminder is picked up from the live stream', () async {
      final engine =
          h.read(notificationEngineProvider) as ReconcilingNotificationEngine;
      await engine.start();
      expect(os.pending, isEmpty);
      await addReminder(start.add(const Duration(hours: 2)));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await engine.reconcileNow();
      expect(os.pending, hasLength(1));
    });
  });

  test('system alerts: inbox always, OS only when its switch is on', () async {
    final refProvider = Provider<Ref>((ref) => ref);
    final ref = h.read(refProvider);
    final posted = await postSystemNotification(
      ref,
      alert: SystemAlert.sync,
      title: 'Backup complete',
    );
    expect(posted, isFalse); // notifySync is off in these settings
    await h
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(notifyVault: true));
    expect(
      await postSystemNotification(
        ref,
        alert: SystemAlert.security,
        title: '1 password found in a breach',
      ),
      isTrue,
    );
    expect(os.shown.single.category, NotificationCategory.security);
    final kinds = (await h.read(inboxRepositoryProvider).watch().first)
        .map((e) => e.kind)
        .toSet();
    expect(kinds, {InboxKind.sync, InboxKind.security});
  });

  test('ledger survives a round-trip through its JSON', () {
    final n = PlannedNotification(
      id: 5,
      key: 'rem:a:1',
      fireAt: DateTime.utc(2026, 10, 13, 10),
      category: NotificationCategory.reminder,
      title: 'Call mom',
      body: 'Due at 10:00 AM',
      payload: const NotificationPayload(
        key: 'rem:a:1',
        category: NotificationCategory.reminder,
      ),
      inboxActions: const [InboxActions.done],
      inboxRef: const ItemRef(ItemType.reminder, 'a'),
      reminderId: 'a',
    );
    final back = SecureLedgerStore.decode(
      SecureLedgerStore.encode([LedgerEntry.of(n)]),
    ).single;
    expect(back.id, 5);
    expect(back.fingerprint, n.fingerprint);
    expect(back.ref, n.inboxRef);
    expect(back.actions, [InboxActions.done]);
    expect(back.fireAt.isAtSameMomentAs(n.fireAt), isTrue);
    expect(SecureLedgerStore.decode('garbage'), isEmpty);
    // A ledger of another install (Keychain survives an iOS reinstall).
    final mine = SecureLedgerStore.encode([LedgerEntry.of(n)], owner: 'a');
    expect(SecureLedgerStore.decode(mine, owner: 'a'), hasLength(1));
    expect(SecureLedgerStore.decode(mine, owner: 'b'), isEmpty);
    expect(NotificationZones.resolve(override: 'Nope/Zone'), same(tz.UTC));
    expect(
      NotificationZones.resolve(override: 'Asia/Dhaka', device: 'UTC').name,
      'Asia/Dhaka',
    );
  });
}
