/// ============================================================
/// SCREEN PROTECTION — block screenshots / app-switcher previews in the vault
/// ============================================================
///
/// Wraps the `screen_protector` plugin (Android FLAG_SECURE; iOS secure
/// layer + blurred app-switcher snapshot). Only vault screens turn it on,
/// and only while Settings › Vault security › Block screenshots is on.
/// Every call is best-effort: a missing plugin (tests, desktop) is ignored.
///
/// Why [keepWindowSecure]: on Android the plugin's "screenshot off" and the
/// app-wide "Hide content in app switcher" (protectDataLeakageOn) are the
/// same window flag, FLAG_SECURE. Leaving the vault must not clear the flag
/// the app-level privacy setting still wants, so disable() skips it then.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

abstract interface class ScreenProtection {
  Future<void> enable();
  Future<void> disable();
}

class PluginScreenProtection implements ScreenProtection {
  /// [keepWindowSecure] answers "does the app itself still want the window
  /// secure?" (Settings › Hide content in app switcher).
  const PluginScreenProtection({this.keepWindowSecure});

  final bool Function()? keepWindowSecure;

  @override
  Future<void> enable() async {
    try {
      await ScreenProtector.preventScreenshotOn();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await ScreenProtector.protectDataLeakageWithBlur();
      }
    } on Object {
      // Plugin unavailable on this platform — nothing to protect with.
    }
  }

  @override
  Future<void> disable() async {
    try {
      final android = defaultTargetPlatform == TargetPlatform.android;
      if (!android || !(keepWindowSecure?.call() ?? false)) {
        await ScreenProtector.preventScreenshotOff();
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await ScreenProtector.protectDataLeakageWithBlurOff();
      }
    } on Object {
      // See enable().
    }
  }
}

/// Records calls instead of touching the platform (tests).
class FakeScreenProtection implements ScreenProtection {
  bool enabled = false;
  int enableCalls = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enableCalls++;
  }

  @override
  Future<void> disable() async => enabled = false;
}
