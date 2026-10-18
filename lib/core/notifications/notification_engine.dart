/// ============================================================
/// NOTIFICATION ENGINE — cross-feature contract (implemented in
/// core/notifications/engine/reconciling_engine.dart)
/// ============================================================
///
/// Owns flutter_local_notifications: channels, permission, scheduling and
/// action handling. It *reconciles* rather than being called per edit: it
/// watches the repositories (reminders, task due alerts, habit reminder
/// times) and the notification settings, and keeps the OS schedule in sync,
/// so no editor needs to remember to schedule or cancel anything.
/// Every fired notification is also written to the inbox (screen 27).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/engine/reconciling_engine.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';

abstract class NotificationEngine {
  /// Called once after the first frame: init plugin, time zones, start
  /// watching repositories, handle the launch notification (deep link).
  Future<void> start();

  /// App returned to the foreground: refresh permission, re-reconcile.
  Future<void> onResume();
}

/// The app's engine (a [ReconcilingNotificationEngine]).
final notificationEngineProvider = Provider<NotificationEngine>((ref) {
  final engine = ReconcilingNotificationEngine(
    ref,
    settle: ref.watch(notificationSettleProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Hands every write made so far to the OS now (no debounce) and waits
/// for it — call after saving a reminder / a task with "Remind me", so the
/// notification is scheduled even if the app is closed right away. A
/// no-op for other engines (tests) and when notifications are unavailable;
/// never throws.
Future<void> flushNotifications(Ref ref) async {
  try {
    final engine = ref.read(notificationEngineProvider);
    if (engine is ReconcilingNotificationEngine) await engine.flush();
  } catch (_) {
    // Best effort: the debounced pass and the background flush follow.
  }
}
