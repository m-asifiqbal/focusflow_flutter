/// ============================================================
/// BACKGROUND HANDLER — notification actions while the app is not running
/// ============================================================
///
/// What: the entry point flutter_local_notifications calls on a background
/// isolate when Done / Snooze / Check in is tapped and the app UI is not
/// in front. It opens the encrypted database with the key from the
/// Keychain / Keystore (SecureStore — never logged), performs the action
/// with the same [NotificationActions] as the app, then runs one reconcile
/// pass so a snoozed reminder is re-scheduled right away.
///
/// The database is opened without quarantine (see [EncryptedDatabase.open]):
/// the app may hold it at the same time, and a busy lock here must never
/// move the user's live database aside.
///
/// This isolate's writes are invisible to the main isolate's Drift
/// streams, so the pass pings the running app (NotificationRefreshPort),
/// which marks its tables updated — and does the same on resume.
/// ============================================================
library;

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/language_service.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/encrypted_database.dart';
import 'package:focusflow/core/notifications/engine/background_reconcile.dart';
import 'package:focusflow/core/notifications/engine/local_notifications_gateway.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference key of the per-install device id (written by bootstrap).
const String _deviceIdKey = 'device_id';

@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
  NotificationResponse response,
) async {
  final button = NotificationButton.fromId(response.actionId);
  final payload = NotificationPayload.decode(response.payload);
  if (button == null || payload == null) return;
  DartPluginRegistrant.ensureInitialized();
  ProviderContainer? container;
  try {
    final key = await SecureStore().read(SecureStore.databaseKey);
    if (key == null || key.length != 64) return;
    final prefs = await SharedPreferences.getInstance();
    await activateLanguageFromPrefs(prefs);
    final gateway = LocalNotificationsGateway();
    await gateway.initializeInBackground();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseKeyProvider.overrideWithValue(key),
        deviceIdProvider.overrideWithValue(
          prefs.getString(_deviceIdKey) ?? 'background',
        ),
        notificationGatewayProvider.overrideWithValue(gateway),
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase(
            EncryptedDatabase.open(cipherKey: key, quarantine: false),
          );
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    await container.read(notificationActionsProvider).perform(button, payload);
    // Re-plan (a snoozed reminder is scheduled right away) and ping the
    // running app, whose Drift streams don't see this isolate's writes.
    await reconcileInBackground(container.read);
  } catch (e, st) {
    AppLogger.e(
      'Background notification action failed',
      error: e,
      stackTrace: st,
    );
  } finally {
    container?.dispose(); // closes the database
  }
}
