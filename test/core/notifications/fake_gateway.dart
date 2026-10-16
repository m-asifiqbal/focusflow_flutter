/// In-memory [NotificationGateway] for engine tests: records what is
/// scheduled, cancelled and the badge; permission is configurable.
library;

import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeGateway implements NotificationGateway {
  final Map<int, PlannedNotification> pending = {};
  final List<int> cancelled = [];
  int scheduleCalls = 0;
  int? badge;
  NotificationPermission state = NotificationPermission.granted;
  NotificationTap? launch;
  void Function(NotificationTap)? onTap;
  String? zone = 'UTC';

  /// The OS delivers everything due by [now] (removes it from pending).
  void deliverUntil(DateTime now) =>
      pending.removeWhere((_, n) => !n.fireAt.isAfter(now));

  @override
  Future<bool> initialize({
    required void Function(NotificationTap) onTap,
  }) async {
    this.onTap = onTap;
    return true;
  }

  @override
  Future<NotificationTap?> launchTap() async => launch;

  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();

  @override
  Future<void> schedule(
    PlannedNotification n,
    tz.Location location,
    DeliveryOptions options,
  ) async {
    scheduleCalls++;
    pending[n.id] = n;
    this.options[n.id] = options;
  }

  final List<PlannedNotification> shown = [];

  @override
  Future<void> showNow(PlannedNotification n, DeliveryOptions options) async =>
      shown.add(n);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> setBadge(int count) async => badge = count;

  @override
  Future<NotificationPermission> permission({
    required bool askedBefore,
  }) async => state;

  @override
  Future<NotificationPermission> requestPermission({
    bool exactAlarms = true,
  }) async => state = NotificationPermission.granted;

  @override
  Future<void> openSettings() async {}

  ExactAlarmPermission exact = ExactAlarmPermission.granted;
  int exactRequests = 0;
  bool fullScreen = true;
  int fullScreenRequests = 0;

  /// Options of the last [schedule] call per id.
  final Map<int, DeliveryOptions> options = {};

  @override
  Future<ExactAlarmPermission> exactAlarmPermission() async => exact;

  @override
  Future<ExactAlarmPermission> requestExactAlarms() async {
    exactRequests++;
    return exact;
  }

  @override
  Future<bool> canUseFullScreenIntent() async => fullScreen;

  @override
  Future<bool> requestFullScreenIntent() async {
    fullScreenRequests++;
    return fullScreen;
  }

  @override
  Future<String?> deviceTimeZone() async => zone;

  int retired = 0;

  @override
  Future<void> retireLegacyChannels() async => retired++;
}

/// In-memory battery-optimisation state ([BackgroundDelivery]).
class FakeBackgroundDelivery implements BackgroundDelivery {
  FakeBackgroundDelivery({this.unrestricted, this.grantOnRequest = true});

  bool? unrestricted;
  bool grantOnRequest;
  int requests = 0;

  @override
  Future<bool?> isUnrestricted() async => unrestricted;

  @override
  Future<bool?> requestUnrestricted() async {
    requests++;
    if (unrestricted != null) unrestricted = grantOnRequest;
    return unrestricted;
  }
}
