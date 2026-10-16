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

abstract class NotificationEngine {
  /// Called once after the first frame: init plugin, time zones, start
  /// watching repositories, handle the launch notification (deep link).
  Future<void> start();

  /// App returned to the foreground: refresh permission, re-reconcile.
  Future<void> onResume();
}

/// The app's engine (a [ReconcilingNotificationEngine]).
final notificationEngineProvider = Provider<NotificationEngine>((ref) {
  final engine = ReconcilingNotificationEngine(ref);
  ref.onDispose(engine.dispose);
  return engine;
});
