/// ImportWriter (dedupe by title + date, created date kept, archived /
/// pinned, logins only through the vault bridge, locked vault writes
/// nothing) and ExportService (.ffbackup honours the INCLUDE filter and
/// refuses vault items without a backup key).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/backup/data/export_service.dart';
import 'package:focusflow/features/backup/data/import_writer.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../core/sync/drive_fakes.dart';
import '../../../helpers/test_container.dart';
import '../../../core/sync/sync_fixtures.dart';

class _Vault extends NoVaultBackupBridge {
  bool unlocked = true;
  final saved = <ImportedLogin>[];

  @override
  Future<int> importLogins(List<ImportedLogin> logins) async {
    if (!unlocked) throw const VaultUnavailable();
    saved.addAll(logins);
    return logins.length;
  }
}

void main() {
  late TestHarness h;
  late _Vault vault;
  late MemorySecureStore secure;

  setUp(() async {
    vault = _Vault();
    secure = MemorySecureStore();
    h = await TestHarness.create(
      now: DateTime(2026, 6, 13, 9, 41),
      prefs: plaintextBackupPrefs(),
      overrides: [
        vaultBridgeProvider.overrideWithValue(vault),
        secureStoreProvider.overrideWithValue(secure),
        backupEngineProvider.overrideWith(
          (ref) => BackupEngine(
            db: ref.watch(databaseProvider),
            items: ref.watch(itemsRepositoryProvider),
            files: ref.watch(appFilesProvider),
            deviceId: TestHarness.deviceId,
            vault: const FakeVaultBridge(),
            clock: ref.watch(clockProvider),
          ),
        ),
      ],
    );
  });
  tearDown(() => h.dispose());

  ImportWriter writer() => h.read(importWriterProvider);

  final bundle = ImportBundle(
    source: ImportSource.googleKeep,
    notes: [
      ImportedNote(
        title: 'Packing',
        text: 'Passport',
        createdAt: DateTime(2024, 5, 1, 10),
        pinned: true,
      ),
      const ImportedNote(title: 'Old idea', text: 'x', archived: true),
    ],
    tasks: [ImportedTask(title: 'Pay rent', due: DateTime(2026, 7, 1))],
    logins: const [
      ImportedLogin(title: 'GitHub', username: 'a', password: 'p'),
      ImportedLogin(title: 'GitHub', username: 'a', password: 'p'),
    ],
  );

  test('writes, keeps created date, dedupes on the second run', () async {
    final r = await writer().write(bundle);
    expect(r.imported, 4);
    expect(r.duplicates, 1); // the repeated login
    expect(vault.saved.single.title, 'GitHub');

    final notes = await h
        .read(notesRepositoryProvider)
        .watchNotes(const NotesQuery())
        .first;
    final packing = notes.single;
    expect(packing.title, 'Packing');
    expect(packing.createdAt, DateTime(2024, 5, 1, 10));
    expect(packing.isPinned, isTrue);
    final archived = await h
        .read(itemsRepositoryProvider)
        .watchArchived()
        .first;
    expect(archived.map((s) => s.ref.type), contains(ItemType.note));

    final again = await writer().write(
      ImportBundle(
        source: bundle.source,
        notes: bundle.notes,
        tasks: bundle.tasks,
      ),
    );
    expect(again.imported, 0);
    expect(again.duplicates, 3);
  });

  test('locked vault: nothing is written', () async {
    vault.unlocked = false;
    await expectLater(writer().write(bundle), throwsA(isA<VaultUnavailable>()));
    final notes = await h
        .read(notesRepositoryProvider)
        .watchNotes(const NotesQuery())
        .first;
    expect(notes, isEmpty);
  });

  test('.ffbackup export honours the filter; vault needs a key', () async {
    await h.read(notesRepositoryProvider).createEmpty(title: 'A');
    await h.read(notesRepositoryProvider).createEmpty(title: 'B');
    final service = h.read(exportServiceProvider);
    final f = await service.build(
      const ExportOptions(modules: {ExportModule.tasks}),
    );
    expect(f.itemCount, 0);
    final all = await service.build(const ExportOptions());
    expect(all.itemCount, 2);
    expect(all.name, endsWith('.ffbackup'));
    final engine = h.read(backupEngineProvider);
    final snap = await engine.openSnapshot(engine.inspect(all.bytes));
    expect(snap.rows('notes'), hasLength(2));

    await expectLater(
      service.build(
        const ExportOptions(modules: {ExportModule.notes, ExportModule.vault}),
      ),
      throwsA(isA<VaultExportNeedsKey>()),
    );
  });

  test(
    '.ffbackup carries the app settings unless they are switched off',
    () async {
      final bridge = FakeSettingsBridge(
        exported: BackupSettings.of(
          const AppSettings().copyWith(accent: AccentColor.blue),
        ),
      );
      final service = ExportService(
        engine: BackupEngine(
          db: h.db,
          items: h.read(itemsRepositoryProvider),
          files: h.read(appFilesProvider),
          deviceId: TestHarness.deviceId,
          vault: const FakeVaultBridge(),
          settings: bridge,
          clock: h.clock,
        ),
        keys: h.read(backupKeyPolicyProvider),
        encryptBackups: () => false,
        drive: h.read(driveSyncProvider),
        local: h.read(localBackupsProvider),
        clock: h.clock,
      );

      final withSettings = await service.build(const ExportOptions());
      expect(withSettings.backup!.manifest.hasSettings, isTrue);
      expect(BackupArchive.decode(withSettings.bytes).settings, isNotNull);

      final without = await service.build(
        const ExportOptions(includeSettings: false),
      );
      expect(without.backup!.manifest.hasSettings, isFalse);
      expect(BackupArchive.decode(without.bytes).settings, isNull);
    },
  );
}
