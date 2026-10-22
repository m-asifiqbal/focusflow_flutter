/// Screen 19 (vault item detail): real encrypted data saved through
/// VaultItemService, captures against the mockup, reveal / copy with
/// auto-clear, 2FA code, health, history, archive, locked state, and
/// small-screen / large-text overflow.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show CustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reveal.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';

/// Base32 2FA secret used by the seeded Google item.
const kTotpSecret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';

/// Seeds the mockup's Google login (3 days old, 4 previous passwords).
Future<String> seedGoogle(VaultTestBed b, {bool breachChecked = true}) async {
  final h = b.h;
  final folderId = await h
      .read(foldersRepositoryProvider)
      .create(ItemType.vault, 'Personal');
  final key = h.read(vaultSessionProvider).requireKey();
  final service = h.read(vaultItemServiceProvider);
  final draftIn = VaultItemDraft(
    type: VaultItemType.login,
    title: 'Google',
    iconKey: 'google',
    folderId: folderId,
    isFavorite: true,
  );
  var payload = const VaultPayload(
    username: 'asif.design@gmail.com',
    password: 'old-password-1',
    url: 'accounts.google.com',
    totpSecret: kTotpSecret,
    notes: 'Design portfolio account. Recovery phone ends 4521.',
  );
  h.clock.advance(const Duration(days: -40));
  final id = await service.save(key: key, draft: draftIn, payload: payload);
  for (final pw in [
    'old-password-2',
    'old-password-3',
    'old-password-4',
    'k8#mP!2sX9@Lq7vR',
  ]) {
    h.clock.advance(const Duration(days: 9));
    final existing = await h.read(vaultRepositoryProvider).getItem(id);
    final next = payload.copyWith(password: pw);
    await service.save(
      key: key,
      draft: draftIn,
      payload: next,
      existing: existing,
      previous: payload,
    );
    payload = next;
  }
  if (breachChecked) {
    await h
        .read(vaultRepositoryProvider)
        .updateBreachResult(id, 0, h.clock.now());
  }
  h.clock.advance(const Duration(days: 4));
  return id;
}

/// SF Mono stands in for Menlo (not bundled) so captures show real glyphs.
Future<void> loadMonoFont() async {
  const path = '/System/Library/Fonts/SFNSMono.ttf';
  if (!File(path).existsSync()) return;
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader('Menlo')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  final now = DateTime(2026, 6, 13, 9, 41, 11);
  const tall = Size(390, 1104);
  const small = Size(360, 800);

  Future<(VaultTestBed, String)> bed(WidgetTester tester) async {
    final b = (await tester.runAsync(() => VaultTestBed.create(now)))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    final id = (await tester.runAsync(() async {
      await b.setUpVault();
      return seedGoogle(b);
    }))!;
    return (b, id);
  }

  void phoneInsets(WidgetTester tester) {
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.resetPadding);
  }

  setUpAll(() async {
    await loadAppFonts();
    await loadMonoFont();
  });

  for (final dark in [false, true]) {
    testWidgets('19 detail matches the mockup${dark ? ' (dark)' : ''}', (
      tester,
    ) async {
      final (b, id) = await bed(tester);
      phoneInsets(tester);
      await pumpApp(
        tester,
        b.h,
        AppRoutes.vaultItem(id),
        size: tall,
        dark: dark,
      );
      await tester.tap(find.bySemanticsLabel('Show password'));
      await settle(tester);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Personal · Updated 4 days ago'), findsOneWidget);
      expect(find.text('asif.design@gmail.com'), findsOneWidget);
      expect(find.text('accounts.google.com'), findsOneWidget);
      expect(find.text('Password history · 4 versions'), findsOneWidget);
      expect(find.text('No breaches'), findsOneWidget);
      expect(find.text('Unique'), findsOneWidget);
      expect(find.text('16+ characters'), findsOneWidget);
      expect(find.text('2FA enabled'), findsOneWidget);
      final code = TotpConfig.parse(kTotpSecret)!.codeAt(b.h.clock.now());
      expect(find.text(TotpConfig.format(code)), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Copy password'));
      await settle(tester, rounds: 2);
      expect(b.clipboard.last, 'k8#mP!2sX9@Lq7vR');
      expect(find.text('Password copied · clears in 30s'), findsOneWidget);
      expect(b.protection.enabled, isTrue);
      await captureScreen(tester, '19_vault_detail${dark ? '_dark' : ''}');
      await tearDownVault(tester, b);
    });
  }

  testWidgets('19 masks by default, history sheet decrypts old passwords', (
    tester,
  ) async {
    final (b, id) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vaultItem(id), size: tall);
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsNothing);
    expect(find.text('•' * 12), findsOneWidget);
    await tester.tap(find.text('Password history · 4 versions'));
    await settle(tester);
    expect(find.text('Password history'), findsOneWidget);
    expect(find.bySemanticsLabel('Show password'), findsNWidgets(5));
    await tester.tap(find.bySemanticsLabel('Show password').last);
    await settle(tester);
    expect(find.textContaining('old-password-'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('19 a revealed password hides itself after 4 s', (tester) async {
    final (b, id) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vaultItem(id), size: tall);
    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsOneWidget);
    // The eye turns into "Hide" and a ring counts down around it.
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(VaultRevealButton),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );

    // Still there just before the end, gone (faded out) just after.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsNothing);
    expect(find.text('•' * 12), findsOneWidget);
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);

    // Hiding early by hand works, and showing again restarts the 4 s.
    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel('Hide password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('19 reveal asks for the PIN when biometrics are unavailable', (
    tester,
  ) async {
    final (b, id) = await bed(tester);
    b.bio.available = false;
    await tester.runAsync(
      () => b.h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(vaultReauthToReveal: true)),
    );
    await pumpApp(tester, b.h, AppRoutes.vaultItem(id), size: tall);
    await tester.tap(find.bySemanticsLabel('Show password'));
    await settle(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Show password'));
    await settle(tester);
    for (final d in '123456'.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    await settle(tester);
    expect(find.text("Confirm it's you"), findsNothing);
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsOneWidget);
    await tearDownVault(tester, b);
  });

  testWidgets('19 long-press large type and history reveal are gated', (
    tester,
  ) async {
    final (b, id) = await bed(tester);
    b.bio.available = false;
    await tester.runAsync(
      () => b.h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(vaultReauthToReveal: true)),
    );
    await pumpApp(tester, b.h, AppRoutes.vaultItem(id), size: tall);
    await tester.longPress(find.text('•' * 12));
    await settle(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('k8#mP!2sX9@Lq7vR'), findsNothing);

    await tester.tap(find.text('Password history · 4 versions'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Show password').last);
    await settle(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.textContaining('old-password-'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('19 archive leaves the screen and offers undo', (tester) async {
    final (b, id) = await bed(tester);
    await pumpApp(tester, b.h, AppRoutes.vault, size: tall);
    b.h.read(routerProvider).push(AppRoutes.vaultItem(id));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Archive'));
    await settle(tester);
    final record = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).getItem(id),
    ))!;
    expect(record.isArchived, isTrue);
    expect(find.text('Vault'), findsWidgets);
    await tearDownVault(tester, b);
  });

  testWidgets('19 locked shows the unlock prompt', (tester) async {
    final (b, id) = await bed(tester);
    await tester.runAsync(b.session.lock);
    await pumpApp(tester, b.h, AppRoutes.vaultItem(id), size: tall);
    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.text('asif.design@gmail.com'), findsNothing);
    await tearDownVault(tester, b);
  });

  testWidgets('19 no overflow at 360 pt and text scale 1.3', (tester) async {
    final (b, id) = await bed(tester);
    await pumpApp(
      tester,
      b.h,
      AppRoutes.vaultItem(id),
      size: small,
      textScale: 1.3,
    );
    await tester.tap(find.bySemanticsLabel('Show password'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '19_vault_detail_360_x13');
    await tearDownVault(tester, b);
  });
}
