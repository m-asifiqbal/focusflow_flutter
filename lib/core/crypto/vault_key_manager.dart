/// ============================================================
/// VAULT KEY MANAGER — set-up, unlock, PIN change, biometrics, recovery
/// ============================================================
///
/// Envelope encryption:
///
///   DEK  = 256 random bits (encrypts every vault blob, see VaultCipher)
///   KEK  = Argon2id(PIN, salt, params)          (pin_kdf.dart)
///   stored: { params, salt, AES-GCM(KEK, DEK) }  → SecureStore `vault.bundle`
///
/// * Wrong PIN ⇒ the GCM tag fails ⇒ [unlockWithPin] returns null. There is
///   no PIN hash to compare against.
/// * Changing the PIN re-wraps the SAME DEK under a new salt/KEK: no vault
///   item is re-encrypted ([changePin]).
/// * Params live in the bundle; after an unlock with weaker params than
///   [targetParams], the DEK is transparently re-wrapped with the new cost.
/// * Biometric copy: the DEK in an OS-gated store ([OsGatedVaultStorage]:
///   Keychain `biometryCurrentSet` / auth-bound Keystore key), so reading it
///   needs a biometric match enforced by the OS. A non-secret marker
///   (`vault.bio.os`) in the main store says the copy exists without
///   reading (= prompting). Installs from before this used an app-gated
///   copy ([LegacyBiometricVaultStorage]); it still unlocks once (after
///   local_auth) and is then moved to the OS-gated store and deleted.
/// * Recovery code (Recovery Kit PDF): 160 random bits shown once; the DEK
///   is also wrapped under HKDF(code) in `vault.recovery`. A new code is
///   two-phase: [prepareRecoveryCode] → the user saves it →
///   [commitRecoveryCode] replaces (invalidates) the old one.
/// * A key bundle that exists but cannot be parsed is reported as
///   [VaultKeyStatus.unreadable] — never as "not set up" — so set-up can
///   not silently overwrite the key of existing ciphertext.
/// * [exportBundle] / [importBundle] let backups carry the PIN-wrapped DEK
///   so a restored vault opens with the same PIN on a new device.
/// ============================================================
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/crypto_bytes.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/crypto/vault_key.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

/// The PIN-wrapped data key + everything needed to unwrap it.
@immutable
class VaultKeyBundle {
  const VaultKeyBundle({
    required this.params,
    required this.salt,
    required this.wrappedDek,
    this.keyId,
    this.version = 1,
  });

  final int version;

  /// Stable random id of the data key (not derived from it). Survives PIN
  /// changes and KDF upgrades, so backups can tell whether their vault rows
  /// were encrypted with this device's key.
  final String? keyId;
  final KdfParams params;
  final Uint8List salt;

  /// nonce ‖ AES-GCM(KEK, DEK) ‖ tag.
  final Uint8List wrappedDek;

  Map<String, Object> toJson() => {
    'v': version,
    'kdf': params.toJson(),
    'salt': CryptoBytes.toBase64(salt),
    'dek': CryptoBytes.toBase64(wrappedDek),
    'kid': ?keyId,
  };

  factory VaultKeyBundle.fromJson(Map<String, Object?> json) => VaultKeyBundle(
    version: (json['v'] as num?)?.toInt() ?? 1,
    params: KdfParams.fromJson((json['kdf']! as Map).cast<String, Object?>()),
    salt: CryptoBytes.fromBase64(json['salt']! as String),
    wrappedDek: CryptoBytes.fromBase64(json['dek']! as String),
    keyId: json['kid'] as String?,
  );

  String encode() => jsonEncode(toJson());

  static VaultKeyBundle decode(String text) => VaultKeyBundle.fromJson(
    (jsonDecode(text) as Map).cast<String, Object?>(),
  );
}

/// Whether this device has a vault key.
enum VaultKeyStatus {
  /// No key bundle stored.
  absent,

  /// A parseable key bundle.
  ready,

  /// A bundle is stored but cannot be parsed (corrupt / unknown format).
  unreadable,
}

/// The stored key bundle exists but cannot be parsed.
class VaultKeyUnreadableException implements Exception {
  const VaultKeyUnreadableException();

  @override
  String toString() => 'VaultKeyUnreadableException';
}

/// A recovery code that was generated but not yet stored (two-phase:
/// shown / shared first, committed once the user saved it).
@immutable
class PendingRecoveryCode {
  const PendingRecoveryCode._(this.code, this._record);

  /// `XXXX-XXXX-…` (show / print this).
  final String code;
  final String _record;

  @override
  String toString() => 'PendingRecoveryCode(<redacted>)';
}

/// Outcome of reading the biometric copy.
enum BiometricCopyStatus {
  /// [BiometricCopyRead.key] is the data key.
  unlocked,

  /// The OS prompt was cancelled / failed; the copy is kept.
  cancelled,

  /// No copy, or it was invalidated (biometrics re-enrolled) / unreadable.
  missing,
}

class BiometricCopyRead {
  const BiometricCopyRead(this.status, [this.key]);

  final BiometricCopyStatus status;
  final VaultKey? key;
}

class VaultKeyManager {
  VaultKeyManager({
    required VaultSecretStorage storage,
    required VaultSecretStorage biometricStorage,
    VaultSecretStorage? legacyBiometricStorage,
    PinKdf kdf = const Argon2PinKdf(),
    this.targetParams = KdfParams.recommended,
    this.calibrate = false,
  }) : _store = storage,
       _bio = biometricStorage,
       _legacyBio = legacyBiometricStorage,
       _kdf = kdf; // ignore: prefer_initializing_formals

  static const String bundleKey = 'vault.bundle';
  static const String recoveryKey = 'vault.recovery';
  static const String biometricKey = 'vault.bio.dek';

  /// Non-secret marker in the main store: an OS-gated biometric copy
  /// exists (checking the copy itself would show the system prompt).
  static const String biometricMarkerKey = 'vault.bio.os';

  /// The master PIN is exactly this many digits.
  static const int pinLength = 6;

  final VaultSecretStorage _store;
  final VaultSecretStorage _bio;
  final VaultSecretStorage? _legacyBio;
  final PinKdf _kdf;

  /// Parameters for new wraps (set-up, PIN change, upgrades) — the ceiling
  /// when [calibrate] is on.
  final KdfParams targetParams;

  /// Time a probe on this device before the first wrap and use the
  /// strongest parameters that fit ~0.75 s ([KdfCalibration]); bundles are
  /// then only upgraded when below [KdfParams.minimum]. Off in tests.
  final bool calibrate;

  KdfParams? _calibrated;

  Future<KdfParams> _newWrapParams() async {
    if (!calibrate) return targetParams;
    return _calibrated ??= await KdfCalibration.measure(
      _kdf,
      ceiling: targetParams,
    );
  }

  bool _needsUpgrade(KdfParams stored) =>
      stored.isWeakerThan(calibrate ? KdfParams.minimum : targetParams);

  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  /// Very common PINs that an attacker tries first.
  static const Set<String> _commonPins = {
    '121212',
    '112233',
    '123123',
    '123321',
    '654321',
    '696969',
    '159753',
    '147258',
    '102030',
    '101010',
    '131313',
    '252525',
    '111222',
    '232323',
    '789456',
    '456789',
    '010203',
    '520520',
    '123654',
    '999888',
  };

  /// Why [pin] is too easy to guess (null = acceptable): all one digit,
  /// a straight run up or down (123456, 987654, 901234 …) or one of the
  /// most common PINs. Checked when a PIN is chosen (set-up, change,
  /// reset), never when one is entered to unlock.
  static String? weakPinReason(String pin) {
    if (!isValidPin(pin)) return 'Use exactly $pinLength digits';
    final d = pin.codeUnits.map((c) => c - 48).toList();
    if (d.every((x) => x == d.first)) return 'Avoid repeating one digit';
    bool run(int step) {
      for (var i = 1; i < d.length; i++) {
        if ((d[i - 1] + step) % 10 != d[i]) return false;
      }
      return true;
    }

    if (run(1) || run(9)) return 'Avoid digits in sequence';
    if (_commonPins.contains(pin)) return 'That PIN is too common';
    return null;
  }

  /// Parsed bundle; null when absent; throws [VaultKeyUnreadableException]
  /// when one is stored but cannot be parsed.
  Future<VaultKeyBundle?> _bundle() async {
    final raw = await _store.read(bundleKey);
    if (raw == null) return null;
    try {
      return VaultKeyBundle.decode(raw);
    } on Object {
      throw const VaultKeyUnreadableException();
    }
  }

  Future<VaultKeyBundle?> _bundleOrNull() async {
    try {
      return await _bundle();
    } on VaultKeyUnreadableException {
      return null;
    }
  }

  /// Absent / ready / unreadable. Storage errors propagate.
  Future<VaultKeyStatus> status() async {
    try {
      return await _bundle() == null
          ? VaultKeyStatus.absent
          : VaultKeyStatus.ready;
    } on VaultKeyUnreadableException {
      return VaultKeyStatus.unreadable;
    }
  }

  /// True when ANY bundle is stored (also an unreadable one): set-up must
  /// never overwrite it.
  Future<bool> isSetUp() async => await _store.read(bundleKey) != null;

  /// The stored KDF parameters (null when no / an unreadable vault).
  Future<KdfParams?> storedParams() async => (await _bundleOrNull())?.params;

  /// The data key's stable id (null when no / an unreadable vault).
  Future<String?> keyId() async => (await _bundleOrNull())?.keyId;

  Future<VaultKeyBundle> _wrap(VaultKey key, String pin, String? keyId) async {
    final params = await _newWrapParams();
    final salt = CryptoBytes.random(16);
    final kek = await _kdf.deriveKek(pin, salt, params);
    final wrapped = await VaultCipher.seal(
      kek,
      key.exportBytes(),
      aad: VaultAad.dek,
    );
    return VaultKeyBundle(
      params: params,
      salt: salt,
      wrappedDek: wrapped,
      keyId: keyId ?? CryptoBytes.toHex(CryptoBytes.random(16)),
    );
  }

  /// Creates a new vault: random DEK wrapped by [pin]. Fails if one exists
  /// (call [wipe] first to start over).
  Future<VaultKey> setUp(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be 6 digits');
    // Also refuses over an unreadable bundle (its ciphertext would be lost).
    if (await isSetUp()) throw StateError('Vault already set up');
    final key = await VaultKey.generate();
    await _store.write(bundleKey, (await _wrap(key, pin, null)).encode());
    return key;
  }

  /// Unwraps the DEK with [pin]; null when the PIN is wrong or no vault
  /// exists (throws [VaultKeyUnreadableException] for a corrupt bundle —
  /// that is not a wrong PIN). Re-wraps when the stored cost is below the target
  /// ([targetParams], or [KdfParams.minimum] when calibrating).
  Future<VaultKey?> unlockWithPin(String pin) async {
    final bundle = await _bundle();
    if (bundle == null || !isValidPin(pin)) return null;
    final key = await _open(bundle, pin);
    if (key == null) return null;
    if (_needsUpgrade(bundle.params)) {
      await _store.write(
        bundleKey,
        (await _wrap(key, pin, bundle.keyId)).encode(),
      );
    }
    return key;
  }

  Future<VaultKey?> _open(VaultKeyBundle bundle, String pin) async {
    final kek = await _kdf.deriveKek(pin, bundle.salt, bundle.params);
    try {
      final dek = await VaultCipher.open(
        kek,
        bundle.wrappedDek,
        aad: VaultAad.dek,
      );
      final key = await VaultKey.fromBytes(dek);
      CryptoBytes.wipe(dek);
      return key;
    } on VaultCryptoException {
      return null;
    }
  }

  /// True when [pin] is the current master PIN (re-auth before settings
  /// changes). Does not upgrade or change anything.
  Future<bool> verifyPin(String pin) async {
    final bundle = await _bundle();
    if (bundle == null || !isValidPin(pin)) return false;
    final key = await _open(bundle, pin);
    key?.destroy();
    return key != null;
  }

  /// Re-wraps the current DEK ([key]) under [newPin]. Vault items are NOT
  /// re-encrypted — they stay readable with the same DEK.
  Future<void> changePin(VaultKey key, String newPin) async {
    if (!isValidPin(newPin)) throw ArgumentError('PIN must be 6 digits');
    final bundle = await _bundle();
    if (bundle == null) throw StateError('No vault');
    await _store.write(
      bundleKey,
      (await _wrap(key, newPin, bundle.keyId)).encode(),
    );
  }

  /// Forgotten PIN: re-wraps [key] (opened with the recovery code) under
  /// [newPin] — also when the stored bundle is unreadable or gone, which
  /// repairs it. The key id is kept when it can still be read.
  Future<void> resetPin(VaultKey key, String newPin) async {
    if (!isValidPin(newPin)) throw ArgumentError('PIN must be 6 digits');
    final keyId = await _salvageKeyId();
    await _store.write(bundleKey, (await _wrap(key, newPin, keyId)).encode());
  }

  Future<String?> _salvageKeyId() async {
    try {
      final raw = await _store.read(bundleKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      return json is Map && json['kid'] is String
          ? json['kid'] as String
          : null;
    } on Object {
      return null;
    }
  }

  // ───────────────────────────── Biometrics ─────────────────────────────

  bool get _osGated => _bio is OsGatedVaultStorage;

  /// True when the biometric store is OS-gated (reading it IS the
  /// biometric check — no separate local_auth prompt needed).
  bool get biometricCopyIsOsGated => _osGated;

  /// True when writing the copy shows the system prompt (Android).
  bool get biometricWritePrompts {
    final bio = _bio;
    return bio is OsGatedVaultStorage && bio.writePrompts;
  }

  /// Whether a biometric copy exists (never prompts): the OS-gated copy's
  /// marker, an app-gated copy, or a legacy copy awaiting migration.
  Future<bool> hasBiometricCopy() async =>
      await _hasCurrentCopy() || await hasLegacyBiometricCopy();

  Future<bool> _hasCurrentCopy() async => _osGated
      ? await _store.read(biometricMarkerKey) != null
      : await _bio.read(biometricKey) != null;

  /// A pre-OS-gating copy is still stored (migrated on the next unlock).
  Future<bool> hasLegacyBiometricCopy() async {
    final legacy = _legacyBio;
    if (legacy == null) return false;
    try {
      return await legacy.read(biometricKey) != null;
    } on Object {
      return false;
    }
  }

  /// True when reading the copy needs the app's own local_auth check
  /// first (an app-gated / legacy copy). False for the OS-gated copy, whose
  /// read shows the system prompt itself.
  Future<bool> biometricReadNeedsAppGate() async =>
      !(_osGated && await _store.read(biometricMarkerKey) != null);

  /// Stores the biometric unlock copy of [key] (may show the system prompt
  /// on Android) and drops a legacy copy. False when the OS refused (no
  /// strong biometrics, prompt cancelled) — nothing is stored then.
  Future<bool> enableBiometrics(VaultKey key) async {
    try {
      await _bio.write(biometricKey, CryptoBytes.toBase64(key.exportBytes()));
      if (_osGated) await _store.write(biometricMarkerKey, '1');
    } on Object {
      await _safe(() => _store.delete(biometricMarkerKey));
      return false;
    }
    await _deleteLegacyCopy();
    return true;
  }

  /// Deletes every biometric copy (OS-gated, marker, legacy). Never throws;
  /// each deletion is attempted even if another fails.
  Future<void> disableBiometrics() async {
    await _safe(() => _bio.delete(biometricKey));
    await _safe(() => _store.delete(biometricMarkerKey));
    await _deleteLegacyCopy();
  }

  /// Deletes only the legacy app-gated copy (after its migration).
  Future<void> disableLegacyBiometrics() => _deleteLegacyCopy();

  Future<void> _deleteLegacyCopy() async {
    final legacy = _legacyBio;
    if (legacy != null) await _safe(() => legacy.delete(biometricKey));
  }

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Best effort (keystore unavailable); retried on the next refresh.
    }
  }

  /// Reads the biometric copy. For an OS-gated copy this shows the system
  /// prompt; otherwise call it ONLY after BiometricAuth succeeded.
  Future<BiometricCopyRead> readBiometricCopy() async {
    if (await status() != VaultKeyStatus.ready) {
      return const BiometricCopyRead(BiometricCopyStatus.missing);
    }
    String? raw;
    try {
      if (!await biometricReadNeedsAppGate()) {
        raw = await _bio.read(biometricKey);
      } else {
        raw = _osGated ? null : await _bio.read(biometricKey);
        final legacy = _legacyBio;
        if (raw == null && legacy != null) {
          raw = await legacy.read(biometricKey);
        }
      }
    } on BiometricReadException {
      return const BiometricCopyRead(BiometricCopyStatus.cancelled);
    } on Object {
      return const BiometricCopyRead(BiometricCopyStatus.missing);
    }
    if (raw == null) {
      return const BiometricCopyRead(BiometricCopyStatus.missing);
    }
    try {
      final bytes = CryptoBytes.fromBase64(raw);
      final key = await VaultKey.fromBytes(bytes);
      CryptoBytes.wipe(bytes);
      return BiometricCopyRead(BiometricCopyStatus.unlocked, key);
    } on Object {
      return const BiometricCopyRead(BiometricCopyStatus.missing);
    }
  }

  /// Reads the biometric copy (null unless unlocked). Compatibility wrapper
  /// around [readBiometricCopy].
  Future<VaultKey?> unlockWithBiometricCopy() async =>
      (await readBiometricCopy()).key;

  // ───────────────────────────── Recovery ──────────────────────────────

  Future<bool> hasRecoveryCode() async =>
      await _store.read(recoveryKey) != null;

  /// Generates a recovery code for [key] WITHOUT storing it: the current
  /// code keeps working until [commitRecoveryCode] (after the user saved
  /// the new one). Formatted as `XXXX-XXXX-…` (8 groups, base32, 160 bits).
  Future<PendingRecoveryCode> prepareRecoveryCode(VaultKey key) async {
    final code = CryptoBytes.random(20);
    final salt = CryptoBytes.random(16);
    final kek = await _recoveryKek(code, salt);
    final wrapped = await VaultCipher.seal(
      kek,
      key.exportBytes(),
      aad: VaultAad.recovery,
    );
    final record = jsonEncode({
      'v': 1,
      'salt': CryptoBytes.toBase64(salt),
      'dek': CryptoBytes.toBase64(wrapped),
    });
    final text = CryptoBytes.toBase32(code);
    CryptoBytes.wipe(code);
    return PendingRecoveryCode._(formatRecoveryCode(text), record);
  }

  /// Stores [pending], replacing (invalidating) any older code.
  Future<void> commitRecoveryCode(PendingRecoveryCode pending) =>
      _store.write(recoveryKey, pending._record);

  /// [prepareRecoveryCode] + [commitRecoveryCode] in one step (first code,
  /// when there is nothing to lose).
  Future<String> createRecoveryCode(VaultKey key) async {
    final pending = await prepareRecoveryCode(key);
    await commitRecoveryCode(pending);
    return pending.code;
  }

  /// `ABCDEFGH…` → `ABCD-EFGH-…`.
  static String formatRecoveryCode(String raw) {
    final clean = raw.toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '');
    final groups = <String>[];
    for (var i = 0; i < clean.length; i += 4) {
      groups.add(clean.substring(i, (i + 4).clamp(0, clean.length)));
    }
    return groups.join('-');
  }

  /// Unwraps the DEK with a recovery code (forgotten PIN). Null if wrong.
  Future<VaultKey?> unlockWithRecoveryCode(String code) async {
    final raw = await _store.read(recoveryKey);
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      final bytes = CryptoBytes.fromBase32(code);
      if (bytes.length != 20) return null;
      final kek = await _recoveryKek(
        bytes,
        CryptoBytes.fromBase64(json['salt']! as String),
      );
      final dek = await VaultCipher.open(
        kek,
        CryptoBytes.fromBase64(json['dek']! as String),
        aad: VaultAad.recovery,
      );
      final key = await VaultKey.fromBytes(dek);
      CryptoBytes.wipe(dek);
      return key;
    } on Object {
      return null;
    }
  }

  // The code has 160 bits of entropy, so a fast KDF (HKDF) is enough.
  Future<SecretKey> _recoveryKek(List<int> code, List<int> salt) =>
      DartHkdf(hmac: DartHmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKeyData(code),
        nonce: salt,
        info: utf8.encode('ff.vault.recovery.v1'),
      );

  // ─────────────────────────── Backup / wipe ───────────────────────────

  /// The PIN-wrapped key bundle for backups (safe to export: useless
  /// without the PIN). Null when no vault exists.
  Future<VaultKeyBundle?> exportBundle() => _bundleOrNull();

  /// Installs a bundle from a backup after checking [pin] opens it.
  /// Returns false (and changes nothing) when the PIN does not match.
  Future<bool> importBundle(VaultKeyBundle bundle, String pin) async {
    final key = await _open(bundle, pin);
    if (key == null) return false;
    key.destroy();
    await _store.write(bundleKey, bundle.encode());
    await disableBiometrics();
    await _store.delete(recoveryKey);
    return true;
  }

  /// Adopts a backup's bundle on a device that has no vault yet, so the
  /// backup's PIN opens the restored items. No PIN is needed: the bundle
  /// stays PIN-wrapped. Returns false (changing nothing) when a vault
  /// already exists.
  Future<bool> adoptBundle(VaultKeyBundle bundle) async {
    if (await isSetUp()) return false;
    await _store.write(bundleKey, bundle.encode());
    await disableBiometrics();
    await _store.delete(recoveryKey);
    return true;
  }

  /// Replaces this device's key with a backup's [bundle] — only for a vault
  /// that holds no items yet (the caller checks), so nothing readable is
  /// lost. The bundle stays PIN-wrapped: the backup's PIN opens it from now
  /// on. Biometric copy and recovery code of the old key are dropped.
  Future<void> replaceEmptyVaultKey(VaultKeyBundle bundle) async {
    await _store.write(bundleKey, bundle.encode());
    await disableBiometrics();
    await _store.delete(recoveryKey);
  }

  /// Deletes every piece of key material. Existing ciphertext becomes
  /// permanently unreadable.
  Future<void> wipe() async {
    await _store.delete(bundleKey);
    await _store.delete(recoveryKey);
    await disableBiometrics();
  }
}
