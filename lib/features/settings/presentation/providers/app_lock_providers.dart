/// ============================================================
/// APP LOCK PROVIDERS — lock state of the whole app (Settings › App lock)
/// ============================================================
///
/// What:
///   * [deviceAuthenticatorProvider] / [privacyScreenProvider] — platform
///     services (overridden with fakes in tests).
///   * [appLockBiometricProvider] — "Face ID", "Fingerprint", "Passcode"…
///   * [appLockControllerProvider] — [AppLockState]: locked on launch when
///     App lock is on, re-locked after the app spent [AppLockController.grace]
///     or longer in the background; [AppLockController.unlock] asks the OS.
/// Why: AppLockGate (UI) only reports lifecycle changes and renders the
/// state; the rules live here and are unit-testable with a fake clock.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/settings/data/local_device_authenticator.dart';
import 'package:focusflow/features/settings/data/plugin_privacy_screen.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:focusflow/features/settings/domain/services/privacy_screen.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalDeviceAuthenticator(
    isIOS: defaultTargetPlatform == TargetPlatform.iOS,
  ),
);

final privacyScreenProvider = Provider<PrivacyScreen>(
  (ref) => const PluginPrivacyScreen(),
);

/// The biometric the OS prompt will use ([BiometricKind.none] = passcode).
final appLockBiometricProvider = FutureProvider.autoDispose<BiometricKind>(
  (ref) => ref.watch(deviceAuthenticatorProvider).biometricKind(),
);

@immutable
class AppLockState {
  const AppLockState({
    this.locked = false,
    this.authenticating = false,
    this.message,
  });

  /// The lock screen covers the app.
  final bool locked;

  /// The OS prompt is up (lifecycle changes it causes are ignored).
  final bool authenticating;

  /// Why the last unlock failed ("Too many attempts…"), if it did.
  final String? message;

  AppLockState copyWith({
    bool? locked,
    bool? authenticating,
    String? message,
  }) => AppLockState(
    locked: locked ?? this.locked,
    authenticating: authenticating ?? this.authenticating,
    message: message,
  );
}

class AppLockController extends Notifier<AppLockState> {
  /// Time in the background that is forgiven (share sheets, file pickers,
  /// a quick app switch). Shown in the App lock footer.
  static const grace = Duration(seconds: 10);

  DateTime? _backgroundSince;

  bool get _enabled => ref.read(settingsProvider).appLockEnabled;

  @override
  AppLockState build() {
    // Turning App lock off from anywhere unlocks at once. Turning it on
    // does not lock the session the user is in.
    ref.listen(settingsProvider.select((s) => s.appLockEnabled), (_, on) {
      if (!on) state = const AppLockState();
    });
    return AppLockState(locked: _enabled);
  }

  /// The app went to the background (paused / hidden).
  void onBackground() {
    if (state.authenticating) return;
    _backgroundSince ??= ref.read(clockProvider).now();
  }

  /// The app is in the foreground again. Returns `justLocked`: true only
  /// when this resume locked an unlocked app (it spent [grace] or longer in
  /// the background) — the gate then shows the prompt once. Any other
  /// resume (the prompt's own dismissal, Control Center, a cancelled
  /// prompt) leaves the lock screen and its Unlock button alone, so a
  /// cancelled prompt never re-opens by itself.
  bool onResume() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (!_enabled || state.authenticating || state.locked) return false;
    if (since != null &&
        ref.read(clockProvider).now().difference(since) >= grace) {
      state = state.copyWith(locked: true);
      return true;
    }
    return false;
  }

  /// Shows the OS prompt; unlocks on success.
  Future<bool> unlock() async {
    if (!state.locked) return true;
    if (state.authenticating) return false;
    state = state.copyWith(authenticating: true);
    final auth = ref.read(deviceAuthenticatorProvider);
    final result = await auth.authenticate(
      tr('Unlock {name}', {'name': AppInfo.name}),
    );
    // No screen lock on the device any more: only the owner can remove
    // it (the OS asks for the old passcode), so let them in and say why.
    // Re-check, so a biometric hardware error can never unlock.
    final ok =
        result == DeviceAuthResult.success ||
        (result == DeviceAuthResult.unavailable && !await auth.isSupported());
    state = AppLockState(locked: !ok, message: _message(result));
    return ok;
  }

  /// Settings › App lock switch. Both directions need the device owner:
  /// turning it on proves the prompt works on this device (so nobody gets
  /// locked out), turning it off can't be done by someone holding an
  /// unlocked phone with FocusFlow open. Returns the prompt result
  /// (`unavailable` = no screen lock set up; nothing changes then).
  Future<DeviceAuthResult> setEnabled(bool on) async {
    if (on == _enabled) return DeviceAuthResult.success;
    final auth = ref.read(deviceAuthenticatorProvider);
    if (on && !await auth.isSupported()) return DeviceAuthResult.unavailable;
    state = state.copyWith(authenticating: true);
    final result = await auth.authenticate(
      on ? tr('Turn on App lock') : tr('Turn off App lock'),
    );
    state = state.copyWith(authenticating: false);
    if (result == DeviceAuthResult.success) {
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(appLockEnabled: on));
    }
    return result;
  }

  static String? _message(DeviceAuthResult r) => switch (r) {
    DeviceAuthResult.success || DeviceAuthResult.cancelled => null,
    DeviceAuthResult.lockedOut => tr(
      'Too many attempts. Unlock your device, then try again.',
    ),
    DeviceAuthResult.unavailable => tr(
      'This device has no screen lock, so App lock can’t protect {name}.',
      {'name': AppInfo.name},
    ),
    DeviceAuthResult.failed => tr('Couldn’t verify it’s you. Try again.'),
  };
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
