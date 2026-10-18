/// Settings inside a `.ffbackup`: carried in `settings.json` (sealed when the
/// backup is encrypted), applied by a restore (Replace / Merge), skipped on
/// request, and never able to cost the user their data — a backup without
/// settings, with damaged ones, or a settings store that cannot be written
/// still restores every item.
library;

import 'dart:convert';
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

BackupKdfParams _fastParams() =>
    BackupKdfParams.generate(memoryKiB: 256, iterations: 1);

/// What a phone with a customised configuration would carry.
BackupSettings _configured() => BackupSettings.of(
  const AppSettings().copyWith(
    accent: AccentColor.blue,
    quietHours: true,
    repeatIntervalMinutes: 15,
  ),
  preferences: const {'tasks.view': 'board'},
);

/// [archive] with its settings entry replaced by [bytes].
BackupArchive _withSettings(BackupArchive archive, List<int> bytes) =>
    BackupArchive(
      manifest: archive.manifest,
      dbJson: archive.dbJson,
      settings: Uint8List.fromList(bytes),
      files: archive.files,
    );

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
  });

  tearDown(() async {
    await source.dispose();
    await target.dispose();
  });

  group('build', () {
    test('carries the settings and says so in the manifest', () async {
      final built = await engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(exported: _configured()),
      ).build();

      expect(built.manifest.hasSettings, isTrue);
      final archive = BackupArchive.decode(built.bytes);
      expect(archive.manifest.hasSettings, isTrue);
      final json =
          jsonDecode(utf8.decode(archive.settings!)) as Map<String, Object?>;
      expect(json['format'], 'ffsettings');
      final settings = json['settings']! as Map;
      expect(settings['accent'], 'blue');
      expect(settings['quietHours'], true);
      expect(json['preferences'], {'tasks.view': 'board'});
    });

    test('device-bound fields never reach the file', () async {
      final built = await engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(
          exported: BackupSettings.of(
            const AppSettings().copyWith(
              onboardingSeen: true,
              accountMode: AccountMode.google,
              recentSearches: const ['secret search'],
            ),
          ),
        ),
      ).build();

      final text = utf8.decode(BackupArchive.decode(built.bytes).settings!);
      for (final key in BackupSettings.deviceBound) {
        expect(text, isNot(contains('"$key"')), reason: key);
      }
      expect(text, isNot(contains('secret search')));
    });

    test('includeSettings: false leaves them out', () async {
      final built = await engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(exported: _configured()),
      ).build(includeSettings: false);

      expect(built.manifest.hasSettings, isFalse);
      expect(BackupArchive.decode(built.bytes).settings, isNull);
    });

    test('nothing to carry → no settings entry', () async {
      final built = await engineFor(source, sourceFiles).build();

      expect(built.manifest.hasSettings, isFalse);
      expect(BackupArchive.decode(built.bytes).settings, isNull);
    });

    test('a settings store that fails never fails the backup', () async {
      final broken = _ThrowingExport();
      final built = await engineFor(
        source,
        sourceFiles,
        settings: broken,
      ).build();

      expect(built.manifest.hasSettings, isFalse);
    });

    test('an encrypted backup seals the settings too', () async {
      final key = await BackupCipher.deriveKey('482910', _fastParams());
      final built = await engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(exported: _configured()),
      ).build(key: key);

      final archive = BackupArchive.decode(built.bytes);
      expect(archive.manifest.hasSettings, isTrue);
      final raw = utf8.decode(archive.settings!, allowMalformed: true);
      expect(raw, isNot(contains('ffsettings')));
      expect(raw, isNot(contains('quietHours')));

      final fake = FakeSettingsBridge();
      final restore = engineFor(target, targetFiles, settings: fake);
      final pinKey = await restore.keyFor(archive.manifest, '482910');
      final result = await restore.restore(
        archive,
        mode: RestoreMode.replace,
        key: pinKey,
      );
      expect(result.settingsRestored, isTrue);
      expect(fake.applied.single.settings.settings['quietHours'], true);
    });
  });

  group('restore', () {
    Future<BackupArchive> backup({bool withSettings = true}) async {
      final engine = engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(
          exported: withSettings ? _configured() : null,
        ),
      );
      return BackupArchive.decode((await engine.build()).bytes);
    }

    test('Replace applies the settings as a replace', () async {
      await seedSample(source, sourceFiles);
      final archive = await backup();
      final fake = FakeSettingsBridge();
      final engine = engineFor(target, targetFiles, settings: fake);

      final result = await engine.restore(archive, mode: RestoreMode.replace);

      expect(result.settingsRestored, isTrue);
      expect(result.settingsFailed, isFalse);
      expect(fake.applied, hasLength(1));
      expect(fake.applied.single.replace, isTrue);
      expect(fake.applied.single.settings.settings['accent'], 'blue');
      expect(fake.applied.single.settings.preferences, {'tasks.view': 'board'});
      // …alongside the data.
      expect((await engine.snapshot()).counts['notes'], greaterThan(0));
    });

    test('Merge applies them as a merge (local choices stay)', () async {
      final archive = await backup();
      final fake = FakeSettingsBridge();

      final result = await engineFor(
        target,
        targetFiles,
        settings: fake,
      ).restore(archive, mode: RestoreMode.merge);

      expect(result.settingsRestored, isTrue);
      expect(fake.applied.single.replace, isFalse);
    });

    test('applySettings: false restores the data only', () async {
      await seedSample(source, sourceFiles);
      final archive = await backup();
      final fake = FakeSettingsBridge();
      final engine = engineFor(target, targetFiles, settings: fake);

      final result = await engine.restore(
        archive,
        mode: RestoreMode.merge,
        applySettings: false,
      );

      expect(fake.applied, isEmpty);
      expect(result.settingsRestored, isFalse);
      expect(result.settingsFailed, isFalse);
      expect((await engine.snapshot()).counts['notes'], greaterThan(0));
    });

    test('a backup without settings restores as before', () async {
      await seedSample(source, sourceFiles);
      final archive = await backup(withSettings: false);
      final fake = FakeSettingsBridge();

      final result = await engineFor(
        target,
        targetFiles,
        settings: fake,
      ).restore(archive, mode: RestoreMode.replace);

      expect(fake.applied, isEmpty);
      expect(result.settingsRestored, isFalse);
      expect(result.settingsFailed, isFalse);
    });

    test('damaged settings never cost the data', () async {
      await seedSample(source, sourceFiles);
      final damaged = _withSettings(await backup(), utf8.encode('{not json'));
      final fake = FakeSettingsBridge();
      final engine = engineFor(target, targetFiles, settings: fake);

      final result = await engine.restore(damaged, mode: RestoreMode.replace);

      expect(result.settingsRestored, isFalse);
      expect(result.settingsFailed, isTrue);
      expect(fake.applied, isEmpty);
      expect((await engine.snapshot()).counts['notes'], greaterThan(0));
    });

    test('settings from a newer app are reported, not applied', () async {
      final newer = _withSettings(
        await backup(),
        utf8.encode(
          jsonEncode({
            'format': 'ffsettings',
            'version': BackupSettings.currentVersion + 1,
            'settings': {'accent': 'blue'},
          }),
        ),
      );
      final fake = FakeSettingsBridge();

      final result = await engineFor(
        target,
        targetFiles,
        settings: fake,
      ).restore(newer, mode: RestoreMode.merge);

      expect(result.settingsFailed, isTrue);
      expect(fake.applied, isEmpty);
    });

    test('a settings store that cannot be written is reported', () async {
      await seedSample(source, sourceFiles);
      final archive = await backup();
      final engine = engineFor(
        target,
        targetFiles,
        settings: FakeSettingsBridge(applyError: StateError('disk full')),
      );

      final result = await engine.restore(archive, mode: RestoreMode.replace);

      expect(result.settingsRestored, isFalse);
      expect(result.settingsFailed, isTrue);
      expect((await engine.snapshot()).counts['notes'], greaterThan(0));
    });

    test('a wrong PIN fails before the settings are touched', () async {
      final key = await BackupCipher.deriveKey('482910', _fastParams());
      final built = await engineFor(
        source,
        sourceFiles,
        settings: FakeSettingsBridge(exported: _configured()),
      ).build(key: key);
      final fake = FakeSettingsBridge();
      final restore = engineFor(target, targetFiles, settings: fake);
      final archive = restore.inspect(built.bytes);
      final wrong = await restore.keyFor(archive.manifest, '000000');

      await expectLater(
        restore.restore(archive, mode: RestoreMode.replace, key: wrong),
        throwsA(isA<WrongBackupPin>()),
      );
      expect(fake.applied, isEmpty);
    });
  });

  group('format', () {
    test('hasSettings survives the manifest JSON', () {
      final m = BackupManifest(
        schemaVersion: 2,
        appVersion: '1.0.0',
        createdAt: syncNow,
        deviceId: 'd',
        deviceName: 'Pixel',
        platform: 'Android',
        counts: const {},
        itemCount: 0,
        checksum: 'x',
        hasSettings: true,
      );
      expect(BackupManifest.fromJson(m.toJson()).hasSettings, isTrue);
    });

    test('a manifest from before settings existed reads as "none"', () {
      final json = BackupManifest(
        schemaVersion: 2,
        appVersion: '1.0.0',
        createdAt: syncNow,
        deviceId: 'd',
        deviceName: 'Pixel',
        platform: 'Android',
        counts: const {},
        itemCount: 0,
        checksum: 'x',
      ).toJson()..remove('hasSettings');
      final m = BackupManifest.fromJson(json);
      expect(m.hasSettings, isFalse);
      expect(m.formatVersion, 1);
    });

    test(
      'the zip carries settings.json only when there are settings',
      () async {
        final withSettings = await engineFor(
          source,
          sourceFiles,
          settings: FakeSettingsBridge(exported: _configured()),
        ).build();
        final without = await engineFor(source, sourceFiles).build();

        expect(BackupArchive.decode(withSettings.bytes).settings, isNotNull);
        expect(BackupArchive.decode(without.bytes).settings, isNull);
      },
    );
  });
}

class _ThrowingExport extends FakeSettingsBridge {
  @override
  Future<BackupSettings?> export() async => throw StateError('prefs gone');
}
