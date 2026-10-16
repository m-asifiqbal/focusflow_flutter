/// ============================================================
/// NOTIFICATION GATEWAY — the engine's port to the OS
/// ============================================================
///
/// What: everything the engine needs from the platform (schedule, cancel,
/// list pending ids, badge, permission, launch details, device zone) behind
/// one small interface.
///
/// Why: the reconciler and the action handler are plain Dart over this
/// port, so they are unit-tested with an in-memory fake; the only code that
/// touches flutter_local_notifications is LocalNotificationsGateway.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:timezone/timezone.dart' as tz;

/// A tap on a notification, or on one of its action buttons.
@immutable
class NotificationTap {
  const NotificationTap({this.payload, this.actionId});

  /// The raw [NotificationPayload] string.
  final String? payload;

  /// [NotificationButton.id] of the tapped button; null for a body tap.
  final String? actionId;

  NotificationButton? get button => NotificationButton.fromId(actionId);

  @override
  String toString() => 'NotificationTap(${actionId ?? 'open'})';
}

/// How one notification is presented, beyond its planned content.
@immutable
class DeliveryOptions {
  const DeliveryOptions({
    this.lockScreen = LockScreenVisibility.titleOnly,
    this.exact = true,
  });

  /// Settings › Show on lock screen.
  final LockScreenVisibility lockScreen;

  /// Exact timing (Android exact alarms). The reconciler sets it from
  /// [NotificationGateway.exactAlarmPermission] on every pass.
  final bool exact;

  /// Part of the ledger fingerprint: options that change the OS copy or
  /// how it is scheduled. Exact vs inexact is included so that granting or
  /// revoking "Alarms & reminders" re-schedules everything (Android drops
  /// an app's exact alarms on revoke while the plugin still lists them).
  /// Exact adds nothing, so ledgers written before this flag stay valid.
  String get variant => 'l${lockScreen.index}${exact ? '' : 'i'}';
}

abstract class NotificationGateway {
  /// Creates channels / categories and installs the tap handler. Returns
  /// false when the platform has no notification support.
  Future<bool> initialize({required void Function(NotificationTap) onTap});

  /// The tap that launched the app from a terminated state, if any.
  Future<NotificationTap?> launchTap();

  /// Ids the OS currently has pending (scheduled, not yet delivered).
  Future<Set<int>> pendingIds();

  /// Schedules (or replaces, same id) one notification at its fire time.
  Future<void> schedule(
    PlannedNotification n,
    tz.Location location,
    DeliveryOptions options,
  );

  /// Shows [n] right away (security / sync events), ignoring its fireAt.
  Future<void> showNow(PlannedNotification n, DeliveryOptions options);

  Future<void> cancel(int id);

  /// Sets the app icon badge now (0 clears it). No-op where unsupported.
  Future<void> setBadge(int count);

  /// Current OS permission (no prompt). `askedBefore` tells a never-asked
  /// state apart from a refusal on platforms that can't report it.
  Future<NotificationPermission> permission({required bool askedBefore});

  /// Shows the OS prompt (and the Android 12+ exact-alarm screen when
  /// [exactAlarms]); returns the resulting state.
  Future<NotificationPermission> requestPermission({bool exactAlarms = true});

  /// Opens the app's notification settings page (after a refusal).
  Future<void> openSettings();

  /// Whether exact alarms are allowed (fresh from the OS, no prompt).
  Future<ExactAlarmPermission> exactAlarmPermission();

  /// Opens the system "Alarms & reminders" page when exact alarms are not
  /// allowed; returns the state afterwards.
  Future<ExactAlarmPermission> requestExactAlarms();

  /// Whether full-screen intents are allowed (Android 14+; true elsewhere).
  Future<bool> canUseFullScreenIntent();

  /// Opens the system page for full-screen intents (Android 14+); returns
  /// whether they are allowed afterwards.
  Future<bool> requestFullScreenIntent();

  /// IANA name of the device zone (null when unknown).
  Future<String?> deviceTimeZone();
}
