/// Test overrides that isolate the tasks / reminders screen tests from the
/// real notification engine and the OS gateway.
///
/// Why: these tests cover the screens and their writes only; the engine
/// (wake timers, reconciliation) is covered by test/core/notifications.
/// Running the real engine here made teardown hang while that code was
/// being edited.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';

import '../../core/notifications/fake_gateway.dart';

/// An engine that never schedules anything.
class NoopNotificationEngine implements NotificationEngine {
  const NoopNotificationEngine();

  @override
  Future<void> start() async {}

  @override
  Future<void> onResume() async {}
}

/// Overrides [notificationEngineProvider] with a no-op engine and
/// [notificationGatewayProvider] with an in-memory [FakeGateway] whose
/// permission is [permission] (or the given [gateway]); battery
/// optimisation is "not applicable" unless [background] says otherwise.
List<Override> isolatedNotifications({
  NotificationPermission permission = NotificationPermission.granted,
  FakeGateway? gateway,
  FakeBackgroundDelivery? background,
}) => [
  notificationGatewayProvider.overrideWithValue(
    gateway ?? (FakeGateway()..state = permission),
  ),
  notificationEngineProvider.overrideWithValue(const NoopNotificationEngine()),
  backgroundDeliveryProvider.overrideWithValue(
    background ?? FakeBackgroundDelivery(),
  ),
];
