/// The profile picture inside a `.ffbackup`: carried by full backups next to
/// the settings (sealed when encrypted), left out of module exports, put
/// back by a restore (Replace always, Merge only when this device has none,
/// never by the data-only automatic merge), and part of the content hash
/// the sync on app open compares.
library;

import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/theme/app_colors.dart';

import '../../helpers/test_container.dart';
import 'sync_fixtures.dart';

final _photo = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3, 4, 0xFF, 0xD9]);
const _path = AppFiles.profilePhotoPath;

void main() {
  late TestHarness source;
  late TestHarness target;
  late AppFiles sourceFiles;
  late AppFiles targetFiles;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    source = await TestHarness.create(now: syncNow);
    target = await TestHarness.create(now: syncNow);
    sourceFiles = tempFiles(addTearDown);
    targetFiles = tempFiles(addTearDown);
    await sourceFiles.write(_path, _photo);
  });

  tearDown(() async {
    await source.dispose();
    await target.dispose();
  });

  Future<BackupArchive> backup({BackupKey? key}) async => BackupArchive.decode(
    (await engineFor(source, sourceFiles).build(key: key)).bytes,
  );

  test('a full backup carries it; Replace puts it back', () async {
    final archive = await backup();
    expect(archive.profilePhoto, _photo);

    final r = await engineFor(
      target,
      targetFiles,
    ).restore(archive, mode: RestoreMode.replace);
    expect(r.photoRestored, isTrue);
    expect(await targetFiles.read(_path), _photo);
  });

  test('Merge keeps a picture chosen here, fills in a missing one', () async {
    final archive = await backup();
    final mine = Uint8List.fromList([9, 9, 9]);
    await targetFiles.write(_path, mine);

    final kept = await engineFor(
      target,
      targetFiles,
    ).restore(archive, mode: RestoreMode.merge);
    expect(kept.photoRestored, isFalse);
    expect(await targetFiles.read(_path), mine);

    await targetFiles.delete(_path);
    final filled = await engineFor(
      target,
      targetFiles,
    ).restore(archive, mode: RestoreMode.merge);
    expect(filled.photoRestored, isTrue);
    expect(await targetFiles.read(_path), _photo);
  });

  test("the data-only merge (another device's backup) never sets it", () async {
    final archive = await backup();
    final r = await engineFor(
      target,
      targetFiles,
    ).restore(archive, mode: RestoreMode.merge, applySettings: false);
    expect(r.photoRestored, isFalse);
    expect(await targetFiles.exists(_path), isFalse);
  });

  test(
    'exports of chosen modules and settings-less builds leave it out',
    () async {
      final engine = engineFor(source, sourceFiles);
      final export = BackupArchive.decode(
        (await engine.build(filter: (s) => s)).bytes,
      );
      expect(export.profilePhoto, isNull);
      final noSettings = BackupArchive.decode(
        (await engine.build(includeSettings: false)).bytes,
      );
      expect(noSettings.profilePhoto, isNull);
    },
  );

  test('an encrypted backup seals it; the right key opens it', () async {
    final key = await BackupCipher.deriveKey(
      '482910',
      BackupKdfParams.generate(memoryKiB: 256, iterations: 1),
    );
    final archive = await backup(key: key);
    expect(archive.profilePhoto, isNot(_photo));

    await engineFor(
      target,
      targetFiles,
    ).restore(archive, mode: RestoreMode.replace, key: key);
    expect(await targetFiles.read(_path), _photo);
  });

  group('content hash', () {
    test('the fingerprint is the hash a backup of this state has', () async {
      final engine = engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(
          exported: BackupSettings.of(
            const AppSettings().copyWith(accent: AccentColor.blue),
          ),
        ),
      );
      final built = await engine.build();
      expect(built.contentHash, isNotEmpty);
      expect(await engine.fingerprint(), built.contentHash);
    });

    test('a new picture, or none, changes it', () async {
      final engine = engineFor(source, sourceFiles);
      final before = await engine.fingerprint();

      await sourceFiles.write(_path, Uint8List.fromList([7, 7]));
      final changed = await engine.fingerprint();
      expect(changed, isNot(before));

      await sourceFiles.delete(_path);
      expect(await engine.fingerprint(), isNot(changed));
      expect(await engine.fingerprint(), isNot(before));
    });

    test('settings are part of it', () async {
      final bridge = FakeSettingsBridge(
        exported: BackupSettings.of(const AppSettings()),
      );
      final engine = engineFor(source, sourceFiles, settings: bridge);
      final before = await engine.fingerprint();
      bridge.exported = BackupSettings.of(
        const AppSettings().copyWith(accent: AccentColor.indigo),
      );
      expect(await engine.fingerprint(), isNot(before));
    });
  });
}
