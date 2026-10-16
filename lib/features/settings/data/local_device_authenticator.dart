/// ============================================================
/// LOCAL DEVICE AUTHENTICATOR — App lock over `local_auth`
/// ============================================================
///
/// What: [DeviceAuthenticator] backed by the OS prompt — biometrics with
/// the device passcode / pattern as fallback (`biometricOnly: false`), so
/// App lock works on devices without enrolled biometrics too.
/// Why: the app never sees a biometric or the passcode; the OS answers
/// yes / no. Platform errors are mapped to [DeviceAuthResult] and never
/// thrown, and nothing is logged.
/// ============================================================
library;

import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:local_auth/local_auth.dart';

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({required this.isIOS, LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// Picks "Face ID / Touch ID" vs "Face unlock / Fingerprint" labels.
  final bool isIOS;
  final LocalAuthentication _auth;

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<BiometricKind> biometricKind() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        return isIOS ? BiometricKind.faceId : BiometricKind.face;
      }
      if (types.contains(BiometricType.fingerprint)) {
        return isIOS ? BiometricKind.touchId : BiometricKind.fingerprint;
      }
      return types.isEmpty ? BiometricKind.none : BiometricKind.biometrics;
    } on Object {
      return BiometricKind.none;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.timeout => DeviceAuthResult.cancelled,
        // Only "no screen lock at all" may count as unavailable (the
        // controller lets the owner in then). A biometric error while a
        // passcode still exists must never unlock.
        LocalAuthExceptionCode.noCredentialsSet => DeviceAuthResult.unavailable,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware => DeviceAuthResult.failed,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => DeviceAuthResult.lockedOut,
        _ => DeviceAuthResult.failed,
      };
    } on Object {
      return DeviceAuthResult.failed;
    }
  }
}

/// Scriptable fake for tests.
class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({
    this.supported = true,
    this.kind = BiometricKind.faceId,
    this.result = DeviceAuthResult.success,
  });

  bool supported;
  BiometricKind kind;
  DeviceAuthResult result;
  int prompts = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<BiometricKind> biometricKind() async =>
      supported ? kind : BiometricKind.none;

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    prompts++;
    return supported ? result : DeviceAuthResult.unavailable;
  }
}
