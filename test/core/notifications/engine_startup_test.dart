/// How the engine starts: one pass at launch (not two), a launch-time wait
/// that a notification tap skips, no re-plan for settings that plan nothing
/// (a theme switch), and a re-plan when something that matters changes.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';
import 'fake_gateway.dart';
import 'planner_test_data.dart';

/// Counts reconcile passes: each one asks the OS what is pending once.
class _CountingGateway extends FakeGateway {
  int passes = 0;

  @override
  Future<Set<int>> pendingIds() {
    passes++;
    return super.pendingIds();
  }
}

void main() {
  final start = DateTime(2026, 10, 13, 9);
  late TestHarness h;
  late _CountingGateway os;

  Future<void> boot({Duration settle = Duration.zero}) async {
    os = _CountingGateway();
    h = await TestHarness.create(
      now: start,
      prefs: {
        SettingsController.prefsKey: jsonEncode(
          quiet.copyWith(notifyReminders: true).toJson(),
        ),
      },
      overrides: [
        notificationGatewayProvider.overrideWithValue(os),
        notificationSettleProvider.overrideWithValue(settle),
        notificationLedgerStoreProvider.overrideWithValue(MemoryLedgerStore()),
      ],
    );
    await h
        .read(remindersRepositoryProvider)
        .save(
          Reminder.draft(
            triggerAt: start.add(const Duration(hours: 2)),
            title: 'Call mom',
          ),
        );
  }

  ReconcilingNotificationEngine engine() =>
      h.read(notificationEngineProvider) as ReconcilingNotificationEngine;

  Future<void> idle() =>
      Future<void>.delayed(const Duration(milliseconds: 900));

  tearDown(() => h.dispose());

  test(
    'launch runs one pass, not one more when the permissions load',
    () async {
      await boot();
      await engine().start();
      expect(os.passes, 1);
      expect(os.pending, hasLength(1));

      await idle(); // the debounce window in which a second pass used to run
      expect(os.passes, 1);
    },
  );

  test('a theme or layout change does not re-plan', () async {
    await boot();
    await engine().start();
    await idle();
    final before = os.passes;

    await h
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            accent: AccentColor.blue,
            themeMode: ThemeMode.dark,
            tasksShowCompleted: false,
            localBackupFrequency: s.localBackupFrequency,
          ),
        );
    await h
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(lastSyncAt: () => start));
    await idle();

    expect(os.passes, before);
  });

  test('a setting that shapes the plan does re-plan', () async {
    await boot();
    await engine().start();
    await idle();
    final before = os.passes;

    await h
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(quietHours: true));
    await idle();

    expect(os.passes, before + 1);
  });

  test('the permission changing re-plans', () async {
    await boot();
    await engine().start();
    await idle();
    expect(
      await h.read(notificationPermissionProvider.future),
      NotificationPermission.granted,
    );
    final before = os.passes;

    os.state = NotificationPermission.denied;
    h.container.invalidate(notificationPermissionProvider);
    await h.read(notificationPermissionProvider.future);
    await idle();

    expect(os.passes, before + 1);
    expect(os.pending, isEmpty, reason: 'nothing is scheduled while denied');
  });

  test('the first pass waits for the settle delay', () async {
    await boot(settle: const Duration(milliseconds: 400));
    final started = engine().start();

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(os.passes, 0, reason: 'the first screen gets the CPU first');
    expect(os.pending, isEmpty);

    await started;
    expect(os.passes, 1);
    expect(os.pending, hasLength(1));
  });

  test('a notification tap that launched the app does not wait', () async {
    await boot(settle: const Duration(seconds: 30));
    final planner = NotificationPayload(
      key: 'rem:x:1',
      category: NotificationCategory.reminder,
      route: '/home',
    );
    os.launch = NotificationTap(payload: planner.encode());

    final sw = Stopwatch()..start();
    await engine().start().timeout(const Duration(seconds: 10));

    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    expect(os.passes, greaterThanOrEqualTo(1));
  });
}
