/// ============================================================
/// NOTIFICATION PROVIDERS — wiring of the engine's building blocks
/// ============================================================
///
/// The gateway (OS port), ledger store, planner snapshot loader, action
/// handler and reconciler, each as a plain [Provider] so the app, the
/// background isolate (its own ProviderContainer) and tests (fake gateway,
/// memory ledger) share one graph.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/engine/local_notifications_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_actions.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/engine/notification_ledger.dart';
import 'package:focusflow/core/notifications/engine/notification_reconciler.dart';
import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The OS port (override with a fake in tests).
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationsGateway(),
);

/// What is scheduled with the OS (Keychain / Keystore).
final notificationLedgerStoreProvider = Provider<LedgerStore>(
  (ref) => SecureLedgerStore(
    ref.watch(secureStoreProvider),
    owner: ref.watch(deviceIdProvider),
  ),
);

final plannerSnapshotLoaderProvider = Provider<PlannerSnapshotLoader>(
  (ref) => PlannerSnapshotLoader(
    reminders: ref.watch(remindersRepositoryProvider),
    tasks: ref.watch(tasksRepositoryProvider),
    habits: ref.watch(habitsRepositoryProvider),
    clock: ref.watch(clockProvider),
    limits: PlannerLimits.current,
  ),
);

/// Done / Snooze / Check in — shared by OS actions and the inbox buttons.
final notificationActionsProvider = Provider<NotificationActions>(
  (ref) => NotificationActions(
    reminders: ref.watch(remindersRepositoryProvider),
    tasks: ref.watch(tasksRepositoryProvider),
    habits: ref.watch(habitsRepositoryProvider),
    clock: ref.watch(clockProvider),
    defaultSnoozeMinutes: ref.watch(
      settingsProvider.select((s) => s.defaultSnoozeMinutes),
    ),
  ),
);

final notificationReconcilerProvider = Provider<NotificationReconciler>(
  (ref) => NotificationReconciler(
    gateway: ref.watch(notificationGatewayProvider),
    ledger: ref.watch(notificationLedgerStoreProvider),
    inbox: ref.watch(inboxRepositoryProvider),
    reminders: ref.watch(remindersRepositoryProvider),
  ),
);

/// Preference flag: the OS prompt was shown once (tells "never asked"
/// apart from "denied" where the OS can't).
const String notificationPermissionAskedKey = 'notifications.permission_asked';
