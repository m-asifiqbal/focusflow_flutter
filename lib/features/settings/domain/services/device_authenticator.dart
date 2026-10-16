/// ============================================================
/// DEVICE AUTHENTICATOR (contract) — Face ID / fingerprint / passcode
/// ============================================================
///
/// Used by App lock (Settings › App lock + AppLockGate) and to label the
/// biometric on the Settings rows ("Face ID"). FocusFlow never sees the
/// biometric or the device passcode: the OS verifies and answers yes/no.
/// ============================================================
library;

/// The strongest biometric the OS offers this app.
enum BiometricKind {
  faceId('Face ID'),
  touchId('Touch ID'),
  face('Face unlock'),
  fingerprint('Fingerprint'),
  biometrics('Biometrics'),
  none('Passcode');

  const BiometricKind(this.label);

  /// "Face ID", "Fingerprint" … ("Passcode" when there is no biometric).
  final String label;
}

/// Outcome of [DeviceAuthenticator.authenticate].
enum DeviceAuthResult {
  success,

  /// The user dismissed the prompt.
  cancelled,

  /// The device has no screen lock / biometric set up (or no plugin).
  unavailable,

  /// Too many attempts — the OS blocks authentication for a while.
  lockedOut,

  /// Anything else (system interruption, device error).
  failed,
}

abstract interface class DeviceAuthenticator {
  /// True when the device can verify the owner (biometric or passcode).
  Future<bool> isSupported();

  /// The biometric used by the prompt (or [BiometricKind.none]).
  Future<BiometricKind> biometricKind();

  /// Shows the OS prompt (biometric with passcode fallback).
  Future<DeviceAuthResult> authenticate(String reason);
}
