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
/// The same applies one level up on those phones: the maker's own
/// "auto-start" list ([aggressiveBrandProvider], [openAutostartSettings]).
/// A swipe from the recent-apps screen otherwise force-stops the app and
/// Android drops its alarms. When that happens anyway, the notification
/// engine renews every alarm on the next start and shows what was missed
/// (see NotificationReconciler.reconcile).
///
/// Settings hook (Settings › Notifications belongs to the settings
/// feature): drop `const ReminderReliabilityBanners(showAll: true)`
/// (features/reminders/presentation/widgets/reminder_reliability_banners.dart)
/// into the notifications screen; it reads these providers.
/// ============================================================
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// Phone makers whose task killer treats swiping the app away like a
/// force-stop, which drops every alarm the app scheduled. Lifting the
/// battery optimisation is not enough there: the user also has to allow
/// "auto-start" / background activity (or Samsung's sleeping-apps list)
/// for the app — no API can do that for them.
///
/// Keys are lower-case `Build.MANUFACTURER` values, values the brand name
/// shown to the user.
const Map<String, String> aggressiveBackgroundMakers = {
  'xiaomi': 'Xiaomi',
  'redmi': 'Xiaomi',
  'poco': 'Xiaomi',
  'oppo': 'Oppo',
  'realme': 'Realme',
  'oneplus': 'OnePlus',
  'vivo': 'Vivo',
  'iqoo': 'iQOO',
  'huawei': 'Huawei',
  'honor': 'Honor',
  'samsung': 'Samsung',
  'asus': 'Asus',
  'tecno': 'Tecno',
  'infinix': 'Infinix',
  'itel': 'itel',
  'meizu': 'Meizu',
  'lenovo': 'Lenovo',
  'nokia': 'Nokia',
  'hmd global': 'Nokia',
};

/// The OS side of the "auto-start" guidance (fake in tests).
abstract class OemBackgroundGuide {
  /// The brand name when this phone's maker is known to stop alarms of
  /// swiped-away apps; null for stock Android, iOS and other platforms.
  Future<String?> aggressiveBrand();

  /// Opens the maker's auto-start / background screen, or the app's info
  /// page when the phone has none we know. Returns whether anything opened.
  Future<bool> openSettings();
}

class PlatformOemBackgroundGuide implements OemBackgroundGuide {
  const PlatformOemBackgroundGuide();

  static const MethodChannel _native = MethodChannel('focusflow/notifications');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> aggressiveBrand() async {
    if (!_android) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    return aggressiveBackgroundMakers[info.manufacturer.toLowerCase().trim()];
  }

  @override
  Future<bool> openSettings() async {
    if (!_android) return false;
    try {
      if (await _native.invokeMethod<bool>('openAutostartSettings') == true) {
        return true;
      }
    } on PlatformException {
      // Fall through to the app info page.
    } on MissingPluginException {
      // No native side (tests, other engines).
    }
    return openAppSettings();
  }
}

final oemBackgroundGuideProvider = Provider<OemBackgroundGuide>(
  (ref) => const PlatformOemBackgroundGuide(),
);

/// Brand of a phone that needs the auto-start step (null elsewhere).
final aggressiveBrandProvider = FutureProvider<String?>((ref) async {
  try {
    return await ref.watch(oemBackgroundGuideProvider).aggressiveBrand();
  } catch (_) {
    return null;
  }
});

/// Preference: the user opened the auto-start page once (the editor stops
/// suggesting it; Settings keeps offering it — Android cannot tell whether
/// they really switched it on).
const String autostartAskedKey = 'notifications.autostart_asked';

/// Whether the reminder editor should still suggest the auto-start step.
final suggestAutostartProvider = Provider<bool>((ref) {
  final asked =
      ref.watch(sharedPreferencesProvider).getBool(autostartAskedKey) ?? false;
  return !asked && ref.watch(aggressiveBrandProvider).valueOrNull != null;
});

/// Opens the maker's auto-start screen and remembers it was offered.
Future<bool> openAutostartSettings(Ref ref) async {
  var opened = false;
  try {
    opened = await ref.read(oemBackgroundGuideProvider).openSettings();
  } catch (_) {
    opened = false;
  }
  await ref.read(sharedPreferencesProvider).setBool(autostartAskedKey, true);
  ref.invalidate(suggestAutostartProvider);
  return opened;
}

/// Callable form of [openAutostartSettings] for widgets (`WidgetRef`).
final autostartRequestProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () => openAutostartSettings(ref),
);

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
