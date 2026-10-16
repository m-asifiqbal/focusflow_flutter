/// ============================================================
/// BACKGROUND DELIVERY — "Allow reminders in the background" (Android)
/// ============================================================
///
/// What: whether Android's battery optimisation is lifted for FocusFlow
/// (`Permission.ignoreBatteryOptimizations`, permission_handler) and an
/// opt-in request for it. iOS has no such switch (scheduled requests are
/// delivered by the OS with the app closed): [unrestrictedBackgroundProvider]
/// is null there.
///
/// Why: scheduled reminders are exact alarms the OS fires on its own, but
/// several OEM builds (Xiaomi, Oppo, Vivo, some Samsung modes) also kill
/// alarms of "optimised" apps that were swiped away. Lifting the
/// optimisation is the user's choice: it is only asked when they tap
/// Allow in the reminder editor (or Settings › Notifications), never at
/// start-up. Play policy restricts REQUEST_IGNORE_BATTERY_OPTIMIZATIONS to
/// apps whose core function needs it (reminders / alarms) — see
/// docs/notifications.md.
///
/// Settings hook (Settings › Notifications belongs to the settings
/// feature): drop `const ReminderReliabilityBanners(showAll: true)`
/// (features/reminders/presentation/widgets/reminder_reliability_banners.dart)
/// into the notifications screen; it reads these providers.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:permission_handler/permission_handler.dart';

/// The OS side (fake in tests).
abstract class BackgroundDelivery {
  /// True = battery optimisation is lifted; false = optimised; null = not
  /// applicable (iOS, other platforms).
  Future<bool?> isUnrestricted();

  /// Shows Android's "Let app always run in background?" dialog; returns
  /// the state afterwards.
  Future<bool?> requestUnrestricted();
}

class PermissionHandlerBackgroundDelivery implements BackgroundDelivery {
  const PermissionHandlerBackgroundDelivery();

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool?> isUnrestricted() async {
    if (!_android) return null;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  @override
  Future<bool?> requestUnrestricted() async {
    if (!_android) return null;
    return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
  }
}

final backgroundDeliveryProvider = Provider<BackgroundDelivery>(
  (ref) => const PermissionHandlerBackgroundDelivery(),
);

/// Battery optimisation lifted (null on iOS). Invalidated on resume by
/// the engine and after [requestUnrestrictedBackground].
final unrestrictedBackgroundProvider = FutureProvider<bool?>((ref) async {
  try {
    return await ref.watch(backgroundDeliveryProvider).isUnrestricted();
  } catch (_) {
    return null;
  }
});

/// Preference: the user was asked once (the editor stops suggesting it;
/// Settings keeps offering it).
const String backgroundDeliveryAskedKey = 'notifications.background_asked';

/// Whether the reminder editor should still suggest it.
final suggestUnrestrictedBackgroundProvider = Provider<bool>((ref) {
  final asked =
      ref
          .watch(sharedPreferencesProvider)
          .getBool(backgroundDeliveryAskedKey) ??
      false;
  return !asked &&
      ref.watch(unrestrictedBackgroundProvider).valueOrNull == false;
});

/// Opt-in request ("Allow"); remembers that it was asked.
Future<bool?> requestUnrestrictedBackground(Ref ref) async {
  bool? result;
  try {
    result = await ref.read(backgroundDeliveryProvider).requestUnrestricted();
  } catch (_) {
    result = null;
  }
  await ref
      .read(sharedPreferencesProvider)
      .setBool(backgroundDeliveryAskedKey, true);
  ref
    ..invalidate(unrestrictedBackgroundProvider)
    ..invalidate(suggestUnrestrictedBackgroundProvider);
  return result;
}
