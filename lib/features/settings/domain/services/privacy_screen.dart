/// ============================================================
/// PRIVACY SCREEN (contract) — hide app content in the app switcher
/// ============================================================
///
/// Settings › "Hide content in app switcher". The native layer does the
/// reliable part (iOS: a cover view on resign-active; Android: FLAG_SECURE,
/// which also keeps the recents thumbnail blank). AppLockGate additionally
/// paints a Flutter cover while the app is inactive.
/// ============================================================
library;

import 'dart:ui' show Color;

abstract interface class PrivacyScreen {
  /// Turns the native app-switcher protection on ([coverColor] is the
  /// colour iOS shows instead of the snapshot) or off.
  Future<void> setEnabled(bool enabled, {required Color coverColor});
}
