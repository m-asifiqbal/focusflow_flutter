/// Screens 17 (vault locked / first-run PIN) and 18 (vault list): real
/// encrypted data, captures against the mockups, PIN pad behaviour,
/// copy-with-auto-clear, filters, screenshot blocking, the unlock sheet
/// behind ensureVaultUnlocked, small-screen / large-text overflow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_alphabet_scrubber.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';

void main() {
  final now = DateTime(2026, 6, 13, 9, 41);
  const tall17 = Size(390, 1119);
  const tall18 = Size(390, 1020);
  const small = Size(360, 800);

  Future<VaultTestBed> bed(
    WidgetTester tester, {
    bool setUp = true,
    bool seed = true,
    bool locked = false,
  }) async {
    final b = (await tester.runAsync(() => VaultTestBed.create(now)))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    await tester.runAsync(() async {
      if (setUp) await b.setUpVault();
      if (seed) await b.seedMockup();
      if (locked) await b.session.lock();
    });
    return b;
  }

  /// Simulates the iPhone status bar / home indicator like the mockups.
  void phoneInsets(WidgetTester tester) {
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.resetPadding);
  }

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    await settle(tester);
  }

  bool unlocked(VaultTestBed b) => b.h.read(vaultSessionProvider).isUnlocked;

  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    final suffix = dark ? '_dark' : '';
    testWidgets('18 list matches the mockup${dark ? ' (dark)' : ''}', (
      tester,
    ) async {
      final b = await bed(tester);
      phoneInsets(tester);
      await pumpApp(tester, b.h, AppRoutes.vault, size: tall18, dark: dark);
      b.h.clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Unlocked · auto-locks in 4:59'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('asif.design@gmail.com'), findsWidgets);
      expect(find.text('BREACHED'), findsOneWidget);
      expect(find.text('REUSED'), findsWidgets);
      expect(find.text('WEAK'), findsOneWidget);
      expect(find.text('1 password found in a data breach'), findsOneWidget);
      expect(find.text('16 items'), findsOneWidget);
      expect(b.protection.enabled, isTrue);
      await captureScreen(tester, '18_vault_list$suffix');
      await tearDownVault(tester, b);
      expect(b.protection.enabled, isFalse);
    });

    testWidgets('17 locked matches the mockup${dark ? ' (dark)' : ''}', (
      tester,
    ) async {
      final b = await bed(tester, locked: true);
      phoneInsets(tester);
      await pumpApp(tester, b.h, AppRoutes.vault, size: tall17, dark: dark);
      expect(b.bio.prompts, 1, reason: 'biometrics auto-prompt on open');
      expect(find.text('Vault Locked'), findsOneWidget);
      expect(find.text('Unlock with Face ID'), findsOneWidget);
      expect(find.text('24 items · AES-256 encrypted'), findsOneWidget);
      expect(find.text('asif.design@gmail.com'), findsNothing);
      await tapDigits(tester, '12');
      await captureScreen(tester, '17_vault_locked$suffix');
      await tearDownVault(tester, b);
    });
  }

  testWidgets('correct PIN unlocks into the list; wrong PIN shakes', (
    tester,
  ) async {
    final b = await bed(tester, locked: true);
    await pumpApp(tester, b.h, AppRoutes.vault);
    await tapDigits(tester, '000000');
    expect(unlocked(b), isFalse);
    expect(find.text('Wrong PIN · 4 tries left'), findsOneWidget);
    await tapDigits(tester, '123456');
    expect(unlocked(b), isTrue);
    expect(find.text('Logins'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Lock vault'));
    await settle(tester);
    expect(unlocked(b), isFalse);
    expect(find.text('Vault Locked'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('"Use master PIN instead" hides the biometric button', (
    tester,
  ) async {
    final b = await bed(tester, locked: true, seed: false);
    await pumpApp(tester, b.h, AppRoutes.vault);
    await tester.tap(find.text('Use master PIN instead'));
    await settle(tester);
    expect(find.text('Unlock with Face ID'), findsNothing);
    expect(find.text('Forgot PIN?'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('first run: create + confirm the master PIN', (tester) async {
    final b = await bed(tester, setUp: false, seed: false);
    await pumpApp(tester, b.h, AppRoutes.vault);
    expect(find.text('Create master PIN'), findsOneWidget);
    await tapDigits(tester, '246810');
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await tapDigits(tester, '111111');
    expect(find.text("PINs didn't match · try again"), findsOneWidget);
    await tapDigits(tester, '246810');
    await tapDigits(tester, '246810');
    expect(unlocked(b), isTrue);
    expect(find.text('Your vault is ready'), findsOneWidget);
    expect(find.text('Add your first password'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('copy button copies the password with auto-clear toast', (
    tester,
  ) async {
    final b = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall18);
    await tester.tap(find.bySemanticsLabel('Copy password for Google'));
    await settle(tester);
    expect(b.clipboard, ['G00gle-strong-pass!']);
    expect(find.text('Password copied · clears in 30s'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('category tile, favourites chip and search filter live', (
    tester,
  ) async {
    final b = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall18);
    await tester.tap(find.bySemanticsLabel('Cards, 3 items'));
    await settle(tester);
    expect(find.text('Visa Platinum'), findsOneWidget);
    expect(find.text('•••• 4242'), findsWidgets);
    expect(find.text('Google'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Cards, 3 items'));
    await tester.tap(find.bySemanticsLabel('Favourites').first);
    await settle(tester);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Figma'), findsNothing);
    await tester.tap(find.bySemanticsLabel('All, 24'));
    await tester.enterText(find.byType(TextField), 'net');
    await settle(tester);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
    // The username (decrypted subtitle) is searchable too.
    await tester.enterText(find.byType(TextField), 'asif.design');
    await settle(tester);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('long A–Z list: the alphabet scrubber jumps to a letter', (
    tester,
  ) async {
    final b = await bed(tester, seed: false);
    await tester.runAsync(() async {
      for (final t in [
        for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) '$c site',
        ...['Alpha 2', 'Beta 2', 'Gamma 2', 'Delta 2', '9 lives'],
      ]) {
        await b.add(t, username: 'me@example.com', password: 'pw-$t-strong');
      }
    });
    await pumpApp(tester, b.h, AppRoutes.vault);
    expect(find.bySemanticsLabel('Alphabet index'), findsOneWidget);
    expect(find.text('Z site').hitTestable(), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(VaultAlphabetScrubber),
        matching: find.text('Z'),
      ),
    );
    await settle(tester);
    expect(find.text('Z site').hitTestable(), findsOneWidget);
    // A search hides the index.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'site');
    await settle(tester);
    expect(find.bySemanticsLabel('Alphabet index'), findsNothing);
    await tearDownVault(tester, b);
  });

  test('vaultIndexLetter and vaultWebsiteUri', () {
    expect(vaultIndexLetter('github'), 'G');
    expect(vaultIndexLetter('9 lives'), '#');
    expect(vaultIndexLetter(''), '#');
    expect(vaultWebsiteUri('github.com')?.toString(), 'https://github.com');
    expect(vaultWebsiteUri('http://x.org/a')?.scheme, 'http');
    expect(vaultWebsiteUri('javascript:alert(1)'), isNull);
    expect(vaultWebsiteUri('file:///etc/passwd'), isNull);
    expect(vaultWebsiteUri('  '), isNull);
  });

  testWidgets('screenshot blocking follows the setting', (tester) async {
    final b = await bed(tester, seed: false);
    await tester.runAsync(
      () => b.h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(vaultBlockScreenshots: false)),
    );
    await pumpApp(tester, b.h, AppRoutes.vault);
    expect(b.protection.enableCalls, 0);
    await tearDownVault(tester, b);
  });

  testWidgets('ensureVaultUnlocked shows the PIN sheet and returns true', (
    tester,
  ) async {
    final b = await bed(tester, locked: true, seed: false);
    bool? result;
    await pumpScreen(
      tester,
      b.h,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async =>
                  result = await ensureVaultUnlocked(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.text('Vault Locked'), findsOneWidget);
    await tapDigits(tester, '123456');
    expect(result, isTrue);
    expect(find.text('Vault Locked'), findsNothing);
    await tearDownVault(tester, b);
  });

  for (final locked in [false, true]) {
    testWidgets('no overflow at 360 pt, text 1.3 (${locked ? 17 : 18})', (
      tester,
    ) async {
      final b = await bed(tester, locked: locked);
      await pumpApp(tester, b.h, AppRoutes.vault, size: small, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await captureScreen(
        tester,
        '${locked ? '17_vault_locked' : '18_vault_list'}_360_x13',
      );
      await tearDownVault(tester, b);
    });
  }
}
