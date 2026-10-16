/// ============================================================
/// VAULT KEY — the unwrapped data key, alive only while the vault is open
/// ============================================================
///
/// Holds the random 256-bit data key (DEK) that encrypts every vault blob,
/// plus a sub-key derived from it with HKDF-SHA256 for password
/// fingerprints. Created by VaultKeyManager on unlock, dropped (and
/// best-effort zeroed) by the vault session on lock. Never serialised,
/// never logged: [toString] is redacted.
///
/// ## Password fingerprints (reuse detection)
/// `HMAC-SHA256(fingerprintKey, password)` as hex. Equal passwords give
/// equal fingerprints, so the security report can count reused passwords
/// from the cached column without decrypting anything — and because the
/// HMAC key is secret (derived from the DEK), the stored fingerprint is not
/// a password hash an attacker could brute-force offline.
/// ============================================================
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:focusflow/core/crypto/crypto_bytes.dart';

class VaultKey {
  VaultKey._(this._dek, this._fingerprintKey);

  /// Wraps [dek] (32 bytes; copied) and derives the fingerprint sub-key.
  static Future<VaultKey> fromBytes(List<int> dek) async {
    if (dek.length != 32) {
      throw ArgumentError('Vault data key must be 32 bytes');
    }
    final copy = Uint8List.fromList(dek);
    final sub = await DartHkdf(hmac: DartHmac.sha256(), outputLength: 32)
        .deriveKey(
          secretKey: SecretKeyData(copy),
          nonce: const [],
          info: utf8.encode('ff.vault.fingerprint.v1'),
        );
    return VaultKey._(copy, Uint8List.fromList(await sub.extractBytes()));
  }

  /// A brand-new random data key (vault set-up).
  static Future<VaultKey> generate() => fromBytes(CryptoBytes.random(32));

  final Uint8List _dek;
  final Uint8List _fingerprintKey;
  bool _destroyed = false;

  bool get isDestroyed => _destroyed;

  /// The DEK for [VaultCipher] calls.
  SecretKey get secretKey {
    _check();
    return SecretKeyData(_dek);
  }

  /// Raw DEK bytes (copy) — only for wrapping by the key manager.
  Uint8List exportBytes() {
    _check();
    return Uint8List.fromList(_dek);
  }

  /// Keyed fingerprint of [password] (hex), for reuse detection.
  String fingerprint(String password) {
    _check();
    final mac = hash.Hmac(
      hash.sha256,
      _fingerprintKey,
    ).convert(utf8.encode(password));
    return mac.toString();
  }

  /// Zeroes the key material we hold. The key is unusable afterwards.
  void destroy() {
    CryptoBytes.wipe(_dek);
    CryptoBytes.wipe(_fingerprintKey);
    _destroyed = true;
  }

  void _check() {
    if (_destroyed) throw StateError('Vault key was destroyed (vault locked)');
  }

  @override
  String toString() => 'VaultKey(<redacted>)';
}
