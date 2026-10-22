/// ============================================================
/// GOOGLE / APPLE SIGN-IN GATEWAYS — thin wrappers over the plugins
/// ============================================================
///
/// [GoogleAuthGateway] and [AppleAuthGateway] are the only code that talks
/// to google_sign_in 7 / sign_in_with_apple, so the account controller can
/// be tested with fakes. OAuth client ids come from the build:
///
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=…   (Android: required)
///   --dart-define=GOOGLE_IOS_CLIENT_ID=…      (iOS: required)
///
/// Without them [GoogleConfig.isConfigured] is false and the UI shows
/// "Google Drive is not set up in this build" (docs/google_drive_setup.md).
/// The only scope ever requested is `drive.appdata` (the app's own hidden
/// Drive folder) — sign-in itself adds just email/profile.
/// ============================================================
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// OAuth client ids passed at build time.
@immutable
class GoogleConfig {
  const GoogleConfig({this.serverClientId = '', this.iosClientId = ''});

  factory GoogleConfig.fromEnvironment() => const GoogleConfig(
    serverClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    iosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
  );

  final String serverClientId;
  final String iosClientId;

  /// The one Drive scope FocusFlow uses.
  static const List<String> driveScopes = [drive.DriveApi.driveAppdataScope];

  /// Whether this platform has the ids it needs.
  bool get isConfigured {
    if (kIsWeb) return false;
    if (Platform.isIOS) return iosClientId.isNotEmpty;
    if (Platform.isAndroid) return serverClientId.isNotEmpty;
    return false;
  }
}

/// The parts of a Google account the app keeps (no tokens).
@immutable
class GoogleProfile {
  const GoogleProfile({required this.email, this.displayName, this.photoUrl});

  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Thrown by gateways for real failures (not cancellation).
class CloudAuthException implements Exception {
  const CloudAuthException(this.message);

  final String message;

  @override
  String toString() => 'CloudAuthException: $message';
}

/// google_sign_in, reduced to what FocusFlow needs.
abstract interface class GoogleAuthGateway {
  /// Interactive sign-in + consent for [GoogleConfig.driveScopes]. Null when
  /// the user cancelled.
  Future<GoogleProfile?> signIn();

  /// Restores the previous session without UI (null when there is none).
  Future<GoogleProfile?> restore();

  /// A Drive access token. [interactive] may show the consent sheet; else
  /// null when one cannot be obtained silently.
  Future<String?> accessToken({bool interactive = false});

  /// Forgets a token Drive rejected so the next [accessToken] is fresh.
  Future<void> clearToken(String token);

  /// Signs out; [revoke] also removes the app's Drive grant.
  Future<void> signOut({bool revoke = false});
}

/// Sign in with Apple (iOS only, profile only).
abstract interface class AppleAuthGateway {
  bool get isAvailable;

  /// Null when cancelled. Apple sends email/name only the first time.
  Future<({String? email, String? name, String userId})?> signIn();
}

// ─────────────────────────── Implementations ───────────────────────────

class PluginGoogleAuthGateway implements GoogleAuthGateway {
  PluginGoogleAuthGateway(this.config);

  final GoogleConfig config;
  Future<void>? _init;
  GoogleSignInAccount? _user;

  GoogleSignIn get _gsi => GoogleSignIn.instance;

  Future<void> _ensureInit() => _init ??= _gsi.initialize(
    clientId: Platform.isIOS ? config.iosClientId : null,
    serverClientId: config.serverClientId.isEmpty
        ? null
        : config.serverClientId,
  );

  static GoogleProfile _profile(GoogleSignInAccount a) => GoogleProfile(
    email: a.email,
    displayName: a.displayName,
    photoUrl: a.photoUrl,
  );

  static bool _cancelled(GoogleSignInException e) =>
      e.code == GoogleSignInExceptionCode.canceled ||
      e.code == GoogleSignInExceptionCode.interrupted ||
      e.code == GoogleSignInExceptionCode.uiUnavailable;

  @override
  Future<GoogleProfile?> signIn() async {
    if (!config.isConfigured) {
      throw CloudAuthException(tr('Google sign-in is not set up'));
    }
    await _ensureInit();
    try {
      final user = await _gsi.authenticate(scopeHint: GoogleConfig.driveScopes);
      // Drive consent (drive.appdata only). Declining = not signed in.
      await user.authorizationClient.authorizeScopes(GoogleConfig.driveScopes);
      _user = user;
      return _profile(user);
    } on GoogleSignInException catch (e) {
      if (_cancelled(e)) {
        await _safeSignOut();
        return null;
      }
      throw CloudAuthException(e.description ?? e.code.name);
    }
  }

  @override
  Future<GoogleProfile?> restore() async {
    if (!config.isConfigured) return null;
    await _ensureInit();
    try {
      _user ??= await _gsi.attemptLightweightAuthentication();
    } catch (_) {
      return null;
    }
    final u = _user;
    return u == null ? null : _profile(u);
  }

  @override
  Future<String?> accessToken({bool interactive = false}) async {
    if (!config.isConfigured) return null;
    await _ensureInit();
    final user = _user ?? (await restore() == null ? null : _user);
    final client = user?.authorizationClient ?? _gsi.authorizationClient;
    try {
      final silent = await client.authorizationForScopes(
        GoogleConfig.driveScopes,
      );
      if (silent != null) return silent.accessToken;
      if (!interactive) return null;
      return (await client.authorizeScopes(
        GoogleConfig.driveScopes,
      )).accessToken;
    } on GoogleSignInException catch (e) {
      if (_cancelled(e)) return null;
      throw CloudAuthException(e.description ?? e.code.name);
    }
  }

  @override
  Future<void> clearToken(String token) async {
    await _ensureInit();
    await _gsi.authorizationClient.clearAuthorizationToken(accessToken: token);
  }

  @override
  Future<void> signOut({bool revoke = false}) async {
    if (!config.isConfigured) return;
    await _ensureInit();
    _user = null;
    if (revoke) {
      await _gsi.disconnect();
    } else {
      await _safeSignOut();
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _gsi.signOut();
    } catch (_) {}
  }
}

class PluginAppleAuthGateway implements AppleAuthGateway {
  const PluginAppleAuthGateway();

  @override
  bool get isAvailable => !kIsWeb && Platform.isIOS;

  @override
  Future<({String? email, String? name, String userId})?> signIn() async {
    if (!isAvailable) return null;
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final name = [
        c.givenName,
        c.familyName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      return (
        email: c.email,
        name: name.isEmpty ? null : name,
        userId: c.userIdentifier ?? '',
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw CloudAuthException(e.message);
    }
  }
}
