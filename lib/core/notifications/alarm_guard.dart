/// ============================================================
/// ALARM GUARD — keeps the app alive for its alarms (Android)
/// ============================================================
///
/// Why: alarms and reminders are `AlarmManager` entries, which Android fires
/// with no app process — until the user swipes the app out of the recent-apps
/// list on a phone whose maker treats that like a force-stop (Xiaomi, Oppo,
/// Vivo, Huawei, some Samsung modes), or a memory cleaner kills the idle
/// process. The guard is the native half that answers that: a foreground
/// service (quiet notification) that keeps the process at foreground
/// priority while something is due, a watchdog alarm that revives it, and a
/// self-repair that re-arms whatever the system dropped. What it cannot beat
/// is a real force-stop; there only the phone's auto-start switch helps (see
/// `background_delivery.dart`). Full description:
/// `android/.../guard/AlarmGuard.kt` and docs/notifications.md.
///
/// What this file does: after every notification pass the engine reports
/// what the OS now holds ([AlarmGuard.sync]); native starts the service when
/// reminders / alarms / task alerts are pending and the user wants it
/// ([AppSettings.keepAlarmsAlive]), and stops it when nothing is left.
/// iOS and other platforms have no such thing: every call is a no-op there.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The OS side (fake in tests).
abstract class AlarmGuard {
  /// Reports the schedule: [enabled] = the user's switch, [pending] = how
  /// many reminders, alarms and task alerts the OS holds, [nextAt] / [lastAt]
  /// = when the soonest / the last of them is due (null when none).
  Future<void> sync({
    required bool enabled,
    required int pending,
    DateTime? nextAt,
    DateTime? lastAt,
  });

  /// Whether the guard's service is running now; null = not applicable.
  Future<bool?> isRunning();
}

class PlatformAlarmGuard implements AlarmGuard {
  const PlatformAlarmGuard();

  static const MethodChannel _native = MethodChannel('focusflow/notifications');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> sync({
    required bool enabled,
    required int pending,
    DateTime? nextAt,
    DateTime? lastAt,
  }) async {
    if (!_android) return;
    try {
      await _native.invokeMethod<void>('syncAlarmGuard', {
        'enabled': enabled,
        'pending': pending,
        'nextAt': nextAt?.millisecondsSinceEpoch ?? 0,
        'lastAt': lastAt?.millisecondsSinceEpoch ?? 0,
      });
    } on PlatformException {
      // The service could not start; the watchdog retries.
    } catch (_) {
      // No native side: not the app's main engine (the background isolate,
      // tests) — the next pass in the app reports it. The guard is best
      // effort and must never break a notification pass.
    }
  }

  @override
  Future<bool?> isRunning() async {
    if (!_android) return null;
    try {
      return await _native.invokeMethod<bool>('alarmGuardRunning');
    } catch (_) {
      return null; // no native side (tests, other engines)
    }
  }
}

final alarmGuardProvider = Provider<AlarmGuard>(
  (ref) => const PlatformAlarmGuard(),
);

/// Whether the guard's service is running (null off Android). Invalidated by
/// Settings after the switch changes.
final alarmGuardRunningProvider = FutureProvider<bool?>((ref) async {
  try {
    return await ref.watch(alarmGuardProvider).isRunning();
  } catch (_) {
    return null;
  }
});
