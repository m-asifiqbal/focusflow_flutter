// Screen 33 — Settings › Vault security: mockup captures, re-auth before
// every change, change PIN keeps items decryptable, Recovery Kit PDF,
// not-set-up state and small-screen overflow.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/vault/data/datasource/recovery_kit_pdf.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_security_settings_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';

class _FakeShare implements RecoveryKitShare {
  Uint8List? pdf;
  String? fileName;

  @override
  Future<bool> share(Uint8List pdf, {required String fileName}) async {
    this.pdf = pdf;
    this.fileName = fileName;
    return true;
  }
}

void main() {
  final now = DateTime(2026, 6, 13, 9, 41);
  const mockup = Size(390, 1249);
  const small = Size(360, 800);

  Future<VaultTestBed> bed(
    WidgetTester tester, {
    bool setUp = true,
    _FakeShare? share,
  }) async {
    final b = (await tester.runAsync(
      () => VaultTestBed.create(
        now,
        overrides: [
          if (share != null) recoveryKitShareProvider.overrideWithValue(share),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    await tester.runAsync(() async {
      await b.session.ready;
      if (setUp) {
        await b.setUpVault();
        await b.add('GitHub', username: 'asif', password: 'hunter2-Pass!x');
      }
      await b.h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(breachMonitoring: true));
    });
    return b;
  }

  Future<void> open(
    WidgetTester tester,
    VaultTestBed b, {
    Size size = mockup,
    bool dark = false,
    double textScale = 1,
  }) async {
    await pumpApp(
      tester,
      b.h,
      AppRoutes.settingsVaultSecurity,
      size: size,
      dark: dark,
      textScale: textScale,
    );
    await settle(tester, rounds: 3);
  }

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    await settle(tester);
  }

  Future<void> tapRow(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(f);
    await settle(tester);
  }

  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    testWidgets(
      '33 vault security matches the mockup${dark ? ' (dark)' : ''}',
      (tester) async {
        final b = await bed(tester);
        tester.view.padding = const FakeViewPadding(
          top: 47 * 3,
          bottom: 34 * 3,
        );
        addTearDown(tester.view.resetPadding);
        await open(tester, b, dark: dark);
        expect(find.text('Vault Security'), findsOneWidget);
        expect(find.text('Zero-knowledge encryption'), findsOneWidget);
        expect(find.text('6 digits'), findsOneWidget);
        expect(find.text('After 5 min'), findsOneWidget);
        expect(find.text('30 s'), findsOneWidget);
        expect(
          find.text('Wipe vault after 10 failed attempts'),
          findsOneWidget,
        );
        await captureScreen(
          tester,
          '33_vault_security_settings${dark ? '_dark' : ''}',
        );
        await tearDownVault(tester, b);
      },
    );
  }

  testWidgets('33 a change asks for the PIN first; cancel keeps it', (
    tester,
  ) async {
    final b = await bed(tester);
    await open(tester, b);
    await tapRow(tester, 'Block screenshots in Vault');
    expect(find.text("Confirm it's you"), findsOneWidget);
    await captureScreen(tester, '33_vault_reauth_sheet');
    expect(b.h.read(settingsProvider).vaultBlockScreenshots, isTrue);
    await tapDigits(tester, '000000');
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(b.h.read(settingsProvider).vaultBlockScreenshots, isTrue);

    await tapRow(tester, 'Block screenshots in Vault');
    await tapDigits(tester, '123456');
    expect(find.text("Confirm it's you"), findsNothing);
    expect(b.h.read(settingsProvider).vaultBlockScreenshots, isFalse);
    await tearDownVault(tester, b);
  });

  testWidgets('33 auto-lock picker applies after re-auth', (tester) async {
    final b = await bed(tester);
    await open(tester, b);
    await tapRow(tester, 'Auto-lock vault');
    await tester.tap(find.text('After 15 min'));
    await settle(tester);
    await tapDigits(tester, '123456');
    expect(b.h.read(settingsProvider).vaultAutoLockMinutes, 15);
    expect(find.text('After 15 min'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('33 change PIN re-wraps the key; items stay decryptable', (
    tester,
  ) async {
    final b = await bed(tester);
    await open(tester, b);
    await tapRow(tester, 'Change master PIN');
    expect(find.text('Change master PIN'), findsWidgets);
    await tapDigits(tester, '123456');
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await tapDigits(tester, '246810');
    expect(find.text('Confirm new PIN'), findsOneWidget);
    await tapDigits(tester, '246810');
    expect(find.text('Choose a new PIN'), findsNothing);
    expect(find.text('Master PIN changed'), findsOneWidget);

    await tester.runAsync(() async {
      await b.session.lock();
      expect(await b.session.unlockWithPin('123456'), UnlockResult.wrongPin);
      expect(await b.session.unlockWithPin('246810'), UnlockResult.success);
      final key = b.h.read(vaultSessionProvider).requireKey();
      final repo = b.h.read(vaultRepositoryProvider);
      final id = (await repo.allItemIds()).single;
      final record = await repo.getItem(id);
      final payload = await VaultPayloadCodec.open(
        key,
        record!.encryptedPayload,
        itemId: id,
      );
      expect(payload.password, 'hunter2-Pass!x');
    });
    await tearDownVault(tester, b);
  });

  testWidgets('33 recovery kit renders a PDF and shares it', (tester) async {
    final share = _FakeShare();
    final b = await bed(tester, share: share);
    await open(tester, b);
    await tapRow(tester, 'Recovery kit (PDF)');
    await tester.tap(find.text('Create kit'));
    await settle(tester);
    await tapDigits(tester, '123456');
    for (var i = 0; i < 5 && share.pdf == null; i++) {
      await settle(tester, rounds: 2);
    }
    expect(share.pdf, isNotNull);
    expect(latin1.decode(share.pdf!.sublist(0, 5)), '%PDF-');
    expect(share.fileName, 'FocusFlow-Recovery-Kit-2026-06-13.pdf');
    await tearDownVault(tester, b);
  });

  testWidgets('33 without a vault shows the set-up call to action', (
    tester,
  ) async {
    final b = await bed(tester, setUp: false);
    await open(tester, b);
    expect(find.text('Set up vault'), findsOneWidget);
    expect(find.text('UNLOCK'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('33 no overflow at 360 pt and text scale 1.3', (tester) async {
    final b = await bed(tester);
    await open(tester, b, size: small, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tearDownVault(tester, b);
  });
}
