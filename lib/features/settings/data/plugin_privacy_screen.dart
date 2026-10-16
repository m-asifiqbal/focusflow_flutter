/// ============================================================
/// PLUGIN PRIVACY SCREEN — "Hide content in app switcher" natively
/// ============================================================
///
/// What: [PrivacyScreen] over the `screen_protector` plugin. iOS: a solid
/// cover view replaces the app-switcher snapshot. Android: FLAG_SECURE,
/// which blanks the recents thumbnail (and, as a side effect, blocks
/// screenshots while it is on).
/// Why: a Flutter-drawn cover alone is not reliable — the OS may take the
/// snapshot before the next frame. AppLockGate paints one as well.
/// Every call is best-effort; a missing plugin (tests, desktop) is ignored.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:focusflow/features/settings/domain/services/privacy_screen.dart';
import 'package:screen_protector/screen_protector.dart';

class PluginPrivacyScreen implements PrivacyScreen {
  const PluginPrivacyScreen();

  @override
  Future<void> setEnabled(bool enabled, {required Color coverColor}) async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          enabled
              ? await ScreenProtector.protectDataLeakageWithColor(coverColor)
              : await ScreenProtector.protectDataLeakageWithColorOff();
        case TargetPlatform.android:
          enabled
              ? await ScreenProtector.protectDataLeakageOn()
              : await ScreenProtector.protectDataLeakageOff();
        default:
          break;
      }
    } on Object {
      // Plugin unavailable — the Flutter cover in AppLockGate still works.
    }
  }
}

/// Records calls instead of touching the platform (tests).
class FakePrivacyScreen implements PrivacyScreen {
  bool? enabled;
  int calls = 0;

  @override
  Future<void> setEnabled(bool enabled, {required Color coverColor}) async {
    this.enabled = enabled;
    calls++;
  }
}
