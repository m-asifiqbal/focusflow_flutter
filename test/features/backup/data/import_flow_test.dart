/// Import flow hardening — odd JSON shapes never crash the importers, a
/// failing picker / parser ends in a clear error (never a stuck "Reading
/// file…"), password CSVs need the vault unlocked *before* parsing, a
/// failed notification re-plan doesn't turn a good import into a failure,
/// parsed logins leave the state when the import ends, and vault dedupe
/// compares title + username + website (never title alone).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/backup/data/import_file_source.dart';
import 'package:focusflow/features/backup/data/import_writer.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/importers/focusflow_importer.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_detector.dart';
import 'package:focusflow/features/backup/domain/services/importers/notes_app_importers.dart';
import 'package:focusflow/features/backup/presentation/notifiers/import_export_controllers.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../core/sync/sync_fixtures.dart';
import '../../../helpers/test_container.dart';

class _Files implements ImportFileSource {
  _Files(this.name, this.text, {this.error});

  final String name;
  final String text;
  final Object? error;
  bool discarded = false;

  @override
  Future<PickedImportFile?> pick() async {
    if (error case final e?) throw e;
    return PickedImportFile(
      name: name,
      bytes: Uint8List.fromList(utf8.encode(text)),
      onDiscard: () async => discarded = true,
    );
  }
}

class _BrokenEngine implements NotificationEngine {
  @override
  Future<void> start() async {}

  @override
  Future<void> onResume() async => throw StateError('plugin gone');
}

class _Vault extends NoVaultBackupBridge {
  final saved = <ImportedLogin>[];
  int lockAfter = 1 << 30;

  @override
  Future<int> importLogins(List<ImportedLogin> logins) async {
    if (saved.length >= lockAfter) {
      throw const VaultUnavailable('The vault locked.');
    }
    saved.addAll(logins);
    return logins.length;
  }
}

const _bitwarden =
    'folder,favorite,type,name,notes,fields,reprompt,login_uri,'
    'login_username,login_password,login_totp\n'
    ',,login,GitHub,,,,https://github.com,sam,pw1,\n';

void main() {
  late TestHarness h;
  late _Vault vault;

  Future<void> start(List overrides) async {
    vault = _Vault();
    h = await TestHarness.create(
      now: DateTime(2026, 6, 13, 9, 41),
      overrides: [vaultBridgeProvider.overrideWithValue(vault), ...overrides],
    );
    addTearDown(h.dispose);
  }

  group('importers survive odd JSON shapes', () {
    test('FocusFlow JSON with wrong types per field', () {
      final b = FocusFlowImporter.fromJson(
        jsonEncode({
          'format': 'focusflow-export',
          'notes': [
            1,
            'x',
            {'title': 'Kept'},
          ],
          'tasks': {'not': 'a list'},
          'habits': [
            {
              'name': 'Run',
              'logs': [
                5,
                {'date': '2026-01-01', 'count': '2'},
              ],
            },
          ],
          'reminders': [null],
        }),
      );
      expect(b.notes.single.title, 'Kept');
      expect(b.tasks, isEmpty);
      expect(b.habits.single.logs, {'2026-01-01': 2});
    });

    test('task subtasks that are not objects are skipped', () {
      final b = FocusFlowImporter.fromJson(
        jsonEncode({
          'format': 'focusflow-export',
          'tasks': [
            {
              'title': 'T',
              'subtasks': [
                3,
                {'title': 'a', 'done': true},
              ],
            },
          ],
        }),
      );
      expect(b.tasks.single.subtasks.single.title, 'a');
    });

    test('a Keep note with odd labels / list items still imports', () {
      final b = KeepImporter.parse(
        utf8.encode(
          jsonEncode({
            'title': 'List',
            'listContent': [
              1,
              {'text': 'milk', 'isChecked': true},
            ],
            'labels': 'not a list',
            'createdTimestampUsec': 1700000000000000,
          }),
        ),
      );
      expect(b.notes.single.text, '- [x] milk');
      expect(b.notes.single.tags, isEmpty);
    });

    test('password exports are recognised from the header alone', () {
      expect(
        ImportDetector.isPasswordExport('x.csv', utf8.encode(_bitwarden)),
        isTrue,
      );
      expect(
        ImportDetector.isPasswordExport('x.csv', utf8.encode('title\nA\n')),
        isFalse,
      );
    });
  });

  group('ImportController', () {
    test('a picker error ends in an error state, not "Reading…"', () async {
      await start([
        importFileSourceProvider.overrideWithValue(
          _Files('x', '', error: StateError('plugin')),
        ),
      ]);
      final c = h.read(importControllerProvider.notifier);
      expect(await c.pick(), isTrue);
      expect(h.read(importControllerProvider).phase, ImportPhase.error);
    });

    test('a damaged file ends in an error state and is discarded', () async {
      final files = _Files('notes.json', '{"format":"focusflow-export",');
      await start([importFileSourceProvider.overrideWithValue(files)]);
      final c = h.read(importControllerProvider.notifier);
      await c.pick();
      final s = h.read(importControllerProvider);
      expect(s.phase, ImportPhase.error);
      expect(s.error, isNotEmpty);
      expect(files.discarded, isTrue);
    });

    test('password CSVs are not parsed until the vault is unlocked', () async {
      final files = _Files('bw.csv', _bitwarden);
      await start([importFileSourceProvider.overrideWithValue(files)]);
      final c = h.read(importControllerProvider.notifier);
      var asked = 0;
      await c.pick(
        unlockVault: () async {
          asked++;
          return false;
        },
      );
      var s = h.read(importControllerProvider);
      expect(asked, 1);
      expect(s.phase, ImportPhase.error);
      expect(s.bundle, isNull);
      expect(files.discarded, isTrue);

      await c.pick(unlockVault: () async => true);
      s = h.read(importControllerProvider);
      expect(s.phase, ImportPhase.preview);
      expect(s.bundle?.logins, hasLength(1));

      // Logins leave the state as soon as the import ends.
      await c.confirm();
      s = h.read(importControllerProvider);
      expect(s.phase, ImportPhase.done);
      expect(s.bundle, isNull);
      expect(s.result?.imported, 1);
      expect(vault.saved.single.title, 'GitHub');
    });

    test('a failing notification re-plan does not fail the import', () async {
      final files = _Files(
        'r.json',
        jsonEncode({
          'format': 'focusflow-export',
          'reminders': [
            {'title': 'Call mum', 'at': '2026-06-20T10:00:00'},
          ],
        }),
      );
      await start([
        importFileSourceProvider.overrideWithValue(files),
        notificationEngineProvider.overrideWithValue(_BrokenEngine()),
      ]);
      final c = h.read(importControllerProvider.notifier);
      await c.pick();
      await c.confirm();
      final s = h.read(importControllerProvider);
      expect(s.phase, ImportPhase.done);
      expect(s.result?.imported, 1);
      expect(s.notice, contains('alerts'));
    });
  });

  group('vault dedupe', () {
    Future<void> addVaultItem(String id, String title) => h.db.customStatement(
      'INSERT INTO vault_items (id, title, encrypted_payload, created_at, '
      'updated_at) VALUES (?, ?, ?, ?, ?)',
      [
        id,
        title,
        Uint8List.fromList([1, 2, 3]),
        1,
        1,
      ],
    );

    ImportWriter writer(Map<String, ({String username, String url})> known) =>
        ImportWriter(
          db: h.db,
          snapshot: () => engineFor(h, tempFiles(addTearDown)).snapshot(),
          notes: h.read(notesRepositoryProvider),
          tasks: h.read(tasksRepositoryProvider),
          reminders: h.read(remindersRepositoryProvider),
          habits: h.read(habitsRepositoryProvider),
          medicines: h.read(medicinesRepositoryProvider),
          items: h.read(itemsRepositoryProvider),
          vault: vault,
          clock: h.read(clockProvider),
          vaultLogin: (id, _) async => known[id],
        );

    test('same title, different username is a new login', () async {
      await start(const []);
      await addVaultItem('v1', 'GitHub');
      await addVaultItem('v2', 'Bank'); // unreadable: never a duplicate
      final r =
          await writer({
            'v1': (username: 'sam', url: 'https://github.com/'),
          }).write(
            const ImportBundle(
              source: ImportSource.bitwarden,
              logins: [
                ImportedLogin(
                  title: 'GitHub',
                  username: 'sam',
                  url: 'github.com',
                ),
                ImportedLogin(
                  title: 'GitHub',
                  username: 'work',
                  url: 'github.com',
                ),
                ImportedLogin(title: 'Bank', username: 'sam'),
              ],
            ),
          );
      expect(r.duplicates, 1);
      expect(r.imported, 2);
      expect(vault.saved.map((l) => l.username), ['work', 'sam']);
    });

    test(
      'a vault that locks half-way reports exactly what was saved',
      () async {
        await start(const []);
        vault.lockAfter = 1;
        final r = await writer(const {}).write(
          const ImportBundle(
            source: ImportSource.bitwarden,
            logins: [
              ImportedLogin(title: 'A'),
              ImportedLogin(title: 'B'),
              ImportedLogin(title: 'C'),
            ],
          ),
        );
        expect(r.imported, 1);
        expect(r.failures.single, contains('2 passwords were not imported'));
      },
    );

    test('a locked vault before the first login writes nothing', () async {
      await start(const []);
      vault.lockAfter = 0;
      await expectLater(
        writer(const {}).write(
          const ImportBundle(
            source: ImportSource.bitwarden,
            logins: [ImportedLogin(title: 'A')],
            notes: [ImportedNote(title: 'N')],
          ),
        ),
        throwsA(isA<VaultUnavailable>()),
      );
      final notes = await h.db
          .customSelect('SELECT COUNT(*) AS n FROM notes')
          .getSingle();
      expect(notes.read<int>('n'), 0);
    });
  });
}
