// Settings › Vault security › Face ID / Fingerprint: the switch shows
// whether biometric unlock really works, tapping a "broken on" switch turns
// it on (instead of asking the PIN to turn off something that never
// worked), the switch can't start a second flow while its PIN sheet is up,
// a PIN check from an earlier sheet can't finish the next one, and a quick
// off → on keeps the key copy.
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_security_settings_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';

void main() {
  final now = DateTime(2026, 6, 13, 9, 41);

  Future<VaultTestBed> bed(WidgetTester tester) async {
    final b = (await tester.runAsync(() => VaultTestBed.create(now)))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    await tester.runAsync(b.setUpVault);
    return b;
  }

  FFListRow bioRow(WidgetTester tester) => tester.widget<FFListRow>(
    find.ancestor(
      of: find.text('Face ID / Fingerprint'),
      matching: find.byType(FFListRow),
    ),
  );

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    await settle(tester);
  }

  setUpAll(loadAppFonts);

  testWidgets('a setting with no key copy shows OFF; tapping turns it on', (
    tester,
  ) async {
    final b = await bed(tester);
    expect(b.h.read(vaultSessionProvider).biometricsReady, isTrue);
    // The copy is lost (fingerprint re-enrolled / restore) — setting stays on.
    await tester.runAsync(() async {
      await b.h.read(vaultKeyManagerProvider).disableBiometrics();
      await b.session.refresh();
    });
    expect(b.h.read(settingsProvider).vaultBiometrics, isTrue);
    expect(b.h.read(vaultSessionProvider).biometricsReady, isFalse);

    await pumpApp(tester, b.h, AppRoutes.settingsVaultSecurity);
    await settle(tester, rounds: 3);
    expect(bioRow(tester).switchValue, isFalse);

    await tester.tap(find.text('Face ID / Fingerprint'));
    await settle(tester);
    // Turning ON: the PIN confirms it (no biometrics to use yet) …
    expect(find.text("Confirm it's you"), findsOneWidget);
    // … and the switch can't start a second flow meanwhile.
    expect(bioRow(tester).onSwitchChanged, isNull);
    await tapDigits(tester, '123456');
    await settle(tester);

    expect(find.text("Confirm it's you"), findsNothing);
    expect(b.h.read(vaultSessionProvider).biometricsReady, isTrue);
    expect(bioRow(tester).switchValue, isTrue);
    expect(bioRow(tester).onSwitchChanged, isNotNull);
    await tearDownVault(tester, b);
  });

  testWidgets('a quick off → on keeps the biometric copy', (tester) async {
    final b = await bed(tester);
    final c = b.h.read(vaultSecuritySettingsControllerProvider);
    await tester.runAsync(() async {
      final off = c.setBiometrics(false);
      final on = c.setBiometrics(true);
      await off;
      expect(await on, isTrue);
      // Let the setting listeners (queued behind the enable) run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(b.h.read(settingsProvider).vaultBiometrics, isTrue);
    expect(b.h.read(vaultSessionProvider).biometricsReady, isTrue);
    expect(
      await tester.runAsync(
        () => b.h.read(vaultKeyManagerProvider).hasBiometricCopy(),
      ),
      isTrue,
    );
    await tearDownVault(tester, b);
  });

  test('a PIN check of an earlier sheet cannot finish the next one', () async {
    final b = await VaultTestBed.create(now);
    addTearDown(b.h.dispose);
    await b.setUpVault();
    final sub = b.h.container.listen(vaultPinPadProvider, (_, _) {});
    addTearDown(sub.close);
    final pad = b.h.read(vaultPinPadProvider.notifier)..startReauth();
    for (final d in '12345'.split('')) {
      await pad.input(d);
    }
    // Sixth digit: the check runs …
    final checking = pad.input('6');
    // … while the next sheet (unlock) takes the shared pad over.
    pad.startUnlock();
    await checking;
    final state = b.h.read(vaultPinPadProvider);
    expect(state.done, isFalse);
    expect(state.step, VaultPadStep.unlock);
    expect(state.length, 0);
  });
}
