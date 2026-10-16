/// ============================================================
/// SYSTEM NOTIFICATIONS — immediate security & sync alerts
/// ============================================================
///
/// What: [postSystemNotification] for events that happen *now* rather
/// than at a planned time — vault security alerts (breach found, failed
/// unlock attempts) and backup / sync results. It always writes the inbox
/// entry (screen 27) and, when the master switch, the matching category
/// switch (Settings › Vault security alerts / Backup & sync) and the OS
/// permission allow, shows an OS notification on the "Security & sync"
/// channel.
///
/// Callers pass short, non-secret text: never a password, a PIN, a key or
/// note contents.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/engine/notification_gateway.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Kind of immediate alert.
enum SystemAlert { security, sync }

/// Records [title]/[body] in the inbox and shows it as an OS notification
/// when allowed. [ref] opens an item on tap; otherwise [route] does.
/// Returns true when an OS notification was posted.
Future<bool> postSystemNotification(
  Ref ref, {
  required SystemAlert alert,
  required String title,
  String body = '',
  ItemRef? item,
  String? route,
}) async {
  final category = switch (alert) {
    SystemAlert.security => NotificationCategory.security,
    SystemAlert.sync => NotificationCategory.sync,
  };
  final now = ref.read(clockProvider).now();
  await ref
      .read(inboxRepositoryProvider)
      .add(
        kind: category.inboxKind,
        title: title,
        body: body,
        ref: item,
        at: now,
      );
  final s = ref.read(settingsProvider);
  final enabled =
      s.notificationsEnabled &&
      switch (alert) {
        SystemAlert.security => s.notifyVault,
        SystemAlert.sync => s.notifySync,
      };
  if (!enabled) return false;
  try {
    final permission = await ref.read(notificationPermissionProvider.future);
    if (permission != NotificationPermission.granted) return false;
    final key = '${category.name}:${now.millisecondsSinceEpoch}';
    await ref
        .read(notificationGatewayProvider)
        .showNow(
          PlannedNotification(
            id: notificationIdForKey(key),
            key: key,
            fireAt: now,
            category: category,
            title: title,
            body: body,
            payload: NotificationPayload(
              key: key,
              category: category,
              open: item,
              route: route,
            ),
          ),
          DeliveryOptions(lockScreen: s.lockScreenVisibility),
        );
    return true;
  } catch (e) {
    AppLogger.w('System notification failed: $e');
    return false;
  }
}
