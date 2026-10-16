/// ============================================================
/// VAULT SESSION STATE — locked / unlocked + the in-memory data key
/// ============================================================
///
/// Immutable snapshot published by VaultSessionController. The decrypted
/// data key ([key]) is present ONLY while [phase] is
/// [VaultPhase.unlocked]; providers that decrypt payloads watch the session
/// and therefore drop every plaintext they computed the moment the vault
/// locks. [toString] never prints the key.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/vault_key.dart';

/// Vault session status shown outside the vault (Library tile "Locked" /
/// "Unlocked", Search "unlock to view", Home). Re-exported by vault_gate.
enum VaultStatus { notSetUp, locked, unlocked }

/// Finer-grained phase used inside the vault.
///
/// [unreadable]: a key bundle is stored but cannot be parsed, or vault
/// items exist without any key. The vault must NOT offer set-up then (it
/// would orphan the items' ciphertext): only recovery-code unlock or an
/// explicit, typed "erase vault".
enum VaultPhase { loading, notSetUp, locked, unlocked, unreadable }

/// Outcome of an unlock / PIN verification attempt.
enum UnlockResult {
  success,

  /// Wrong PIN; [VaultSessionState.attempts] has the new count / lock-out.
  wrongPin,

  /// Still inside a back-off window; nothing was tried.
  lockedOut,

  /// That failure crossed the wipe threshold (setting on): vault erased.
  wiped,

  /// Biometrics not enabled / not available, or no vault.
  unavailable,

  /// The user dismissed the biometric prompt.
  cancelled,
}

/// Thrown when vault crypto is requested while the vault is locked.
class VaultLockedException implements Exception {
  const VaultLockedException();

  @override
  String toString() => 'VaultLockedException: the vault is locked';
}

@immutable
class VaultSessionState {
  const VaultSessionState({
    required this.phase,
    this.key,
    this.attempts = PinAttemptState.initial,
    this.biometricsReady = false,
    this.biometricKind = BiometricKind.none,
    this.unlockedAt,
    this.pinResetRequired = false,
  });

  static const VaultSessionState loading = VaultSessionState(
    phase: VaultPhase.loading,
  );

  final VaultPhase phase;

  /// The unwrapped data key; null unless unlocked.
  final VaultKey? key;

  /// Failed-PIN counter and back-off deadline.
  final PinAttemptState attempts;

  /// Biometric unlock can be offered right now (setting on, device
  /// enrolled, biometric key copy present).
  final bool biometricsReady;
  final BiometricKind biometricKind;
  final DateTime? unlockedAt;

  /// Unlocked with the recovery code (forgotten PIN): a new PIN must be
  /// chosen before the vault is used.
  final bool pinResetRequired;

  bool get isUnlocked => phase == VaultPhase.unlocked && key != null;

  VaultStatus get status => switch (phase) {
    VaultPhase.notSetUp => VaultStatus.notSetUp,
    VaultPhase.unlocked => VaultStatus.unlocked,
    VaultPhase.loading ||
    VaultPhase.locked ||
    VaultPhase.unreadable => VaultStatus.locked,
  };

  /// The key, or [VaultLockedException].
  VaultKey requireKey() {
    final k = key;
    if (!isUnlocked || k == null || k.isDestroyed) {
      throw const VaultLockedException();
    }
    return k;
  }

  VaultSessionState copyWith({
    VaultPhase? phase,
    PinAttemptState? attempts,
    bool? biometricsReady,
    BiometricKind? biometricKind,
    bool? pinResetRequired,
  }) => VaultSessionState(
    phase: phase ?? this.phase,
    key: key,
    attempts: attempts ?? this.attempts,
    biometricsReady: biometricsReady ?? this.biometricsReady,
    biometricKind: biometricKind ?? this.biometricKind,
    unlockedAt: unlockedAt,
    pinResetRequired: pinResetRequired ?? this.pinResetRequired,
  );

  /// The same state without the key (locked).
  VaultSessionState locked({VaultPhase phase = VaultPhase.locked}) =>
      VaultSessionState(
        phase: phase,
        attempts: attempts,
        biometricsReady: biometricsReady,
        biometricKind: biometricKind,
      );

  @override
  String toString() =>
      'VaultSessionState($phase, failed: ${attempts.failed}, '
      'biometrics: $biometricsReady)';
}
