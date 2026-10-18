/// ============================================================
/// BACKGROUND RECONCILE — one notification pass outside the UI isolate
/// ============================================================
///
/// What: the pass a background isolate runs after writing (notification
/// action) or periodically (the 12 h maintenance task): record fired
/// notifications in the inbox, align task reminders with the planning
/// zone, refill the rolling 60-request window and ping the running app
/// ([NotificationRefreshPort]) so its live queries re-read.
///
/// Why: iOS keeps at most 64 pending requests and the engine only rolls
/// the window forward while the app runs; without a background pass a
/// user who doesn't open the app for two weeks stops getting reminders.
/// Both background entry points share this, so they plan exactly like the
/// app (same planner snapshot, same zone rule).
///
/// The caller provides a container whose [notificationGatewayProvider] is
/// initialized for this isolate.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/engine/refresh_port.dart';
import 'package:focusflow/core/notifications/engine/task_reminder_zones.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Reads a provider (a ProviderContainer's or a Ref's `read`).
typedef NotificationReader = T Function<T>(ProviderListenable<T> provider);

/// Runs one reconcile pass with [read]'s graph. Returns its result.
///
/// [rearm]: the isolate was started fresh by the OS (maintenance task), so
/// alarms the system dropped meanwhile are renewed and lost reminders shown
/// as "Missed" — see `NotificationReconciler.reconcile`. A notification
/// action (Done / Snooze) leaves it off: it changes one item, and the
/// alarms are as healthy as they were a moment ago.
Future<ReconcileResult> reconcileInBackground(
  NotificationReader read, {
  bool rearm = false,
}) async {
  NotificationZones.ensureLoaded();
  final gateway = read(notificationGatewayProvider);
  final settings = read(settingsProvider);
  final location = NotificationZones.resolve(
    override: settings.timeZone,
    device: await gateway.deviceTimeZone(),
  );
  await TaskReminderZones.align(
    read(remindersRepositoryProvider),
    read(sharedPreferencesProvider),
    location,
  );
  final input = await read(
    plannerSnapshotLoaderProvider,
  ).load(settings, location);
  final permission = await read(notificationPermissionProvider.future);
  final result = await read(notificationReconcilerProvider).reconcile(
    input,
    allowed: permission == NotificationPermission.granted,
    location: location,
    rearm: rearm,
  );
  NotificationRefreshPort.ping();
  return result;
}
