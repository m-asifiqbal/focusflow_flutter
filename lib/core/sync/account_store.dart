/// ============================================================
/// ACCOUNT STORE — the signed-in profile, kept in the keychain
/// ============================================================
///
/// Only the *profile* (provider, email, name, photo URL) is stored, under
/// `account.profile` in [SecureStore]. Never tokens: google_sign_in keeps
/// its own credentials and hands out short-lived access tokens on demand,
/// and Sign in with Apple is profile-only.
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/sync/cloud_account.dart';

class AccountStore {
  AccountStore(this._secure);

  final SecureStore _secure;

  static const String storageKey = 'account.profile';

  /// The stored profile, or null (signed out / unreadable / no keychain,
  /// e.g. in widget tests).
  Future<CloudAccount?> read() async {
    try {
      final raw = await _secure.read(storageKey);
      if (raw == null) return null;
      return decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(CloudAccount account) =>
      _secure.write(storageKey, encode(account));

  Future<void> clear() async {
    try {
      await _secure.delete(storageKey);
    } catch (_) {
      // Nothing stored / no keychain: already signed out.
    }
  }

  static String encode(CloudAccount a) => jsonEncode({
    'provider': a.provider.name,
    'email': a.email,
    'displayName': a.displayName,
    'photoUrl': a.photoUrl,
  });

  /// Null for anything that is not a stored profile.
  static CloudAccount? decode(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final provider = CloudProvider.values.firstWhere(
        (p) => p.name == j['provider'],
      );
      return CloudAccount(
        provider: provider,
        email: j['email']! as String,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
