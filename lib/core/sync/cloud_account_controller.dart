/// ============================================================
/// CLOUD ACCOUNT CONTROLLER — Google (Drive) / Apple sign-in, sign-out
/// ============================================================
///
/// Implements the [CloudAccountController] contract (cloud_account.dart)
/// over the plugin gateways (google_account.dart):
/// * Google: interactive sign-in + `drive.appdata` consent; the profile is
///   saved in the keychain ([AccountStore]) and Settings' accountMode is
///   set to google. google_sign_in keeps its own credentials; Drive tokens
///   are fetched on demand ([DriveTokenSource]) and never stored.
/// * Apple (iOS): profile only — no Drive. Apple shares the email/name
///   only on the first sign-in, so a later sign-in keeps the stored ones.
/// * Sign out forgets the profile and the Drive sync bookkeeping (merged
///   backups, last sync time); local data stays. `revoke` also removes
///   the Drive grant ("Delete account & Drive data").
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/account_store.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_sync_state.dart';
import 'package:focusflow/core/sync/google_account.dart';
import 'package:focusflow/core/sync/google_drive_store.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The current account. Starts null and loads the stored profile once
/// (keychain read, milliseconds); [loaded] completes when it has.
class CloudAccountNotifier extends Notifier<CloudAccount?> {
  final Completer<CloudAccount?> _loaded = Completer();
  bool _changed = false;

  /// The stored account, once read (background jobs await this).
  Future<CloudAccount?> get loaded => _loaded.future;

  @override
  CloudAccount? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    final stored = await ref.read(accountStoreProvider).read();
    // A sign-in that finished first wins over the stored profile.
    if (!_changed) state = stored;
    if (!_loaded.isCompleted) _loaded.complete(state);
  }

  /// Called by the controller after sign-in / sign-out.
  void set(CloudAccount? account) {
    _changed = true;
    state = account;
    if (!_loaded.isCompleted) _loaded.complete(account);
  }
}

class GoogleCloudAccountController
    implements CloudAccountController, DriveTokenSource {
  GoogleCloudAccountController(this._ref);

  final Ref _ref;

  GoogleAuthGateway get _google => _ref.read(googleAuthGatewayProvider);
  AppleAuthGateway get _apple => _ref.read(appleAuthGatewayProvider);
  AccountStore get _store => _ref.read(accountStoreProvider);

  @override
  bool get googleAvailable => _ref.read(googleConfigProvider).isConfigured;

  @override
  bool get appleAvailable => _apple.isAvailable;

  @override
  Future<CloudAccount?> signInWithGoogle() async {
    if (!googleAvailable) {
      throw const CloudAuthException(
        'Google Drive is not set up in this build',
      );
    }
    final p = await _google.signIn();
    if (p == null) return null;
    final account = CloudAccount(
      provider: CloudProvider.google,
      email: p.email,
      displayName: p.displayName,
      photoUrl: p.photoUrl,
    );
    await _save(account, AccountMode.google);
    return account;
  }

  @override
  Future<CloudAccount?> signInWithApple() async {
    if (!appleAvailable) return null;
    final r = await _apple.signIn();
    if (r == null) return null;
    final previous = await _store.read();
    final same = previous?.provider == CloudProvider.apple ? previous : null;
    final account = CloudAccount(
      provider: CloudProvider.apple,
      email: r.email ?? same?.email ?? 'Apple ID',
      displayName: r.name ?? same?.displayName,
    );
    await _save(account, AccountMode.apple);
    return account;
  }

  @override
  Future<void> signOut({bool revoke = false}) async {
    final current = _ref.read(cloudAccountProvider);
    if (current?.provider == CloudProvider.google || revoke) {
      try {
        await _google.signOut(revoke: revoke);
      } catch (_) {
        // Offline / plugin error: forgetting the profile locally is enough.
      }
    }
    await _store.clear();
    _ref.read(cloudAccountProvider.notifier).set(null);
    await forgetSyncState(_ref);
    await _ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(accountMode: AccountMode.offline));
  }

  Future<void> _save(CloudAccount account, AccountMode mode) async {
    try {
      await _store.write(account);
    } catch (_) {
      // No keychain (tests / simulator glitches): still signed in for now.
    }
    _ref.read(cloudAccountProvider.notifier).set(account);
    final name = account.displayName;
    await _ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            accountMode: mode,
            displayName: s.displayName.isEmpty && name != null ? name : null,
          ),
        );
  }

  // ── DriveTokenSource ──

  @override
  Future<String?> token({bool interactive = false}) =>
      _google.accessToken(interactive: interactive);

  @override
  Future<void> invalidate(String token) => _google.clearToken(token);
}

/// Forgets this device's Drive sync bookkeeping — which other-device
/// backups were merged, a pending Restore / Start fresh choice and the
/// last sync time — after sign-out, erase or a different account: it
/// described a Drive (or data) this device no longer uses.
Future<void> forgetSyncState(Ref ref) async {
  try {
    await DriveSyncState(ref.read(sharedPreferencesProvider)).clear();
    await ref.read(syncStatusProvider.notifier).forgetLastSync();
  } on Object {
    // Prefs unavailable: nothing was stored either.
  }
}

// ───────────────────────────── Providers ─────────────────────────────

/// OAuth client ids from --dart-define (override in tests).
final googleConfigProvider = Provider<GoogleConfig>(
  (ref) => GoogleConfig.fromEnvironment(),
);

final googleAuthGatewayProvider = Provider<GoogleAuthGateway>(
  (ref) => PluginGoogleAuthGateway(ref.watch(googleConfigProvider)),
);

final appleAuthGatewayProvider = Provider<AppleAuthGateway>(
  (ref) => const PluginAppleAuthGateway(),
);

final accountStoreProvider = Provider<AccountStore>(
  (ref) => AccountStore(ref.watch(secureStoreProvider)),
);
