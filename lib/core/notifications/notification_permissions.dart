/// ============================================================
/// NOTIFICATION PERMISSIONS — cross-feature contract
/// ============================================================
///
/// Implemented by the notification engine (core/notifications). Read by
/// Settings › Notifications (31), the Reminders list banner (12) and the
/// reminder editor (13).
///
/// The OS cannot always tell "never asked" from "refused", so a
/// preference flag records that the prompt was shown once.
///
/// Android 12+ also gates *exact* alarms (Settings › Alarms & reminders)
/// and Android 14+ full-screen intents (alarm-style reminders). Both are
/// separate from the notification permission, so each has its own state
/// ([exactAlarmPermissionProvider], [fullScreenAlarmsAllowedProvider]) and
/// an explicit request that opens the system page. The engine invalidates
/// all three on resume (the user comes back from system settings).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

enum NotificationPermission { granted, denied, notDetermined }

/// Android 12+ "Alarms & reminders" access. [notApplicable] on iOS and
/// where the platform has no such switch.
enum ExactAlarmPermission { granted, denied, notApplicable }

/// Current OS permission state; invalidate it after asking / on resume.
final notificationPermissionProvider = FutureProvider<NotificationPermission>((
  ref,
) async {
  final asked =
      ref
          .watch(sharedPreferencesProvider)
          .getBool(notificationPermissionAskedKey) ??
      false;
  try {
    return await ref
        .watch(notificationGatewayProvider)
        .permission(askedBefore: asked);
  } catch (_) {
    return NotificationPermission.notDetermined;
  }
});

/// Asks the OS (Android 13+ / iOS); returns the new state. Also requests
/// exact-alarm permission on Android 12+ when [exactAlarms] is true.
/// After a refusal the OS no longer prompts, so this opens the app's
/// notification settings instead.
Future<NotificationPermission> requestNotificationPermission(
  Ref ref, {
  bool exactAlarms = true,
}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final gateway = ref.read(notificationGatewayProvider);
  NotificationPermission result;
  try {
    final current = await ref.read(notificationPermissionProvider.future);
    if (current == NotificationPermission.denied) {
      await gateway.openSettings();
      result = current;
    } else {
      result = await gateway.requestPermission(exactAlarms: exactAlarms);
    }
  } catch (_) {
    result = NotificationPermission.notDetermined;
  }
  await prefs.setBool(notificationPermissionAskedKey, true);
  ref.invalidate(notificationPermissionProvider);
  return result;
}

/// Whether reminders can fire at their exact minute (Android 12+). The
/// reminder editor and Settings show "Reminders may be late — Allow exact
/// alarms" while this is [ExactAlarmPermission.denied].
final exactAlarmPermissionProvider = FutureProvider<ExactAlarmPermission>((
  ref,
) async {
  try {
    return await ref.watch(notificationGatewayProvider).exactAlarmPermission();
  } catch (_) {
    return ExactAlarmPermission.notApplicable;
  }
});

/// Opens the system "Alarms & reminders" page (Android 12+); returns the
/// state afterwards. The engine re-plans on resume, so a grant switches
/// every pending notification to exact timing (and a revoke to inexact).
Future<ExactAlarmPermission> requestExactAlarmPermission(Ref ref) async {
  ExactAlarmPermission result;
  try {
    result = await ref.read(notificationGatewayProvider).requestExactAlarms();
  } catch (_) {
    result = ExactAlarmPermission.notApplicable;
  }
  ref.invalidate(exactAlarmPermissionProvider);
  return result;
}

/// Whether alarm-style reminders may show full screen (Android 14+
/// "Full screen notifications"; always true elsewhere). Without it they
/// still alert as a high-priority heads-up notification.
final fullScreenAlarmsAllowedProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref
        .watch(notificationGatewayProvider)
        .canUseFullScreenIntent();
  } catch (_) {
    return true;
  }
});

/// Asks for full-screen intents when they are not allowed (opens the
/// system page on Android 14+). Called when alarm-style is switched on.
Future<bool> requestFullScreenAlarms(Ref ref) async {
  final gateway = ref.read(notificationGatewayProvider);
  var allowed = true;
  try {
    allowed = await gateway.canUseFullScreenIntent();
    if (!allowed) allowed = await gateway.requestFullScreenIntent();
  } catch (_) {
    // Never blocks the editor; the hint stays visible.
  }
  ref.invalidate(fullScreenAlarmsAllowedProvider);
  return allowed;
}
