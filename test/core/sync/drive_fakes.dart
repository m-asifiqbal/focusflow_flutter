/// Fakes for the account / Drive tests: an in-memory appDataFolder,
/// sign-in gateways, a keychain and a network switch — so sync, sign-in
/// and background jobs run without plugins or network.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/google_account.dart';
import 'package:focusflow/core/sync/network_info.dart';
import 'package:focusflow/core/sync/settings_bridge.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';
import 'sync_fixtures.dart';

/// Keychain in a map.
class MemorySecureStore extends SecureStore {
  MemorySecureStore([Map<String, String>? values]) : values = values ?? {};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// appDataFolder in memory. Set [failWith] to make every call throw.
class FakeDriveStore implements DriveStore {
  final Map<String, DriveFile> files = {};
  final Map<String, Uint8List> contents = {};
  DriveFailure? failWith;
  int _seq = 0;

  /// Creation times come from here (defaults to wall time).
  DateTime Function() now = DateTime.now;

  void _check() {
    if (failWith case final f?) throw f;
  }

  @override
  Future<List<DriveFile>> list() async {
    _check();
    return files.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<DriveFile> upload(
    String name,
    Uint8List bytes, {
    Map<String, String> properties = const {},
    String mimeType = 'application/octet-stream',
    void Function(double progress)? onProgress,
  }) async {
    _check();
    onProgress?.call(0.5);
    final f = DriveFile(
      id: 'f${_seq++}',
      name: name,
      createdAt: now(),
      sizeBytes: bytes.length,
      properties: properties,
    );
    files[f.id] = f;
    contents[f.id] = bytes;
    onProgress?.call(1);
    return f;
  }

  @override
  Future<void> overwrite(String fileId, Uint8List bytes) async {
    _check();
    contents[fileId] = bytes;
  }

  @override
  Future<Uint8List> download(String fileId) async {
    _check();
    final c = contents[fileId];
    if (c == null) throw const DriveFailure(DriveFailureKind.unknown, '404');
    return c;
  }

  @override
  Future<void> delete(String fileId) async {
    _check();
    files.remove(fileId);
    contents.remove(fileId);
  }

  /// Total Drive storage reported by [storageLimit].
  int? limit = 15 * 1024 * 1024 * 1024;

  @override
  Future<int?> storageLimit() async {
    _check();
    return limit;
  }

  /// Names of the backups (not the manifest).
  List<String> get backupNames =>
      [for (final f in files.values) f.name]
        ..removeWhere((n) => !n.endsWith('.ffbackup'));
}

class FakeGoogleAuth implements GoogleAuthGateway {
  GoogleProfile? profile = const GoogleProfile(
    email: 'sam@example.com',
    displayName: 'Sam Lee',
  );
  Object? error;
  final List<bool> signOuts = [];

  @override
  Future<GoogleProfile?> signIn() async {
    if (error case final e?) throw e;
    return profile;
  }

  @override
  Future<GoogleProfile?> restore() async => profile;

  @override
  Future<String?> accessToken({bool interactive = false}) async => 'token';

  @override
  Future<void> clearToken(String token) async {}

  @override
  Future<void> signOut({bool revoke = false}) async => signOuts.add(revoke);
}

class FakeAppleAuth implements AppleAuthGateway {
  ({String? email, String? name, String userId})? result;

  @override
  bool get isAvailable => true;

  @override
  Future<({String? email, String? name, String userId})?> signIn() async =>
      result;
}

/// Google configured regardless of the host platform.
class ConfiguredGoogle extends GoogleConfig {
  const ConfiguredGoogle() : super(serverClientId: 's', iosClientId: 'i');

  @override
  bool get isConfigured => true;
}

class FakeNetwork extends NetworkInfo {
  FakeNetwork({this.online = true, this.wifi = true});

  bool online;
  bool wifi;

  @override
  Future<bool> isOnline() async => online;

  @override
  Future<bool> isOnWifi() async => online && wifi;
}

/// Overrides that make a [TestHarness] sync against [drive] (null = not
/// signed in) with a memory keychain, temp files and [net].
List<Override> driveOverrides({
  required FakeDriveStore? drive,
  required AppFiles files,
  required MemorySecureStore secure,
  required FakeNetwork net,
}) => [
  secureStoreProvider.overrideWithValue(secure),
  appFilesProvider.overrideWithValue(files),
  networkInfoProvider.overrideWithValue(net),
  driveStoreFactoryProvider.overrideWithValue(
    ({bool interactive = false}) async => drive,
  ),
  backupEngineProvider.overrideWith(
    (ref) => BackupEngine(
      db: ref.watch(databaseProvider),
      items: ref.watch(itemsRepositoryProvider),
      files: files,
      deviceId: TestHarness.deviceId,
      vault: const FakeVaultBridge(),
      settings: ref.watch(settingsBackupBridgeProvider),
      clock: ref.watch(clockProvider),
    ),
  ),
];

/// Initial prefs with "Encrypt backups" off. Plaintext backups now only
/// happen when the user chose "Back up without encryption" (the default
/// is on, and on + no backup PIN refuses to back up), so tests that
/// exercise plaintext backups state that choice explicitly.
Map<String, Object> plaintextBackupPrefs() => {
  SettingsController.prefsKey: jsonEncode(
    const AppSettings(encryptBackups: false).toJson(),
  ),
};
