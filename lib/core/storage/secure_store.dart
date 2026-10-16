/// ============================================================
/// SECURE STORE — Keychain (iOS) / Keystore-backed prefs (Android)
/// ============================================================
///
/// One configured [FlutterSecureStorage] for the whole app, plus the
/// database key. Items are readable after the first unlock so background
/// work (auto backup, notification actions) can open the encrypted DB.
///
/// Keys stored here:
///   db.key            random 256-bit SQLite key (hex)
///   vault.*           wrapped vault data key + KDF params (core/crypto)
///   account.*         signed-in Google / Apple profile (no tokens —
///                     google_sign_in keeps its own)
/// ============================================================
library;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  static const String databaseKey = 'db.key';

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  /// Where a malformed database key is moved before a new one is made.
  static const String damagedDatabaseKey = 'db.key.damaged';

  /// Returns the SQLite key, generating and persisting one only when none
  /// exists (first launch).
  ///
  /// A keychain *failure* (locked before first unlock, plugin error) throws
  /// [DatabaseKeyUnavailable] — making a new key then would orphan the
  /// user's encrypted database. A stored value that is not a key is kept
  /// under [damagedDatabaseKey] (never overwritten) before a new key is
  /// made; the unreadable database is quarantined by EncryptedDatabase.
  /// A new key that could not be saved also throws, so the app never runs
  /// on a key it will not have next launch.
  Future<String> getOrCreateDatabaseKey() async {
    final String? existing;
    try {
      existing = await read(databaseKey);
    } on Object catch (e) {
      throw DatabaseKeyUnavailable(e.runtimeType.toString());
    }
    if (existing != null && isValidDatabaseKey(existing)) return existing;
    try {
      if (existing != null) await write(damagedDatabaseKey, existing);
      final key = randomHex(32);
      await write(databaseKey, key);
      return key;
    } on Object catch (e) {
      throw DatabaseKeyUnavailable(e.runtimeType.toString());
    }
  }

  /// A stored key as written by [randomHex] (64 characters). Kept as
  /// lenient as before so no key that ever worked is treated as damaged.
  static bool isValidDatabaseKey(String key) => key.length == 64;

  /// [bytes] cryptographically secure random bytes as lower-case hex.
  static String randomHex(int bytes) {
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

/// The database key could not be read from (or saved to) the keychain.
class DatabaseKeyUnavailable implements Exception {
  const DatabaseKeyUnavailable([this.detail]);

  /// Error type for logs (never the key).
  final String? detail;

  @override
  String toString() =>
      'DatabaseKeyUnavailable${detail == null ? '' : ' ($detail)'}';
}
