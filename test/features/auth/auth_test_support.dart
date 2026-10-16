/// Shared setup for the auth screen tests (02 Sign in, 36 Account):
/// a [TestHarness] whose Google / Apple / Drive / keychain / file stores
/// are fakes, plus a helper to put a backup into the fake Drive.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/device_profile.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';

import '../../core/sync/drive_fakes.dart';
import '../../helpers/test_container.dart';

class AuthFakes {
  AuthFakes({FakeDriveStore? drive}) : drive = drive ?? FakeDriveStore();

  final FakeDriveStore drive;
  final google = FakeGoogleAuth();
  final apple = FakeAppleAuth();
  final secure = MemorySecureStore();
  final net = FakeNetwork();
  late final Directory dir = Directory.systemTemp.createTempSync('ff_auth');
  late final files = AppFiles.at(dir);

  /// Puts a FocusFlow backup with [itemCount] items into the fake Drive.
  Future<void> addDriveBackup({
    required DateTime createdAt,
    int itemCount = 113,
    String deviceName = 'Pixel 8 Pro',
  }) => drive.upload(
    DriveBackupFile.fileNameFor(createdAt, 'other-device'),
    Uint8List.fromList([1, 2, 3]),
    properties: {
      DriveBackupFile.kindKey: DriveBackupFile.kindBackup,
      'deviceId': 'other-device',
      'deviceName': deviceName,
      'platform': 'Android 15',
      'createdAt': createdAt.toUtc().toIso8601String(),
      'itemCount': '$itemCount',
    },
  );
}

/// A harness at [now] wired to [fakes]; disposed on tear-down. Backups
/// are plaintext by choice unless [encryptBackups] (the app default).
Future<TestHarness> authHarness(
  AuthFakes fakes, {
  required DateTime now,
  List<Override> overrides = const [],
  bool encryptBackups = false,
}) async {
  final h = await TestHarness.create(
    now: now,
    prefs: encryptBackups ? const {} : plaintextBackupPrefs(),
    overrides: [
      ...driveOverrides(
        drive: fakes.drive,
        files: fakes.files,
        secure: fakes.secure,
        net: fakes.net,
      ),
      googleConfigProvider.overrideWithValue(const ConfiguredGoogle()),
      googleAuthGatewayProvider.overrideWithValue(fakes.google),
      appleAuthGatewayProvider.overrideWithValue(fakes.apple),
      deviceProfileProvider.overrideWith(
        (ref) async => const DeviceProfile(
          name: 'Pixel 8 Pro',
          platform: 'Android 15',
          appVersion: '1.0.0',
        ),
      ),
      ...overrides,
    ],
  );
  return h;
}
