/// ============================================================
/// VAULT CRYPTO PROVIDERS — the core/crypto services as Riverpod singletons
/// ============================================================
///
/// Tests override [vaultStorageProvider] / [vaultBiometricStorageProvider] /
/// [vaultLegacyBiometricStorageProvider] with InMemoryVaultStorage (or
/// FakeOsGatedVaultStorage), [pinMonotonicClockProvider] with a fake, [biometricAuthProvider] with
/// FakeBiometricAuth, [vaultKdfParamsProvider] with `KdfParams.testing`
/// and [pinKdfProvider] with `Argon2PinKdf(useIsolate: false)` (isolates
/// do not run inside widget tests' fake-async zone).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/crypto/breach_check.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/secure_clipboard.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';
import 'package:focusflow/features/vault/data/datasource/screen_protection.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Keychain / Keystore store for the PIN-wrapped key, recovery wrap and
/// failed-attempt counter.
final vaultStorageProvider = Provider<VaultSecretStorage>(
  (ref) => SecureStoreVaultStorage(ref.watch(secureStoreProvider)),
);

/// OS-gated store for the biometric key copy (Keychain biometryCurrentSet
/// / auth-bound Keystore key).
///
/// Android uses the app's own androidx BiometricPrompt implementation
/// ([AndroidBiometricVaultStorage]); iOS the Keychain access-control store.
final vaultBiometricStorageProvider = Provider<VaultSecretStorage>(
  (ref) => defaultTargetPlatform == TargetPlatform.android
      ? AndroidBiometricVaultStorage()
      : BiometricVaultStorage(),
);

/// The pre-OS-gating biometric copy (read once to migrate, then deleted).
final vaultLegacyBiometricStorageProvider = Provider<VaultSecretStorage?>(
  (ref) => LegacyBiometricVaultStorage(),
);

/// Monotonic time for the PIN back-off (immune to device clock changes).
final pinMonotonicClockProvider = Provider<Duration Function()>((ref) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => LocalBiometricAuth(),
);

final pinKdfProvider = Provider<PinKdf>((ref) => const Argon2PinKdf());

/// Argon2id cost for new wraps (see pin_kdf.dart for the measurements).
final vaultKdfParamsProvider = Provider<KdfParams>(
  (ref) => KdfParams.recommended,
);

final vaultKeyManagerProvider = Provider<VaultKeyManager>(
  (ref) => VaultKeyManager(
    storage: ref.watch(vaultStorageProvider),
    biometricStorage: ref.watch(vaultBiometricStorageProvider),
    legacyBiometricStorage: ref.watch(vaultLegacyBiometricStorageProvider),
    kdf: ref.watch(pinKdfProvider),
    targetParams: ref.watch(vaultKdfParamsProvider),
    // Device calibration only for the production cost (tests override the
    // params with cheap ones and must stay deterministic).
    calibrate: ref.watch(vaultKdfParamsProvider) == KdfParams.recommended,
  ),
);

final pinAttemptGuardProvider = Provider<PinAttemptGuard>(
  (ref) => PinAttemptGuard(
    ref.watch(vaultStorageProvider),
    monotonic: ref.watch(pinMonotonicClockProvider),
  ),
);

/// Copies secrets (marked sensitive via the native channel) and clears the
/// clipboard after the configured delay; the pending clear is persisted.
final secureClipboardProvider = Provider<SecureClipboard>((ref) {
  final clipboard = SecureClipboard(
    now: () => ref.read(clockProvider).now(),
    store: ref.watch(vaultStorageProvider),
  );
  // Timers do not run while iOS suspends the app: clear an overdue copied
  // secret as soon as the app comes back.
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(clipboard.clearIfExpired()),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    clipboard.dispose();
  });
  return clipboard;
});

/// Opt-in HIBP k-anonymity lookups (only called when breach monitoring is
/// on or the user taps "Check now").
final breachCheckerProvider = Provider<BreachChecker>((ref) {
  final checker = BreachChecker();
  ref.onDispose(checker.close);
  return checker;
});

final passwordGeneratorProvider = Provider<PasswordGenerator>(
  (ref) => PasswordGenerator(),
);

/// The EFF large wordlist (loaded once from assets).
final effWordlistProvider = FutureProvider<EffWordlist>(
  (ref) => EffWordlist.load(),
);

/// Screenshot / app-switcher protection for vault screens (tests override
/// with FakeScreenProtection). Leaving the vault keeps the window secure
/// while Settings › Hide content in app switcher is on (same native flag).
final screenProtectionProvider = Provider<ScreenProtection>(
  (ref) => PluginScreenProtection(
    keepWindowSecure: () => ref.read(settingsProvider).hideInAppSwitcher,
  ),
);
