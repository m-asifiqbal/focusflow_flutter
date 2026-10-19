/// The alarm guard's Dart side: each notification pass reports the vital
/// schedule (reminders, alarms, task alerts — not digests) to the native
/// guard, the Settings switch reaches it without a re-plan, the setting
/// survives JSON, and the channel call carries what native expects.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/alarm_guard.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/test_container.dart';
import 'fake_alarm_guard.dart';
import 'fake_gateway.dart';
import 'planner_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 10, 13, 9);
  late TestHarness h;
  late FakeGateway os;
  late FakeAlarmGuard guard;

  Future<void> boot({AppSettings? settings}) async {
    os = FakeGateway();
    guard = FakeAlarmGuard();
    h = await TestHarness.create(
      now: start,
      prefs: {
        SettingsController.prefsKey: jsonEncode(
          (settings ?? quiet.copyWith(notifyReminders: true)).toJson(),
        ),
      },
      overrides: [
        notificationGatewayProvider.overrideWithValue(os),
        notificationSettleProvider.overrideWithValue(Duration.zero),
        notificationLedgerStoreProvider.overrideWithValue(MemoryLedgerStore()),
        alarmGuardProvider.overrideWithValue(guard),
      ],
    );
    addTearDown(h.dispose);
  }

  Future<String> addReminder(Duration after, {String title = 'Call mom'}) => h
      .read(remindersRepositoryProvider)
      .save(Reminder.draft(triggerAt: start.add(after), title: title));

  Future<ReconcileResult> pass() async {
    final s = h.read(settingsProvider);
    final input = await h.read(plannerSnapshotLoaderProvider).load(s, tz.UTC);
    return h
        .read(notificationReconcilerProvider)
        .reconcile(input, allowed: true, location: tz.UTC);
  }

  ReconcilingNotificationEngine engine() =>
      h.read(notificationEngineProvider) as ReconcilingNotificationEngine;

  Future<void> idle() =>
      Future<void>.delayed(const Duration(milliseconds: 900));

  group('what a pass reports', () {
    test('counts reminders, with the soonest and the last due time', () async {
      await boot();
      await addReminder(const Duration(hours: 3), title: 'Later');
      await addReminder(const Duration(hours: 1), title: 'Sooner');

      final r = await pass();

      expect(r.vitalPending, 2);
      expect(r.nextVitalAt, start.add(const Duration(hours: 1)));
      expect(r.lastVitalAt, start.add(const Duration(hours: 3)));
    });

    test('a digest is not vital: nothing to guard for it', () async {
      await boot(settings: quiet.copyWith(morningBriefing: true));

      final r = await pass();

      expect(r.pending, greaterThan(0), reason: 'the briefing is scheduled');
      expect(r.vitalPending, 0);
      expect(r.nextVitalAt, isNull);
      expect(r.lastVitalAt, isNull);
    });

    test('nothing scheduled: nothing pending', () async {
      await boot();
      final r = await pass();
      expect(r.vitalPending, 0);
      expect(r.nextVitalAt, isNull);
    });
  });

  group('the engine tells the guard', () {
    test('after the first pass, with the user setting', () async {
      await boot();
      await addReminder(const Duration(hours: 2));

      await engine().start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final report = guard.last!;
      expect(report.enabled, isTrue);
      expect(report.pending, 1);
      expect(report.nextAt, start.add(const Duration(hours: 2)));
      expect(report.lastAt, start.add(const Duration(hours: 2)));
    });

    test('switching it off reaches the guard without a re-plan', () async {
      await boot();
      await addReminder(const Duration(hours: 2));
      await engine().start();
      await idle();
      final planned = os.scheduleCalls;
      final reports = guard.reports.length;

      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(keepAlarmsAlive: false));
      await idle();

      expect(guard.reports.length, reports + 1);
      expect(guard.last!.enabled, isFalse);
      expect(guard.last!.pending, 1, reason: 'the schedule is unchanged');
      expect(os.scheduleCalls, planned, reason: 'nothing was re-planned');
    });

    test('an emptied schedule is reported as nothing pending', () async {
      await boot();
      final id = await addReminder(const Duration(hours: 2));
      await engine().start();
      await idle();
      expect(guard.last!.pending, 1);

      await h.read(remindersRepositoryProvider).setEnabled(id, false);
      await engine().reconcileNow();

      expect(guard.last!.pending, 0);
      expect(guard.last!.nextAt, isNull);
    });
  });

  group('the setting', () {
    test('is on by default and survives JSON', () {
      expect(const AppSettings().keepAlarmsAlive, isTrue);
      final off = const AppSettings().copyWith(keepAlarmsAlive: false);
      expect(AppSettings.fromJson(off.toJson()).keepAlarmsAlive, isFalse);
      expect(
        AppSettings.fromJson({'keepAlarmsAlive': 'nope'}).keepAlarmsAlive,
        isTrue,
        reason: 'garbage falls back to the default',
      );
      expect(AppSettings.fromJson(const {}).keepAlarmsAlive, isTrue);
    });
  });

  group('PlatformAlarmGuard', () {
    const channel = MethodChannel('focusflow/notifications');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'alarmGuardRunning' ? true : null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sync sends epoch milliseconds (0 = none)', () async {
      final at = DateTime.utc(2026, 10, 13, 12);
      await const PlatformAlarmGuard().sync(
        enabled: true,
        pending: 3,
        nextAt: at,
        lastAt: at.add(const Duration(days: 2)),
      );
      await const PlatformAlarmGuard().sync(enabled: false, pending: 0);

      expect(calls.map((c) => c.method), everyElement('syncAlarmGuard'));
      expect(calls.first.arguments, {
        'enabled': true,
        'pending': 3,
        'nextAt': at.millisecondsSinceEpoch,
        'lastAt': at.add(const Duration(days: 2)).millisecondsSinceEpoch,
      });
      expect(calls.last.arguments, {
        'enabled': false,
        'pending': 0,
        'nextAt': 0,
        'lastAt': 0,
      });
    });

    test('reads whether the service runs', () async {
      expect(await const PlatformAlarmGuard().isRunning(), isTrue);
    });

    test('a native failure never throws into the engine', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'refused');
          });
      await const PlatformAlarmGuard().sync(enabled: true, pending: 1);
      expect(await const PlatformAlarmGuard().isRunning(), isNull);
    });
  });
}
