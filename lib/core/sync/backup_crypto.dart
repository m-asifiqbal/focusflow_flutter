/// ============================================================
/// BACKUP CRYPTO — optional .ffbackup encryption (Argon2id → AES-256-GCM)
/// ============================================================
///
/// Self-contained (independent of the vault session): the master PIN is
/// stretched with Argon2id into a 256-bit key; `db.json` and every
/// attachment are sealed with AES-256-GCM (fresh 96-bit nonce each,
/// stored as nonce ‖ ciphertext ‖ 128-bit tag). The KDF parameters and
/// salt travel in the plaintext manifest, so any device can restore with
/// the PIN alone. A wrong PIN fails the GCM tag check → [WrongBackupPin].
///
/// Background auto-backups cannot ask for the PIN, so the derived key (not
/// the PIN) is kept in the keychain by [BackupKeyStore] while "Encrypt
/// backups" is on. Never log keys or PINs.
/// ============================================================
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/argon2_runner.dart';
import 'package:focusflow/core/storage/secure_store.dart';

/// The PIN did not open the backup (GCM authentication failed).
class WrongBackupPin implements Exception {
  const WrongBackupPin();

  @override
  String toString() => 'WrongBackupPin';
}

/// Argon2id parameters + salt, written to `manifest.json › encryption`.
@immutable
class BackupKdfParams {
  const BackupKdfParams({
    required this.salt,
    this.memoryKiB = defaultMemoryKiB,
    this.iterations = defaultIterations,
    this.parallelism = 1,
  });

  /// OWASP 2023 minimum for Argon2id: m = 19 MiB, t = 2, p = 1.
  static const int defaultMemoryKiB = 19 * 1024;
  static const int defaultIterations = 2;

  final Uint8List salt;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  static BackupKdfParams generate({
    int memoryKiB = defaultMemoryKiB,
    int iterations = defaultIterations,
  }) {
    final rnd = Random.secure();
    return BackupKdfParams(
      salt: Uint8List.fromList(List.generate(16, (_) => rnd.nextInt(256))),
      memoryKiB: memoryKiB,
      iterations: iterations,
    );
  }

  Map<String, Object?> toJson() => {
    'cipher': 'AES-256-GCM',
    'kdf': 'argon2id',
    'salt': base64Encode(salt),
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
  };

  /// Reads the manifest's `encryption` block. The cost comes from the
  /// FILE, so anything this app would never have written (a damaged or
  /// crafted backup asking for gigabytes) is refused up front instead of
  /// being attempted.
  static BackupKdfParams fromJson(Map<String, Object?> j) {
    if (j['kdf'] != 'argon2id' || j['cipher'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported backup encryption');
    }
    final params = BackupKdfParams(
      salt: base64Decode(j['salt']! as String),
      memoryKiB: (j['memoryKiB']! as num).toInt(),
      iterations: (j['iterations']! as num).toInt(),
      parallelism: (j['parallelism'] as num?)?.toInt() ?? 1,
    );
    if (!Argon2Runner.accept(
      memoryKiB: params.memoryKiB,
      iterations: params.iterations,
      parallelism: params.parallelism,
    )) {
      throw const FormatException('Unsupported backup encryption');
    }
    return params;
  }

  @override
  bool operator ==(Object other) =>
      other is BackupKdfParams &&
      listEquals(other.salt, salt) &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(salt), memoryKiB, iterations, parallelism);
}

/// A derived backup key with the parameters that produced it.
@immutable
class BackupKey {
  const BackupKey(this.params, this.keyBytes);

  final BackupKdfParams params;
  final Uint8List keyBytes;
}

abstract final class BackupCipher {
  static final AesGcm _aes = AesGcm.with256bits();

  /// Argon2id(PIN, salt) → 32-byte key, computed by [Argon2Runner] (own
  /// isolate, validated cost, time limit). Throws [Argon2Failure] when the
  /// phone cannot finish it — never [WrongBackupPin]: whether the PIN is
  /// right is only known when the key opens the data.
  static Future<BackupKey> deriveKey(String pin, BackupKdfParams params) async {
    final bytes = await Argon2Runner.derive(
      password: utf8.encode(pin),
      salt: params.salt,
      memoryKiB: params.memoryKiB,
      iterations: params.iterations,
      parallelism: params.parallelism,
    );
    return BackupKey(params, bytes);
  }

  /// nonce(12) ‖ ciphertext ‖ tag(16).
  static Future<Uint8List> seal(List<int> plain, BackupKey key) async {
    final box = await _aes.encrypt(
      plain,
      secretKey: SecretKey(key.keyBytes),
      nonce: _aes.newNonce(),
    );
    return box.concatenation();
  }

  /// Payloads from this size on are decrypted on a background isolate:
  /// pure-Dart AES-GCM does a few MB per second, and a restore decrypts the
  /// whole database plus every attachment — on the UI isolate that froze the
  /// "Restoring…" dialog (and an ANR if the user touched the screen).
  static const int isolateThreshold = 256 * 1024;

  /// Opens [sealed]; throws [WrongBackupPin] when the key is wrong or the
  /// data was tampered with.
  static Future<Uint8List> open(List<int> sealed, BackupKey key) async {
    if (sealed.length >= isolateThreshold) {
      final bytes = Uint8List.fromList(sealed);
      final keyBytes = key.keyBytes;
      return Isolate.run(() => _openSync(bytes, keyBytes));
    }
    return _openSync(sealed, key.keyBytes);
  }

  static Future<Uint8List> _openSync(
    List<int> sealed,
    List<int> keyBytes,
  ) async {
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
        copy: false,
      );
      final plain = await _aes.decrypt(box, secretKey: SecretKey(keyBytes));
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const WrongBackupPin();
    } on ArgumentError {
      throw const WrongBackupPin();
    }
  }
}

/// Keeps the derived backup key in the keychain while "Encrypt backups" is
/// on (so scheduled backups can encrypt without asking for the PIN).
class BackupKeyStore {
  BackupKeyStore(this._secure);

  final SecureStore _secure;

  static const String storageKey = 'backup.key';

  /// Derives a key from [pin] with fresh salt and stores it.
  Future<BackupKey> enable(String pin, {BackupKdfParams? params}) async {
    final key = await BackupCipher.deriveKey(
      pin,
      params ?? BackupKdfParams.generate(),
    );
    await _secure.write(
      storageKey,
      jsonEncode({
        'params': key.params.toJson(),
        'key': base64Encode(key.keyBytes),
      }),
    );
    return key;
  }

  /// The stored key, or null when encryption was never set up.
  Future<BackupKey?> current() async {
    try {
      final raw = await _secure.read(storageKey);
      if (raw == null) return null;
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      return BackupKey(
        BackupKdfParams.fromJson((j['params']! as Map).cast<String, Object?>()),
        base64Decode(j['key']! as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasKey() async => (await current()) != null;

  /// The master PIN changed: when "Encrypt backups" has a key, re-derives
  /// it from [newPin] with the SAME KDF parameters and salt (other devices
  /// share the salt), so every backup made from now on opens with the new
  /// PIN. Backups made before keep their manifest's salt and still need the
  /// PIN that was current when they were made. Returns true when a key was
  /// replaced (false: encryption off — nothing to do).
  Future<bool> rekey(String newPin) async {
    final old = await current();
    if (old == null) return false;
    await enable(newPin, params: old.params);
    return true;
  }

  Future<void> disable() => _secure.delete(storageKey);
}
