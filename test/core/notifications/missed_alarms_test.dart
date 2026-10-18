/// An app that was killed (force-stop, OEM task killer) loses every alarm it
/// had registered, yet the notification plugin's own list of pending
/// requests is stored data and keeps naming them. These tests pin down what
/// the reconciler does about it on the first pass of a fresh process:
/// renew every alarm, and show a lost reminder as "Missed" instead of
/// letting it vanish.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
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

  Future<void> boot({bool quietHours = false}) async {
    os = FakeGateway();
    ledger = MemoryLedgerStore();
    h = await TestHarness.create(
      now: start,
      prefs: {
        SettingsController.prefsKey: jsonEncode(
          quiet
              .copyWith(
                notifyReminders: true,
                notifyTasks: true,
                quietHours: quietHours,
                // Quiet from 10:00 to 11:00; the reminders below fire at
                // 09:30, before it.
                quietStartMinutes: 10 * 60,
                quietEndMinutes: 11 * 60,
              )
              .toJson(),
        ),
      },
      overrides: [
        notificationGatewayProvider.overrideWithValue(os),
        notificationSettleProvider.overrideWithValue(Duration.zero),
        notificationLedgerStoreProvider.overrideWithValue(ledger),
      ],
    );
  }

  setUp(boot);
  tearDown(() => h.dispose());

  Future<ReconcileResult> pass({bool rearm = false}) async {
    final s = h.read(settingsProvider);
    final input = await h.read(plannerSnapshotLoaderProvider).load(s, tz.UTC);
    return h
        .read(notificationReconcilerProvider)
        .reconcile(input, allowed: true, location: tz.UTC, rearm: rearm);
  }

  Future<String> saveReminder(
    DateTime at, {
    String title = 'Pay rent',
    AlertStyle style = AlertStyle.notification,
  }) => h
      .read(remindersRepositoryProvider)
      .save(
        Reminder.draft(triggerAt: at, title: title).copyWith(alertStyle: style),
      );

  final at = start.add(const Duration(minutes: 30));

  test('a normal pass leaves an unchanged alarm alone', () async {
    await saveReminder(at);
    await pass();
    expect(os.scheduleCalls, 1);
    await pass();
    expect(os.scheduleCalls, 1);
  });

  test('a fresh process renews every alarm, even unchanged ones', () async {
    await saveReminder(at);
    await pass();
    expect(os.scheduleCalls, 1);

    final r = await pass(rearm: true);
    expect(os.scheduleCalls, 2, reason: 'the OS may have dropped the alarm');
    expect(r.scheduled, 1);
    expect(os.pending, hasLength(1));
  });

  test('a lost reminder is shown as "Missed" on a fresh process', () async {
    await saveReminder(at, title: 'Pay rent');
    await pass();
    final id = os.pending.keys.single;

    // The alarm never fired (app killed); the plugin still lists it.
    h.clock.set(at.add(const Duration(minutes: 10)));
    final r = await pass(rearm: true);

    expect(r.caughtUp, 1);
    expect(os.cancelled, contains(id), reason: 'the dead alarm is dropped');
    final shown = os.shown.single;
    expect(shown.title, 'Pay rent');
    expect(shown.body, startsWith('Missed · was due at '));
    expect(shown.id, isNot(id), reason: 'own id: never replaced by the next');
    // Recorded once in the inbox, and out of the ledger.
    final inbox = await h.read(inboxRepositoryProvider).watch().first;
    expect(inbox.map((e) => e.title), ['Pay rent']);
    expect(ledger.entries.where((e) => e.id == id), isEmpty);

    // A second fresh-process pass must not show it again.
    await pass(rearm: true);
    expect(os.shown, hasLength(1));
  });

  test('without a fresh process a late request is only waited for', () async {
    await saveReminder(at);
    await pass();
    h.clock.set(at.add(const Duration(minutes: 10)));
    final r = await pass();
    expect(r.caughtUp, 0);
    expect(os.shown, isEmpty);
    expect(os.pending, isNotEmpty);
  });

  test('inside the grace a fresh process still waits for the OS', () async {
    await saveReminder(at);
    await pass();
    h.clock.set(at.add(const Duration(minutes: 1)));
    final r = await pass(rearm: true);
    expect(r.caughtUp, 0);
    expect(os.shown, isEmpty);
  });

  test('a stuck request after the give-up time is caught up, too', () async {
    await saveReminder(at);
    await pass();
    h.clock.set(
      at.add(NotificationReconciler.giveUpAfter + const Duration(minutes: 1)),
    );
    final r = await pass();
    expect(r.caughtUp, 1);
    expect(os.shown.single.body, startsWith('Missed'));
  });

  test('older than the catch-up window it only goes to the inbox', () async {
    await saveReminder(at);
    await pass();
    h.clock.set(
      at.add(NotificationReconciler.catchUpWindow + const Duration(hours: 1)),
    );
    final r = await pass(rearm: true);
    expect(r.caughtUp, 0);
    expect(os.shown, isEmpty);
    final inbox = await h.read(inboxRepositoryProvider).watch().first;
    expect(inbox, hasLength(1));
  });

  test('an alarm-style reminder comes back as a plain heads-up', () async {
    await saveReminder(at, title: 'Wake up', style: AlertStyle.alarm);
    await pass();
    h.clock.set(at.add(const Duration(minutes: 10)));
    await pass(rearm: true);
    final shown = os.shown.single;
    expect(shown.category, NotificationCategory.reminder);
    expect(shown.payload.category, NotificationCategory.reminder);
  });

  test('quiet hours make the catch-up silent', () async {
    await h.dispose();
    await boot(quietHours: true);
    // The planner runs in UTC here: spell the instants in UTC, too.
    h.clock.set(DateTime.utc(2026, 10, 13, 9));
    await saveReminder(DateTime.utc(2026, 10, 13, 9, 30));
    await pass();
    // Found out at 10:05 — inside the quiet window.
    h.clock.set(DateTime.utc(2026, 10, 13, 10, 5));
    await pass(rearm: true);
    expect(os.shown.single.isSilent, isTrue);
  });

  test('a reminder switched off meanwhile is not caught up', () async {
    final id = await saveReminder(at);
    await pass();
    h.clock.set(at.add(const Duration(minutes: 10)));
    await h.read(remindersRepositoryProvider).setEnabled(id, false);
    final r = await pass(rearm: true);
    expect(r.caughtUp, 0);
    expect(os.shown, isEmpty);
  });

  test('a delivered request is never "missed"', () async {
    await saveReminder(at);
    await pass();
    h.clock.set(at.add(const Duration(minutes: 10)));
    os.deliverUntil(h.clock.now()); // the OS really showed it
    final r = await pass(rearm: true);
    expect(r.caughtUp, 0);
    expect(os.shown, isEmpty);
    final inbox = await h.read(inboxRepositoryProvider).watch().first;
    expect(inbox, hasLength(1));
  });
}
