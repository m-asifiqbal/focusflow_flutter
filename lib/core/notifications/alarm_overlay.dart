/// ============================================================
/// ALARM OVER APPS — "Display over other apps" for the alarm screen (Android)
/// ============================================================
///
/// Why: a ringing alarm must come to the front by itself, like the clock app.
/// A full-screen intent only does that on the lock screen; with the phone in
/// use Android shows a heads-up and the alarm screen waits for a tap. The one
/// permission that lets an app open a screen from the background is "Display
/// over other apps" (SYSTEM_ALERT_WINDOW). It cannot be granted by a dialog:
/// the user flips it on the system page this opens, so it is opt-in, offered
/// from the reminder editor (alarm style) and Settings › Notifications, and
/// re-read when the app resumes.
///
/// Not Android → always "allowed" (nothing to ask).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The OS side (fake in tests).
abstract class AlarmOverlay {
  /// Whether the alarm screen may open over other apps.
  Future<bool> isAllowed();

  /// Opens the system page for the permission.
  Future<void> request();
}

class PlatformAlarmOverlay implements AlarmOverlay {
  const PlatformAlarmOverlay();

  static const MethodChannel _native = MethodChannel('focusflow/notifications');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isAllowed() async {
    if (!_android) return true;
    try {
      return await _native.invokeMethod<bool>('canShowAlarmOverApps') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<void> request() async {
    if (!_android) return;
    try {
      await _native.invokeMethod<void>('requestAlarmOverApps');
    } on MissingPluginException {
      // Not the app's main engine (tests).
    } on PlatformException {
      // Nothing to open on this device.
    }
  }
}

final alarmOverlayProvider = Provider<AlarmOverlay>(
  (ref) => const PlatformAlarmOverlay(),
);

/// Whether alarms may come to the front on their own (true off Android).
final alarmOverAppsAllowedProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(alarmOverlayProvider).isAllowed();
  } catch (_) {
    return true;
  }
});

/// Opens the system page; the state is re-read when the app resumes.
Future<void> requestAlarmOverApps(Ref ref) async {
  try {
    await ref.read(alarmOverlayProvider).request();
  } catch (_) {
    // The banner stays; nothing to do.
  }
  ref.invalidate(alarmOverAppsAllowedProvider);
}

/// Callable form for widgets.
final alarmOverAppsRequestProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => requestAlarmOverApps(ref),
);
