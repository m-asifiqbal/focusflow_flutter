/// ============================================================
/// LOCK SCREEN ACCESS — "can an alarm / reminder reach the lock screen?"
/// ============================================================
///
/// Why: with every standard permission granted, some phones still keep alarms
/// and reminders off the lock screen and refuse to open the alarm screen from
/// the background. Xiaomi / Redmi / POCO (MIUI, HyperOS, the Chinese ROMs in
/// particular) have two extra per-app switches — "Show on lock screen" and
/// "Display pop-up windows while running in the background" — that default to
/// off; and on any phone the user can set a notification channel to
/// "Don't show on the lock screen" or block it. Android reports none of this
/// through its permission APIs, so the native side
/// (`android/.../MakerPermissions.kt`) reads what it can and this file turns
/// it into a banner ([ReminderReliabilityBanners]) with a button to the exact
/// system page. Re-read when the app resumes.
///
/// Not Android → nothing to fix.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';

/// What the phone says about the lock screen. `null` = it would not tell.
@immutable
class LockScreenAccess {
  const LockScreenAccess({
    this.xiaomi = false,
    this.showOnLockScreen = true,
    this.backgroundPopup = true,
    this.blockedChannels = const [],
  });

  /// A Xiaomi-family phone (the two switches below exist only there).
  final bool xiaomi;

  /// MIUI "Show on lock screen".
  final bool? showOnLockScreen;

  /// MIUI "Display pop-up windows while running in the background".
  final bool? backgroundPopup;

  /// Reminder / alarm channels the user blocked or hid from the lock screen.
  final List<String> blockedChannels;

  /// Something is known to be off.
  bool get needsAttention => makerSwitchOff || blockedChannels.isNotEmpty;

  /// A MIUI switch is known to be off (unknown does not count).
  bool get makerSwitchOff =>
      xiaomi && (showOnLockScreen == false || backgroundPopup == false);

  /// A MIUI switch could not be read: worth showing in Settings, not in the
  /// editor.
  bool get makerSwitchUnknown =>
      xiaomi &&
      !makerSwitchOff &&
      (showOnLockScreen == null || backgroundPopup == null);

  static const LockScreenAccess fine = LockScreenAccess();
}

/// The OS side (fake in tests).
abstract class LockScreenAccessSource {
  Future<LockScreenAccess> read();

  /// Opens the page that fixes it; [channelId] = a blocked channel to land on.
  Future<void> openSettings({String? channelId});
}

class PlatformLockScreenAccess implements LockScreenAccessSource {
  const PlatformLockScreenAccess();

  static const MethodChannel _native = MethodChannel('focusflow/notifications');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Channels that carry something the user must see on a locked phone.
  static final List<String> _channelIds = [
    for (final c in NotificationChannelId.values)
      if (c != NotificationChannelId.digests &&
          c != NotificationChannelId.system)
        c.id,
  ];

  @override
  Future<LockScreenAccess> read() async {
    if (!_android) return LockScreenAccess.fine;
    try {
      final m = await _native.invokeMapMethod<String, Object?>(
        'lockScreenAccess',
        {'channelIds': _channelIds},
      );
      if (m == null) return LockScreenAccess.fine;
      return LockScreenAccess(
        xiaomi: m['xiaomi'] == true,
        showOnLockScreen: m['showOnLockScreen'] as bool?,
        backgroundPopup: m['backgroundPopup'] as bool?,
        blockedChannels: [...?(m['blockedChannels'] as List?)?.cast<String>()],
      );
    } on MissingPluginException {
      return LockScreenAccess.fine;
    } on PlatformException {
      return LockScreenAccess.fine;
    }
  }

  @override
  Future<void> openSettings({String? channelId}) async {
    if (!_android) return;
    try {
      await _native.invokeMethod<bool>('openLockScreenSettings', {
        'channelId': channelId,
      });
    } on MissingPluginException {
      // Not the app's main engine (tests).
    } on PlatformException {
      // Nothing to open on this device.
    }
  }
}

final lockScreenAccessSourceProvider = Provider<LockScreenAccessSource>(
  (ref) => const PlatformLockScreenAccess(),
);

/// Current lock-screen access (fine off Android); invalidated on resume.
final lockScreenAccessProvider = FutureProvider<LockScreenAccess>((ref) async {
  try {
    return await ref.watch(lockScreenAccessSourceProvider).read();
  } catch (_) {
    return LockScreenAccess.fine;
  }
});

/// Opens the fixing page; the state is re-read when the app resumes.
Future<void> openLockScreenSettings(Ref ref, {String? channelId}) async {
  try {
    await ref
        .read(lockScreenAccessSourceProvider)
        .openSettings(channelId: channelId);
  } catch (_) {
    // The banner stays; nothing to do.
  }
  ref.invalidate(lockScreenAccessProvider);
}

/// Callable form for widgets.
final lockScreenSettingsRequestProvider =
    Provider<Future<void> Function({String? channelId})>(
      (ref) =>
          ({String? channelId}) =>
              openLockScreenSettings(ref, channelId: channelId),
    );
