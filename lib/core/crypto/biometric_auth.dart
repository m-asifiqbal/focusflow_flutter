/// ============================================================
/// BIOMETRIC AUTH — the local_auth gate in front of biometric vault unlock
/// ============================================================
///
/// ## How biometric unlock works
/// When the user enables Face ID / fingerprint, the vault stores a second
/// copy of the 256-bit data key in [BiometricVaultStorage], protected by
/// OS-enforced access control: Keychain `biometryCurrentSet` on iOS, an
/// auth-bound (Class 3 biometrics, invalidated on new enrolment) Keystore
/// key on Android. Reading that copy IS the biometric check — the OS shows
/// the prompt and only releases the bytes after a match, so code running
/// inside the app process cannot read it without the user's finger/face.
///
/// [BiometricAuth] (local_auth) is still used for: availability / kind
/// labels, re-auth before Vault security changes, and a one-time unlock of
/// a LEGACY copy written by older versions (app-gated, not bound to a
/// match) — that copy is moved to the OS-gated store and deleted on the
/// next unlock, and deleted whenever the setting is off.
///
/// Nothing in this file logs or stores secrets.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// What the device offers, for labels ("Face ID" vs "fingerprint").
enum BiometricKind { none, face, fingerprint, generic }

abstract interface class BiometricAuth {
  /// True when the device has enrolled biometrics the app may use.
  Future<bool> isAvailable();

  Future<BiometricKind> kind();

  /// Shows the system prompt. Returns false on cancel / failure / no
  /// hardware (never throws).
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricKind> kind() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
      return types.isEmpty ? BiometricKind.none : BiometricKind.generic;
    } catch (_) {
      return BiometricKind.none;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Scriptable fake for tests.
@visibleForTesting
class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({
    this.available = true,
    this.result = true,
    this.biometricKind = BiometricKind.face,
  });

  bool available;
  bool result;
  BiometricKind biometricKind;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricKind> kind() async =>
      available ? biometricKind : BiometricKind.none;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return available && result;
  }
}
