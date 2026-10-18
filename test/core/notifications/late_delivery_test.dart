/// Reconciler vs. a notification the OS has not shown yet at its fire time
/// (Android inexact alarms fire minutes late; the engine wakes 2 s after
/// the fire time): the pending request must be left alone — never
/// cancelled — and recorded in the inbox only once the OS delivered it.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
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

  setUp(() async {
    os = FakeGateway();
    ledger = MemoryLedgerStore();
    h = await TestHarness.create(
      now: start,
      prefs: {
        SettingsController.prefsKey: jsonEncode(
          quiet.copyWith(notifyReminders: true).toJson(),
        ),
      },
      overrides: [
        notificationGatewayProvider.overrideWithValue(os),
        notificationSettleProvider.overrideWithValue(Duration.zero),
        notificationLedgerStoreProvider.overrideWithValue(ledger),
      ],
    );
  });

  tearDown(() => h.dispose());

  Future<void> pass() async {
    final s = h.read(settingsProvider);
    final input = await h.read(plannerSnapshotLoaderProvider).load(s, tz.UTC);
    await h
        .read(notificationReconcilerProvider)
        .reconcile(input, allowed: true, location: tz.UTC);
  }

  test('a due request the OS still holds is not cancelled', () async {
    final at = start.add(const Duration(minutes: 30));
    await h
        .read(remindersRepositoryProvider)
        .save(Reminder.draft(triggerAt: at, title: 'Call mom'));
    await pass();
    final id = os.pending.keys.single;

    // Engine wake-up 2 s after the fire time; the OS has not shown it yet.
    h.clock.set(at.add(const Duration(seconds: 2)));
    await pass();
    expect(os.cancelled, isNot(contains(id)), reason: 'dropped before shown');
    expect(os.pending.keys, contains(id));
    expect(ledger.entries.map((e) => e.id), contains(id));
  });

  test('a request still pending after the grace is not cancelled', () async {
    final at = start.add(const Duration(minutes: 30));
    await h
        .read(remindersRepositoryProvider)
        .save(Reminder.draft(triggerAt: at, title: 'Call mom'));
    await pass();
    final id = os.pending.keys.single;

    // Inexact alarm: still pending 5 minutes later.
    h.clock.set(at.add(const Duration(minutes: 5)));
    await pass();
    expect(os.cancelled, isNot(contains(id)));
  });

  test('recorded in the inbox only once the OS has shown it', () async {
    final at = start.add(const Duration(minutes: 30));
    await h
        .read(remindersRepositoryProvider)
        .save(Reminder.draft(triggerAt: at, title: 'Call mom'));
    await pass();
    final inbox = h.read(inboxRepositoryProvider);

    h.clock.set(at.add(const Duration(minutes: 3)));
    await pass();
    expect(await inbox.watch().first, isEmpty, reason: 'not shown yet');

    os.deliverUntil(h.clock.now());
    await pass();
    await pass(); // a second pass must not record it again
    final entries = await inbox.watch().first;
    expect(entries.map((e) => e.title), ['Call mom']);
    expect(ledger.entries, isEmpty);
  });

  test('a due request is cancelled once its reminder is done', () async {
    final at = start.add(const Duration(minutes: 30));
    final repo = h.read(remindersRepositoryProvider);
    final id = await repo.save(Reminder.draft(triggerAt: at, title: 'Pay'));
    await pass();
    final osId = os.pending.keys.single;

    h.clock.set(at.add(const Duration(minutes: 1)));
    await repo.setEnabled(id, false);
    await pass();
    expect(os.cancelled, contains(osId));
    expect(ledger.entries, isEmpty);
    expect(await h.read(inboxRepositoryProvider).watch().first, isEmpty);
  });

  test(
    'a request stuck past the give-up time is recorded and cancelled',
    () async {
      final at = start.add(const Duration(minutes: 30));
      await h
          .read(remindersRepositoryProvider)
          .save(Reminder.draft(triggerAt: at, title: 'Call mom'));
      await pass();
      final id = os.pending.keys.single;

      h.clock.set(
        at.add(NotificationReconciler.giveUpAfter + const Duration(minutes: 1)),
      );
      await pass();
      expect(os.cancelled, contains(id));
      final entries = await h.read(inboxRepositoryProvider).watch().first;
      expect(entries.map((e) => e.title), ['Call mom']);
    },
  );
}
