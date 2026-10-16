/// ============================================================
/// VAULT CIPHER — AES-256-GCM sealing with a fixed wire format
/// ============================================================
///
/// Every encrypted blob in the app (vault payloads, password history,
/// generator history, the wrapped data key itself) uses ONE format:
///
///     nonce (12 bytes) ‖ ciphertext ‖ GCM tag (16 bytes)
///
/// A fresh random 96-bit nonce is drawn for every seal, so the same
/// plaintext never produces the same blob and a (key, nonce) pair is never
/// reused (the birthday bound for 2^96 random nonces is far beyond the
/// number of items a person stores). The optional [aad] binds a blob to its
/// purpose ("item", "history", "dek" …): a blob sealed for one purpose
/// fails authentication when opened as another.
///
/// Opening a tampered / truncated blob or using the wrong key throws
/// [VaultCryptoException] — never returns garbage.
/// ============================================================
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Authentication failed (wrong key, tampered data) or malformed input.
class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);

  final String message;

  @override
  String toString() => 'VaultCryptoException: $message';
}

/// Associated-data labels — one per kind of blob.
abstract final class VaultAad {
  /// Legacy item label (v1): not bound to the row, so a blob could be
  /// moved to another item. Still accepted when opening (fallback).
  static final Uint8List item = _l('ff.vault.item.v1');

  /// Item label bound to the row id (v2): a blob copied onto another
  /// vault row fails authentication.
  static Uint8List itemFor(String itemId) => _l('ff.vault.item.v2:$itemId');
  static final Uint8List history = _l('ff.vault.history.v1');
  static final Uint8List generator = _l('ff.vault.generator.v1');
  static final Uint8List dek = _l('ff.vault.dek.v1');
  static final Uint8List recovery = _l('ff.vault.recovery.v1');
  static final Uint8List export = _l('ff.vault.export.v1');

  static Uint8List _l(String s) => Uint8List.fromList(utf8.encode(s));
}

abstract final class VaultCipher {
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int keyLength = 32;

  /// Pure-Dart AES-GCM: identical on every platform and in tests.
  static final AesGcm _aes = DartAesGcm(secretKeyLength: keyLength);

  /// Encrypts [plaintext] under the 256-bit [key].
  static Future<Uint8List> seal(
    SecretKey key,
    List<int> plaintext, {
    List<int> aad = const [],
  }) async {
    final box = await _aes.encrypt(
      plaintext,
      secretKey: key,
      nonce: _aes.newNonce(),
      aad: aad,
    );
    return box.concatenation();
  }

  /// Decrypts a blob produced by [seal]. Throws [VaultCryptoException] when
  /// the blob was tampered with, truncated, or sealed with another key/aad.
  static Future<Uint8List> open(
    SecretKey key,
    List<int> blob, {
    List<int> aad = const [],
  }) async {
    if (blob.length < nonceLength + macLength) {
      throw const VaultCryptoException('Ciphertext too short');
    }
    try {
      final box = SecretBox.fromConcatenation(
        blob,
        nonceLength: nonceLength,
        macLength: macLength,
        copy: true,
      );
      final clear = await _aes.decrypt(box, secretKey: key, aad: aad);
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoException('Authentication failed');
    }
  }

  /// UTF-8 convenience wrappers.
  static Future<Uint8List> sealString(
    SecretKey key,
    String text, {
    List<int> aad = const [],
  }) => seal(key, utf8.encode(text), aad: aad);

  static Future<String> openString(
    SecretKey key,
    List<int> blob, {
    List<int> aad = const [],
  }) async => utf8.decode(await open(key, blob, aad: aad));
}
