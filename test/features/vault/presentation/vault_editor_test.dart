/// Screen 20 (vault item editor): mockup captures over a real encrypted
/// item, create / edit round trips through VaultItemService (ciphertext
/// only, password history), validation, type switching, discard prompt,
/// locked state and small-screen / large-text overflow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
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
import 'vault_detail_test.dart' show loadMonoFont;

const kFigmaPassword = r'X7$vQ2!pLm9#Tz4w';

/// The mockup's Figma login (Work folder, #design #tools, favourite,
/// 90-day expiry reminder).
Future<String> seedFigma(VaultTestBed b) async {
  final h = b.h;
  final folders = h.read(foldersRepositoryProvider);
  await folders.create(ItemType.vault, 'Personal');
  final work = await folders.create(ItemType.vault, 'Work');
  return h
      .read(vaultItemServiceProvider)
      .save(
        key: h.read(vaultSessionProvider).requireKey(),
        draft: VaultItemDraft(
          type: VaultItemType.login,
          title: 'Figma',
          iconKey: 'figma',
          folderId: work,
          tagNames: const ['design', 'tools'],
          isFavorite: true,
          expiryDays: 90,
        ),
        payload: const VaultPayload(
          username: 'asif.design@gmail.com',
          password: kFigmaPassword,
          url: 'figma.com',
          notes: 'Team plan admin. Billing owner is the design lead.',
        ),
      );
}

void main() {
  final now = DateTime(2026, 6, 13, 9, 41, 11);
  const tall = Size(390, 1223);
  const small = Size(360, 800);

  Future<(VaultTestBed, String)> bed(WidgetTester tester) async {
    final b = (await tester.runAsync(() => VaultTestBed.create(now)))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    final id = (await tester.runAsync(() async {
      await b.setUpVault();
      return seedFigma(b);
    }))!;
    return (b, id);
  }

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

  setUpAll(() async {
    await loadAppFonts();
    await loadMonoFont();
  });

  for (final dark in [false, true]) {
    testWidgets('20 editor matches the mockup${dark ? ' (dark)' : ''}', (
      tester,
    ) async {
      final (b, id) = await bed(tester);
      tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
      addTearDown(tester.view.resetPadding);
      await pumpApp(
        tester,
        b.h,
        AppRoutes.vaultItemEdit(id),
        size: tall,
        dark: dark,
      );
      expect(find.text('Edit Item'), findsOneWidget);
      expect(find.text('Figma'), findsOneWidget);
      expect(find.text(kFigmaPassword), findsOneWidget);
      expect(
        find.text('Very strong · would take centuries to crack'),
        findsOneWidget,
      );
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('#design #tools'), findsOneWidget);
      expect(find.text('90 days'), findsOneWidget);
      expect(find.text('Add field (PIN, security question…)'), findsOneWidget);
      expect(b.protection.enabled, isTrue);
      await captureScreen(tester, '20_vault_editor${dark ? '_dark' : ''}');
      await tearDownVault(tester, b);
    });
  }

  testWidgets('20 edit saves ciphertext and keeps the old password', (
    tester,
  ) async {
    final (b, id) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    b.h.read(routerProvider).push(AppRoutes.vaultItemEdit(id));
    await settle(tester);
    await tester.enterText(
      find.bySemanticsLabel('Password').last,
      'brand-new-Secret-42!',
    );
    await tester.enterText(find.bySemanticsLabel('Website'), 'www.figma.com');
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Save'));
    await settle(tester, rounds: 3);
    final p = await payloadOf(tester, b, id);
    expect(p.password, 'brand-new-Secret-42!');
    expect(p.url, 'www.figma.com');
    expect(p.username, 'asif.design@gmail.com');
    final history = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).watchHistory(id).first,
    ))!;
    expect(history, hasLength(1));
    final record = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).getItem(id),
    ))!;
    expect(record.title, 'Figma');
    expect(record.expiryDays, 90);
    expect(record.isFavorite, isTrue);
    expect(record.passwordStrength, isNotNull);
    expect(find.text('Edit Item'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('20 new card: title required, type fields, saves', (
    tester,
  ) async {
    final (b, _) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    b.h.read(routerProvider).push(AppRoutes.newVaultItem(type: 'card'));
    await settle(tester);
    expect(find.text('New Item'), findsOneWidget);
    expect(find.bySemanticsLabel('Card number'), findsOneWidget);
    expect(find.bySemanticsLabel('Username / email'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Save'));
    await settle(tester);
    expect(find.text('Add a title'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Title'), 'Visa Platinum');
    await tester.enterText(
      find.bySemanticsLabel('Card number'),
      '4242 4242 4242 4242',
    );
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Save'));
    await settle(tester, rounds: 3);
    final items = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).allItemIds(),
    ))!;
    expect(items, hasLength(2));
    String? cardId;
    for (final i in items) {
      final r = (await tester.runAsync(
        () => b.h.read(vaultRepositoryProvider).getItem(i),
      ))!;
      if (r.type == VaultItemType.card) cardId = r.id;
    }
    expect(cardId, isNotNull);
    expect(
      (await payloadOf(tester, b, cardId!)).cardNumber,
      '4242 4242 4242 4242',
    );
    // Back on the list, which shows the new card live.
    expect(find.text('New Item'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('20 switching type and cancelling asks to discard', (
    tester,
  ) async {
    final (b, id) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    b.h.read(routerProvider).push(AppRoutes.vaultItemEdit(id));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Wi-Fi'));
    await settle(tester);
    expect(find.bySemanticsLabel('Network name (SSID)'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.text('Edit Item'), findsNothing);
    final record = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).getItem(id),
    ))!;
    expect(record.type, VaultItemType.login);
    await tearDownVault(tester, b);
  });

  testWidgets('20 custom field is added and encrypted', (tester) async {
    final (b, id) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vaultItemEdit(id), size: tall);
    await tester.tap(find.bySemanticsLabel('Add custom field'));
    await settle(tester);
    await tester.tap(find.text('PIN'));
    await settle(tester);
    await tester.enterText(find.bySemanticsLabel('Value'), '4521');
    await tester.tap(find.text('Save field'));
    await settle(tester);
    expect(find.text('••••'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Save'));
    await settle(tester, rounds: 3);
    final p = await payloadOf(tester, b, id);
    expect(p.customFields.single.label, 'PIN');
    expect(p.customFields.single.value, '4521');
    expect(p.customFields.single.hidden, isTrue);
    await tearDownVault(tester, b);
  });

  testWidgets('20 locked shows the unlock prompt', (tester) async {
    final (b, id) = await bed(tester);
    await tester.runAsync(b.session.lock);
    await pumpApp(tester, b.h, AppRoutes.vaultItemEdit(id), size: tall);
    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.text(kFigmaPassword), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('20 no overflow at 360 pt and text scale 1.3', (tester) async {
    final (b, id) = await bed(tester);
    await pumpApp(
      tester,
      b.h,
      AppRoutes.vaultItemEdit(id),
      size: small,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '20_vault_editor_360_x13');
    await tester.scrollUntilVisible(
      find.text('Add field (PIN, security question…)'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tearDownVault(tester, b);
  });
}
