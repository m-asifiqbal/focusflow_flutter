/// VaultSessionBackupBridge: key envelope export / accept (same device,
/// new device adopts, other vault refused), PIN check and encrypted
/// password imports.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/vault_backup_bridge.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../vault_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 6, 13, 9, 41);
  late VaultTestBed a;

  setUp(() async => a = await VaultTestBed.create(now));
  tearDown(() async {
    await a.session.lock();
    await a.h.dispose();
  });

  VaultBackupBridge bridgeOf(VaultTestBed b) => b.h.read(vaultBridgeProvider);

  test('the provider returns the vault session bridge', () {
    expect(bridgeOf(a), isA<VaultSessionBackupBridge>());
  });

  test('no vault: no envelope, imports refused', () async {
    await a.session.ready;
    final bridge = bridgeOf(a);
    expect(await bridge.hasVault(), isFalse);
    expect(await bridge.exportKeyEnvelope(), isNull);
    expect(await bridge.acceptKeyEnvelope(null), isTrue);
    await expectLater(
      bridge.importLogins(const [ImportedLogin(title: 'X', password: 'p')]),
      throwsA(isA<VaultUnavailable>()),
    );
  });

  test('envelope carries the wrapped key and its stable id', () async {
    await a.setUpVault();
    final bridge = bridgeOf(a);
    final env = (await bridge.exportKeyEnvelope())!;
    expect(env['keyId'], await a.h.read(vaultKeyManagerProvider).keyId());
    expect(env['bundle'], isA<String>());
    expect(env.toString(), isNot(contains('123456')));
    expect(await bridge.acceptKeyEnvelope(env), isTrue);
    expect(await bridge.verifyPin('123456'), isTrue);
    expect(await bridge.verifyPin('000000'), isFalse);
  });

  test('an empty local vault takes the backup\'s key and PIN', () async {
    await a.setUpVault();
    final b = await VaultTestBed.create(now);
    addTearDown(() async {
      await b.session.lock();
      await b.h.dispose();
    });
    await b.setUpVault('654321');
    final env = (await bridgeOf(a).exportKeyEnvelope())!;
    expect(await bridgeOf(b).acceptKeyEnvelope(env), isTrue);
    expect(b.h.read(vaultSessionProvider).phase, VaultPhase.locked);
    expect(await b.session.unlockWithPin('654321'), UnlockResult.wrongPin);
    expect(await b.session.unlockWithPin('123456'), UnlockResult.success);
    expect((await bridgeOf(b).exportKeyEnvelope())!['keyId'], env['keyId']);
  });

  test(
    'a new device adopts the envelope; the old PIN opens old rows',
    () async {
      await a.setUpVault();
      final blob = await VaultPayloadCodec.seal(
        a.h.read(vaultSessionProvider).requireKey(),
        const VaultPayload(password: 'restored-secret'),
      );
      final env = (await bridgeOf(a).exportKeyEnvelope())!;

      final b = await VaultTestBed.create(now);
      addTearDown(() async {
        await b.session.lock();
        await b.h.dispose();
      });
      await b.session.ready;
      expect(await bridgeOf(b).acceptKeyEnvelope(env), isTrue);
      expect(await bridgeOf(b).hasVault(), isTrue);
      expect(b.h.read(vaultSessionProvider).phase, VaultPhase.locked);
      expect(await b.session.unlockWithPin('123456'), UnlockResult.success);
      final opened = await VaultPayloadCodec.open(
        b.h.read(vaultSessionProvider).requireKey(),
        blob,
      );
      expect(opened.password, 'restored-secret');
    },
  );

  test(
    'a backup from another vault is refused when this vault has items',
    () async {
      await a.setUpVault();
      await a.add('Bank');
      final b = await VaultTestBed.create(now);
      addTearDown(() async {
        await b.session.lock();
        await b.h.dispose();
      });
      await b.setUpVault('654321');
      final env = (await bridgeOf(b).exportKeyEnvelope())!;
      expect(await bridgeOf(a).acceptKeyEnvelope(env), isFalse);
      expect(await bridgeOf(a).acceptKeyEnvelope({'bundle': 'junk'}), isFalse);
    },
  );

  test(
    'imports are encrypted, filed by folder and need an open vault',
    () async {
      await a.setUpVault();
      final bridge = bridgeOf(a);
      final saved = await bridge.importLogins(const [
        ImportedLogin(
          title: 'GitHub',
          username: 'asif-dev',
          password: 'gh-pass-1',
          url: 'https://github.com',
          folder: 'Work',
          totpSecret: 'JBSWY3DPEHPK3PXP',
          isFavorite: true,
        ),
        ImportedLogin(
          title: '',
          password: 'pw-2',
          url: 'https://www.example.org/login',
          folder: 'work',
        ),
      ]);
      expect(saved, 2);
      final repo = a.h.read(vaultRepositoryProvider);
      final folders = await a.h
          .read(foldersRepositoryProvider)
          .watchFolders(ItemType.vault)
          .first;
      expect(folders.map((f) => f.name), ['Work']);
      final key = a.h.read(vaultSessionProvider).requireKey();
      final titles = <String>{};
      for (final id in await repo.allItemIds()) {
        final r = (await repo.getItem(id))!;
        titles.add(r.title);
        expect(r.folderId, folders.single.id);
        final p = await VaultPayloadCodec.open(
          key,
          r.encryptedPayload,
          itemId: id,
        );
        if (r.title == 'GitHub') {
          expect(p.password, 'gh-pass-1');
          expect(r.hasTotp, isTrue);
          expect(r.isFavorite, isTrue);
          expect(r.passwordFingerprint, isNotNull);
        }
      }
      expect(titles, {'GitHub', 'example.org'});

      await a.session.lock();
      await expectLater(
        bridge.importLogins(const [ImportedLogin(title: 'X', password: 'p')]),
        throwsA(isA<VaultUnavailable>()),
      );
    },
  );
}
