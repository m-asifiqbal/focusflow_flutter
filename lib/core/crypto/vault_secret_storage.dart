/// ============================================================
/// VAULT SECRET STORAGE — where the vault's key material is kept
/// ============================================================
///
/// Two small key/value stores, both backed by the platform keystore:
///
/// * [SecureStoreVaultStorage] — the app's [SecureStore] (Keychain
///   `first_unlock_this_device` / Android Keystore-wrapped prefs). Holds the
///   PIN-wrapped data key + KDF params, the recovery-wrapped data key and
///   the failed-attempt counter. Everything here is useless without the PIN
///   (or recovery code).
/// * [BiometricVaultStorage] — a SEPARATE, OS-gated store for the
///   biometric unlock copy of the data key: Keychain `biometryCurrentSet`
///   access control / an auth-bound Android Keystore key, so the OS (not
///   the app) decides whether the copy can be read.
/// * [LegacyBiometricVaultStorage] — the older app-gated copy, kept only
///   so existing installs migrate (see VaultKeyManager).
///
/// [InMemoryVaultStorage] backs unit and widget tests.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/storage/secure_store.dart';

abstract interface class VaultSecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The app-wide secure store.
class SecureStoreVaultStorage implements VaultSecretStorage {
  const SecureStoreVaultStorage(this._store);

  final SecureStore _store;

  @override
  Future<String?> read(String key) => _store.read(key);

  @override
  Future<void> write(String key, String value) => _store.write(key, value);

  @override
  Future<void> delete(String key) => _store.delete(key);
}

/// A store whose reads are gated by the OPERATING SYSTEM, not by the app:
/// reading an item shows the system Face ID / fingerprint prompt and the
/// keystore only releases the value after a successful match.
///
/// [read] returns null when the item does not exist or was permanently
/// invalidated (biometrics re-enrolled), and throws
/// [BiometricReadException] when the user cancelled / the match failed.
abstract interface class OsGatedVaultStorage implements VaultSecretStorage {
  /// True when writing also shows the system prompt (Android: the
  /// auth-bound Keystore key is needed to encrypt as well).
  bool get writePrompts;
}

/// The OS prompt behind an [OsGatedVaultStorage] read was cancelled or
/// failed; the stored item is untouched.
class BiometricReadException implements Exception {
  const BiometricReadException();

  @override
  String toString() => 'BiometricReadException';
}

/// The biometric unlock copy of the data key, protected by OS-enforced
/// access control (flutter_secure_storage 11):
///
/// * iOS: Keychain item `WhenPasscodeSetThisDeviceOnly` +
///   `SecAccessControl(.biometryCurrentSet)` — the Secure Enclave only
///   releases it after a Face ID / Touch ID match with the CURRENTLY
///   enrolled biometrics (a new enrolment makes it unreadable); never
///   synced, deleted when the passcode is removed.
/// * Android (API 28+): AES-GCM data wrapped by a Keystore key created
///   with `setUserAuthenticationRequired(true)`, Class-3 biometrics only,
///   `setInvalidatedByBiometricEnrollment(true)`; a fresh BiometricPrompt
///   + CryptoObject for EVERY read/write (`requireBiometricsPerOperation`).
///
/// Uses new namespaces (`….v2`) so a legacy app-gated copy
/// ([LegacyBiometricVaultStorage]) can be told apart and migrated.
class BiometricVaultStorage implements OsGatedVaultStorage {
  BiometricVaultStorage([FlutterSecureStorage? storage]) : _injected = storage;

  final FlutterSecureStorage? _injected;

  /// Built on every use (cheap: it only holds options) so the prompt text
  /// follows the language the user has chosen right now.
  FlutterSecureStorage get _storage =>
      _injected ??
      FlutterSecureStorage(
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.passcode,
          accountName: 'focusflow.vault.biometric.v2',
          accessControlFlags: [AccessControlFlag.biometryCurrentSet],
        ),
        aOptions: AndroidOptions.biometric(
          storageNamespace: 'ff_vault_biometric_v2',
          enforceBiometrics: true,
          requireBiometricsPerOperation: true,
          biometricType: AndroidBiometricType.strongBiometricOnly,
          biometricPromptTitle: tr('Unlock your vault'),
          biometricPromptSubtitle: tr('Confirm your fingerprint or face'),
          biometricPromptNegativeButton: tr('Use PIN'),
        ),
      );

  @override
  bool get writePrompts => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> read(String key) async {
    try {
      return await _prompted(_storage.read(key: key));
    } on PlatformException {
      // Cancel, failed match, lock-out — the item itself is kept.
      throw const BiometricReadException();
    }
  }

  @override
  Future<void> write(String key, String value) async {
    // Delete first: updating an access-controlled Keychain item would
    // itself require authentication.
    await delete(key);
    try {
      await _prompted(_storage.write(key: key, value: value));
    } on PlatformException {
      throw const BiometricReadException();
    }
  }

  /// After the prompt closes, how long the plugin may take to answer.
  @visibleForTesting
  static const Duration dismissGrace = Duration(milliseconds: 2500);

  /// Upper bound for one prompted call (a prompt left open, a phone whose
  /// prompt doesn't take the window focus).
  @visibleForTesting
  static const Duration promptCeiling = Duration(seconds: 60);

  /// Makes a call that shows the Android BiometricPrompt always end.
  ///
  /// flutter_secure_storage 11.2 gives the prompt's negative button ("Use
  /// PIN") an empty listener, and the framework prompt reports that button
  /// only to the listener — so the call never answered, and everything
  /// waiting on it (the Settings switch, first set-up) hung for good. The
  /// prompt takes the window focus (app → inactive) and gives it back when
  /// it closes (→ resumed): when no answer follows within [dismissGrace],
  /// the prompt was dismissed and this throws [BiometricReadException]
  /// (= cancelled). [promptCeiling] bounds everything else.
  Future<T> _prompted<T>(Future<T> call) {
    // Only the real plugin on Android prompts per call (tests inject a
    // fake storage and may have no binding).
    if (_injected != null || !writePrompts) return call;
    final done = Completer<T>();
    Timer? grace;
    Timer? ceiling;
    AppLifecycleListener? listener;
    void finish(void Function() complete) {
      if (done.isCompleted) return;
      grace?.cancel();
      ceiling?.cancel();
      listener?.dispose();
      complete();
    }

    void cancelled() =>
        finish(() => done.completeError(const BiometricReadException()));
    var leftApp = false;
    listener = AppLifecycleListener(
      onStateChange: (s) {
        if (s != AppLifecycleState.resumed) {
          leftApp = true;
          grace?.cancel();
        } else if (leftApp) {
          grace?.cancel();
          grace = Timer(dismissGrace, cancelled);
        }
      },
    );
    ceiling = Timer(promptCeiling, cancelled);
    call.then(
      (v) => finish(() => done.complete(v)),
      onError: (Object e, StackTrace s) =>
          finish(() => done.completeError(e, s)),
    );
    return done.future;
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The biometric unlock copy on ANDROID: the native `BiometricVault`
/// (android/.../BiometricVault.kt, channel `focusflow/biometric_vault`).
///
/// Same contract as [BiometricVaultStorage] — an auth-bound Keystore key
/// that needs a fresh strong-biometric match for every read and write, null
/// when there is no copy or it was invalidated (fingerprints changed),
/// [BiometricReadException] when the user did not authenticate — but driven
/// by androidx BiometricPrompt on the main thread. Every call is answered
/// exactly once by the native side ("Use PIN" included), so none of the
/// lifecycle guessing [BiometricVaultStorage] needs is required here; the
/// [ceiling] is only a last resort.
class AndroidBiometricVaultStorage implements OsGatedVaultStorage {
  AndroidBiometricVaultStorage({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'focusflow/biometric_vault';

  final MethodChannel _channel;

  /// A prompt left open this long is cancelled.
  @visibleForTesting
  static const Duration ceiling = Duration(seconds: 60);

  @override
  bool get writePrompts => true;

  /// Prompt texts, in the language chosen right now.
  Map<String, Object?> get _texts => {
    'title': tr('Unlock your vault'),
    'subtitle': tr('Confirm your fingerprint or face'),
    'negative': tr('Use PIN'),
  };

  Future<T?> _prompted<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel
          .invokeMethod<T>(method, args)
          .timeout(
            ceiling,
            onTimeout: () {
              unawaited(_cancelPrompt());
              throw const BiometricReadException();
            },
          );
    } on PlatformException {
      // cancelled · busy · unavailable · error: nothing was read or stored.
      throw const BiometricReadException();
    } on MissingPluginException {
      throw const BiometricReadException();
    }
  }

  Future<void> _cancelPrompt() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Object {
      // Best effort.
    }
  }

  @override
  Future<String?> read(String key) =>
      _prompted<String>('read', {'key': key, ..._texts});

  @override
  Future<void> write(String key, String value) async {
    final ok = await _prompted<bool>('write', {
      'key': key,
      'value': value,
      ..._texts,
    });
    if (ok != true) throw const BiometricReadException();
  }

  /// Never prompts and never throws.
  @override
  Future<void> delete(String key) async {
    try {
      await _channel.invokeMethod<void>('delete', {'key': key});
    } on Object {
      // Nothing to delete / no platform side (tests).
    }
  }
}

/// The pre-1.0.3 biometric copy: a raw data key in a device-only namespace
/// whose reads are NOT bound to a biometric match (the app checked
/// local_auth first). Only read once more to migrate, then deleted.
class LegacyBiometricVaultStorage implements VaultSecretStorage {
  LegacyBiometricVaultStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.passcode,
              accountName: 'focusflow.vault.biometric',
            ),
            aOptions: AndroidOptions(storageNamespace: 'ff_vault_biometric'),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Map-backed storage for tests.
@visibleForTesting
class InMemoryVaultStorage implements VaultSecretStorage {
  InMemoryVaultStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// [InMemoryVaultStorage] that behaves like an OS-gated store: every read
/// "shows the system prompt" ([prompts]) and fails with
/// [BiometricReadException] while [allow] is false.
@visibleForTesting
class FakeOsGatedVaultStorage extends InMemoryVaultStorage
    implements OsGatedVaultStorage {
  FakeOsGatedVaultStorage({this.writePrompts = false});

  @override
  final bool writePrompts;
  bool allow = true;

  /// Fails the next writes (e.g. the prompt was cancelled while enabling).
  bool failWrites = false;
  int prompts = 0;

  @override
  Future<String?> read(String key) async {
    prompts++;
    if (!allow) throw const BiometricReadException();
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (writePrompts) prompts++;
    if (failWrites) throw const BiometricReadException();
    await super.write(key, value);
  }
}
