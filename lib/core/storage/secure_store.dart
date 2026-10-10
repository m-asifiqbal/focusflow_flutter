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

  /// Returns the SQLite key, generating and persisting one on first launch.
  Future<String> getOrCreateDatabaseKey() async {
    final existing = await read(databaseKey);
    if (existing != null && existing.length == 64) return existing;
    final key = randomHex(32);
    await write(databaseKey, key);
    return key;
  }

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
