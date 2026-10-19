/// Launch-time renewal of alarms: a launch no longer re-sends every planned
/// request (each Android schedule call re-writes the plugin's whole list on
/// the platform thread, N × N work that made the app stutter after opening);
/// it asks the OS which alarms are still armed and renews only the others.
/// After a force-stop nothing is armed, so nothing is lost; when the OS cannot
/// say, or a full renewal is due, everything is renewed as before.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/engine/rearm_policy.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/test_container.dart';
import 'fake_gateway.dart';
import 'planner_test_data.dart';

void main() {
  final start = DateTime(2026, 10, 13, 9);
  late TestHarness h;
  late FakeGateway os;

  Future<void> boot({Map<String, Object> prefs = const {}}) async {
    os = FakeGateway();
    h = await TestHarness.create(
      now: start,
      prefs: {
        SettingsController.prefsKey: jsonEncode(
          quiet.copyWith(notifyReminders: true).toJson(),
        ),
        ...prefs,
      },
      overrides: [
        notificationGatewayProvider.overrideWithValue(os),
        notificationSettleProvider.overrideWithValue(Duration.zero),
        notificationLedgerStoreProvider.overrideWithValue(MemoryLedgerStore()),
      ],
    );
    addTearDown(h.dispose);
  }

  Future<void> addReminders(int n) async {
    for (var i = 0; i < n; i++) {
      await h
          .read(remindersRepositoryProvider)
          .save(
            Reminder.draft(
              triggerAt: start.add(Duration(hours: 1 + i)),
              title: 'Reminder $i',
            ),
          );
    }
  }

  Future<void> pass({bool rearm = false, bool trustArmed = false}) async {
    final s = h.read(settingsProvider);
    final input = await h.read(plannerSnapshotLoaderProvider).load(s, tz.UTC);
    await h
        .read(notificationReconcilerProvider)
        .reconcile(
          input,
          allowed: true,
          location: tz.UTC,
          rearm: rearm,
          trustArmed: trustArmed,
        );
  }

  group('reconciler', () {
    test('renews only the alarms the OS no longer holds', () async {
      await boot();
      await addReminders(4);
      await pass();
      expect(os.scheduleCalls, 4);
      final ids = os.pending.keys.toList();

      os.armed = {ids[0], ids[2]}; // two of four were dropped
      await pass(rearm: true, trustArmed: true);

      expect(os.scheduleCalls, 4 + 2);
      expect(os.armedAsked.single, ids.toSet());
    });

    test('everything armed: a launch sends nothing', () async {
      await boot();
      await addReminders(3);
      await pass();
      os.armed = os.pending.keys.toSet();

      await pass(rearm: true, trustArmed: true);

      expect(os.scheduleCalls, 3);
    });

    test('after a force-stop none is armed: all are renewed', () async {
      await boot();
      await addReminders(3);
      await pass();
      os.armed = <int>{};

      await pass(rearm: true, trustArmed: true);

      expect(os.scheduleCalls, 3 + 3);
    });

    test('an OS that cannot tell gets everything renewed', () async {
      await boot();
      await addReminders(3);
      await pass();
      os.armed = null;

      await pass(rearm: true, trustArmed: true);

      expect(os.scheduleCalls, 3 + 3);
    });

    test('without trust everything is renewed and nobody is asked', () async {
      await boot();
      await addReminders(3);
      await pass();
      os.armed = os.pending.keys.toSet();

      await pass(rearm: true);

      expect(os.scheduleCalls, 3 + 3);
      expect(os.armedAsked, isEmpty);
    });

    test('an ordinary pass never asks', () async {
      await boot();
      await addReminders(2);
      await pass();
      os.armed = os.pending.keys.toSet();
      await pass(trustArmed: true); // trust means nothing without rearm
      expect(os.armedAsked, isEmpty);
      expect(os.scheduleCalls, 2);
    });

    test('a changed request is re-sent even when its alarm is armed', () async {
      await boot();
      await addReminders(2);
      await pass();
      final reminders = h.read(remindersRepositoryProvider);
      final id = (await reminders.watchSchedulable().first).first.id;
      await reminders.reschedule(id, start.add(const Duration(days: 2)));
      os.armed = os.pending.keys.toSet();

      await pass(rearm: true, trustArmed: true);

      expect(os.scheduleCalls, 2 + 1, reason: 'only the edited one');
    });
  });

  group('the launch pass of the engine', () {
    ReconcilingNotificationEngine engine() =>
        h.read(notificationEngineProvider) as ReconcilingNotificationEngine;

    test('the very first one renews everything and records it', () async {
      await boot();
      await addReminders(3);
      await pass(); // what the previous session left with the OS
      os.armed = os.pending.keys.toSet();
      final before = os.scheduleCalls;

      await engine().start();

      expect(os.armedAsked, isEmpty, reason: 'no stamp: a full renewal');
      expect(os.scheduleCalls, before + 3);
      expect(
        h.read(sharedPreferencesProvider).getInt(RearmPolicy.lastFullKey),
        start.millisecondsSinceEpoch,
      );
    });

    test('a launch soon after trusts the OS and sends nothing', () async {
      await boot(
        prefs: {
          RearmPolicy.lastFullKey: start
              .subtract(const Duration(hours: 3))
              .millisecondsSinceEpoch,
        },
      );
      await addReminders(3);
      await pass();
      os.armed = os.pending.keys.toSet();
      final before = os.scheduleCalls;

      await engine().start();

      expect(os.armedAsked, hasLength(1));
      expect(os.scheduleCalls, before, reason: 'all alarms were armed');
      expect(
        h.read(sharedPreferencesProvider).getInt(RearmPolicy.lastFullKey),
        start.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
        reason: 'a verified launch is not a full renewal',
      );
    });

    test('a launch after a force-stop renews what was dropped', () async {
      await boot(
        prefs: {
          RearmPolicy.lastFullKey: start
              .subtract(const Duration(hours: 3))
              .millisecondsSinceEpoch,
        },
      );
      await addReminders(3);
      await pass();
      os.armed = <int>{};
      final before = os.scheduleCalls;

      await engine().start();

      expect(os.scheduleCalls, before + 3);
    });
  });

  group('RearmPolicy', () {
    final now = DateTime(2026, 10, 13, 12);

    Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    test('a full renewal is due when there has never been one', () async {
      expect(RearmPolicy.fullDue(await prefsWith({}), now), isTrue);
    });

    test('and again once the last one is a day old', () async {
      Future<bool> due(Duration ago) async => RearmPolicy.fullDue(
        await prefsWith({
          RearmPolicy.lastFullKey: now.subtract(ago).millisecondsSinceEpoch,
        }),
        now,
      );
      expect(await due(const Duration(hours: 1)), isFalse);
      expect(await due(const Duration(hours: 23)), isFalse);
      expect(await due(const Duration(hours: 24)), isTrue);
      expect(await due(const Duration(days: 9)), isTrue);
    });

    test('a clock that went back renews too', () async {
      final prefs = await prefsWith({
        RearmPolicy.lastFullKey: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });
      expect(RearmPolicy.fullDue(prefs, now), isTrue);
    });
  });
}
