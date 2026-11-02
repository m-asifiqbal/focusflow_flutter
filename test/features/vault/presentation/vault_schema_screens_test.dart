/// The schema-driven vault types end to end: saving through the service
/// (only the type's own keys survive, the password / 2FA slots follow the
/// type), per-type counts, the "+" type picker, the generic editor and
/// detail cards, document-expiry badges and Duplicate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';

const _totp = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
const _iban = 'GB82WEST12345698765432';

void main() {
  final now = DateTime(2026, 6, 13, 9, 41, 11);
  const tall = Size(390, 1600);

  Future<VaultTestBed> bed(WidgetTester tester) async {
    final b = (await tester.runAsync(() => VaultTestBed.create(now)))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    await tester.runAsync(b.setUpVault);
    return b;
  }

  Future<String> save(
    WidgetTester tester,
    VaultTestBed b,
    VaultItemType type,
    String title,
    VaultPayload payload, {
    String? iconKey,
  }) async => (await tester.runAsync(
    () => b.h
        .read(vaultItemServiceProvider)
        .save(
          key: b.h.read(vaultSessionProvider).requireKey(),
          draft: VaultItemDraft(type: type, title: title, iconKey: iconKey),
          payload: payload,
        ),
  ))!;

  Future<VaultPayload> payloadOf(
    WidgetTester tester,
    VaultTestBed b,
    String id,
  ) async => (await tester.runAsync(() async {
    final r = await b.h.read(vaultRepositoryProvider).getItem(id);
    return VaultPayloadCodec.open(
      b.h.read(vaultSessionProvider).requireKey(),
      r!.encryptedPayload,
      itemId: id,
    );
  }))!;

  VaultPayload bankPayload() => const VaultPayload(
    password: 'Corr3ct-Horse!Battery',
    totpSecret: _totp,
    notes: 'Main salary account',
  ).withField('holder', 'Asif Iqbal').withField('number', '1234567890').withField('iban', _iban);

  testWidgets('saving keeps only the type\'s own keys and slots', (
    tester,
  ) async {
    final b = await bed(tester);
    final dirty = bankPayload()
        .withField('bogus', 'leftover from another type')
        .withField('seed', 'abandon ability able') // a crypto-wallet key
        .withField('bank', '  HSBC  ');
    final bankId = await save(tester, b, VaultItemType.bankAccount, 'HSBC', dirty);
    final bank = await payloadOf(tester, b, bankId);
    expect(bank.fields.keys.toSet(), {'holder', 'number', 'iban', 'bank'});
    expect(bank.field('bank'), 'HSBC'); // trimmed
    expect(bank.password, 'Corr3ct-Horse!Battery');
    expect(bank.totpSecret, _totp);
    final record = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).getItem(bankId),
    ))!;
    expect(record.type, VaultItemType.bankAccount);
    expect(record.hasTotp, isTrue);
    expect(record.passwordStrength, isNotNull);
    expect(record.passwordFingerprint, isNotNull);
    // The database row never holds a secret in clear.
    expect(String.fromCharCodes(record.encryptedPayload), isNot(contains(_iban)));

    // A passport has no password or 2FA slot: a switch from a login cannot
    // leave a hidden one behind.
    final passportId = await save(
      tester,
      b,
      VaultItemType.passport,
      'Passport',
      bankPayload().withField('number', 'AB1234567'),
    );
    final passport = await payloadOf(tester, b, passportId);
    expect(passport.password, isEmpty);
    expect(passport.totpSecret, isNull);
    expect(passport.fields.keys.toSet(), {'number'});
    final p = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).getItem(passportId),
    ))!;
    expect(p.hasTotp, isFalse);
    expect(p.passwordStrength, isNull);
    expect(p.passwordFingerprint, isNull);

    // An over-long value is cut to what a payload can decode again.
    final longId = await save(
      tester,
      b,
      VaultItemType.apiKey,
      'Key',
      const VaultPayload().withField('key', 'k' * (VaultPayload.maxFieldValue + 50)),
    );
    expect((await payloadOf(tester, b, longId)).field('key').length, VaultPayload.maxFieldValue);
    await tearDownVault(tester, b);
  });

  testWidgets('counts include every type in one query', (tester) async {
    final b = await bed(tester);
    await save(tester, b, VaultItemType.bankAccount, 'A', bankPayload());
    await save(tester, b, VaultItemType.bankAccount, 'B', bankPayload());
    await save(tester, b, VaultItemType.vehicle, 'Car', const VaultPayload());
    await save(tester, b, VaultItemType.login, 'L', const VaultPayload(username: 'u'));
    final counts = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).watchCounts().first,
    ))!;
    expect(counts.total, 4);
    expect(counts.of(VaultItemType.bankAccount), 2);
    expect(counts.of(VaultItemType.vehicle), 1);
    expect(counts.of(VaultItemType.login), 1);
    expect(counts.of(VaultItemType.server), 0);
    expect(counts.byType.keys.toSet(), VaultItemType.values.toSet());
    expect(counts.withTotp, 2);
    await tearDownVault(tester, b);
  });

  testWidgets('list: masked subtitle, expiry badge, tiles of used types', (
    tester,
  ) async {
    final b = await bed(tester);
    await save(tester, b, VaultItemType.bankAccount, 'HSBC Savings', bankPayload());
    // Expires in 18 days → EXPIRING; another one is long past → EXPIRED.
    await save(
      tester,
      b,
      VaultItemType.passport,
      'My passport',
      const VaultPayload().withField('expires', '2026-07-01'),
    );
    await save(
      tester,
      b,
      VaultItemType.driverLicense,
      'Old licence',
      const VaultPayload().withField('expires', '2024-01-31'),
    );
    await save(
      tester,
      b,
      VaultItemType.softwareLicense,
      'Far licence',
      const VaultPayload().withField('expires', '2031-01-01'),
    );
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    expect(find.text('Asif Iqbal · •••• 7890'), findsOneWidget);
    expect(find.text('EXPIRING'), findsOneWidget);
    expect(find.text('EXPIRED'), findsOneWidget);
    // Tiles: the four everyday types + the types in use — not all eighteen.
    expect(find.text('Bank accounts'), findsOneWidget);
    expect(find.text('Passports'), findsOneWidget);
    expect(find.text('Servers'), findsNothing);
    expect(find.text('Vehicles'), findsNothing);
    // Filtering by a new type narrows the list live.
    await tester.ensureVisible(find.text('Bank accounts'));
    await tester.tap(find.text('Bank accounts'));
    await settle(tester);
    expect(find.text('HSBC Savings'), findsOneWidget);
    expect(find.text('My passport'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('+ asks for a type, then opens the editor on it', (tester) async {
    final b = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    await tester.tap(find.bySemanticsLabel('Add password').first);
    await settle(tester);
    expect(find.text('What do you want to save?'), findsOneWidget);
    for (final g in [
      'EVERYDAY',
      'FINANCE',
      'IDENTITY & HEALTH',
      'DIGITAL & DEVELOPER',
      'LIFESTYLE',
    ]) {
      expect(find.text(g), findsOneWidget, reason: g);
    }
    for (final t in ['Login', 'Bank account', 'Crypto wallet', 'Passport', 'Server', 'Vehicle']) {
      expect(find.bySemanticsLabel(t), findsWidgets, reason: t);
    }
    await tester.tap(find.bySemanticsLabel('Bank account').first);
    await settle(tester);
    expect(find.text('New Item'), findsOneWidget);
    expect(find.bySemanticsLabel('Bank name'), findsOneWidget);
    expect(find.bySemanticsLabel('Username / email'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('editor: bank account sections, soft IBAN check, saves', (
    tester,
  ) async {
    final b = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    b.h.read(routerProvider).push(AppRoutes.newVaultItem(type: 'bankAccount'));
    await settle(tester);
    for (final s in ['ACCOUNT', 'ONLINE BANKING', 'PINS & SECURITY', 'CONTACT']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    await tester.enterText(find.bySemanticsLabel('Title'), 'Salary account');
    await tester.enterText(find.bySemanticsLabel('Bank name'), 'HSBC');
    await tester.enterText(find.bySemanticsLabel('IBAN'), 'GB83WEST12345698765432');
    await settle(tester);
    expect(find.text("This IBAN doesn't look valid"), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('IBAN'), _iban);
    await settle(tester);
    expect(find.text("This IBAN doesn't look valid"), findsNothing);
    await tester.enterText(find.bySemanticsLabel('Password').last, 'Sup3r-Secret-Pass!');
    await tester.tap(find.bySemanticsLabel('Save'));
    await settle(tester, rounds: 3);
    final ids = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).allItemIds(),
    ))!;
    expect(ids, hasLength(1));
    final p = await payloadOf(tester, b, ids.single);
    expect(p.field('bank'), 'HSBC');
    expect(p.field('iban'), _iban);
    expect(p.password, 'Sup3r-Secret-Pass!');
    await tearDownVault(tester, b);
  });

  testWidgets('editor: a date field opens the calendar and shows the expiry', (
    tester,
  ) async {
    final b = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    b.h.read(routerProvider).push(AppRoutes.newVaultItem(type: 'passport'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Expiry date: Not set'));
    await settle(tester);
    expect(find.text('Clear date'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    // The sheet's initial day is "today" (the test clock).
    expect(find.text('13 Jun 2026 · Expires today'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Expiry date: 13 Jun 2026 · Expires today'));
    await settle(tester);
    await tester.tap(find.text('Clear date'));
    await settle(tester);
    expect(find.bySemanticsLabel('Expiry date: Not set'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('detail: sections, masked numbers, expiry note, 2FA', (
    tester,
  ) async {
    final b = await bed(tester);
    final id = await save(tester, b, VaultItemType.bankAccount, 'HSBC Savings', bankPayload());
    final pid = await save(
      tester,
      b,
      VaultItemType.passport,
      'My passport',
      const VaultPayload()
          .withField('fullName', 'Asif Iqbal')
          .withField('number', 'AB1234567')
          .withField('expires', '2026-07-01'),
    );
    await pumpApp(tester, b.h, AppRoutes.vaultItem(id), size: tall);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('ONLINE BANKING'), findsOneWidget);
    expect(find.text('Asif Iqbal'), findsOneWidget);
    // The account number and the IBAN are masked until revealed.
    expect(find.text('1234567890'), findsNothing);
    expect(find.text(_iban), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show iban'));
    await settle(tester);
    expect(find.text('GB82 WEST 1234 5698 7654 32'), findsOneWidget);
    expect(find.text('One-time code (2FA)'.toUpperCase()), findsOneWidget);
    await tearDownVault(tester, b);

    final b2 = await bed(tester);
    final pid2 = await save(
      tester,
      b2,
      VaultItemType.passport,
      'My passport',
      const VaultPayload()
          .withField('number', 'AB1234567')
          .withField('expires', '2026-07-01'),
    );
    await pumpApp(tester, b2.h, AppRoutes.vaultItem(pid2), size: tall);
    expect(find.text('1 Jul 2026'), findsOneWidget);
    expect(find.text('Expires in 18 days'), findsOneWidget);
    expect(pid, isNotEmpty);
    await tearDownVault(tester, b2);
  });

  testWidgets('long-press → Duplicate makes an independent copy', (tester) async {
    final b = await bed(tester);
    await save(tester, b, VaultItemType.bankAccount, 'HSBC Savings', bankPayload());
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    await tester.longPress(find.text('HSBC Savings'));
    await settle(tester);
    expect(find.text('Copy iban'), findsOneWidget);
    await tester.tap(find.text('Duplicate'));
    await settle(tester, rounds: 5);
    final repo = b.h.read(vaultRepositoryProvider);
    final all = (await tester.runAsync(repo.getAll))!;
    expect(all.map((r) => r.title).toSet(), {'HSBC Savings', 'HSBC Savings (copy)'});
    final copy = all.firstWhere((r) => r.title.endsWith('(copy)'));
    final p = await payloadOf(tester, b, copy.id);
    expect(p.field('iban'), _iban);
    expect(copy.isFavorite, isFalse);
    expect(copy.type, VaultItemType.bankAccount);
    await tearDownVault(tester, b);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360 pt and text 1.3 (picker, editor, detail)${dark ? ' dark' : ''}', (
      tester,
    ) async {
      final b = await bed(tester);
      final id = await save(tester, b, VaultItemType.bankAccount, 'HSBC Savings', bankPayload());
      await pumpApp(
        tester,
        b.h,
        AppRoutes.vaultItem(id),
        size: const Size(360, 800),
        textScale: 1.3,
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      b.h.read(routerProvider).push(AppRoutes.vaultItemEdit(id));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
      await tearDownVault(tester, b);
    });
  }
}
