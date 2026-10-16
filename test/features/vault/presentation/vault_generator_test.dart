/// Screen 21 (vault Generator tab): captures against the mockup, copy with
/// auto-clear into the encrypted history, passphrase / PIN modes, "Save to
/// new vault item" prefilling the editor (in memory, not the URL), and
/// small-screen / large-text overflow.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_generator_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_generator_state.dart';
import 'package:focusflow/features/vault/presentation/widgets/generator/vault_generator_options.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_tab_bar.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';
import 'vault_detail_test.dart' show loadMonoFont;

/// Returns the mockup's password first, then real random values.
class _MockupGenerator extends PasswordGenerator {
  bool _first = true;

  @override
  GeneratedValue password(PasswordOptions options) {
    if (_first && options.length == 16) {
      _first = false;
      return const GeneratedValue(
        'k8#mP!2sX9@Lq7v',
        98,
        GeneratorMode.password,
      );
    }
    return super.password(options);
  }
}

/// Locks in the real zone (drift closes streams with Timer.run), then
/// unmounts and lets auto-dispose providers close theirs.
Future<void> _tearDown(WidgetTester tester, VaultTestBed b) async {
  await tester.runAsync(() async {
    await b.session.lock();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  final now = DateTime(2026, 6, 13, 9, 41, 11);
  const tall = Size(390, 1170);
  const small = Size(360, 800);

  Future<VaultTestBed> bed(WidgetTester tester, {bool history = true}) async {
    final b = (await tester.runAsync(
      () => VaultTestBed.create(
        now,
        overrides: [
          passwordGeneratorProvider.overrideWithValue(_MockupGenerator()),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    await tester.runAsync(() async {
      await b.setUpVault();
      if (!history) return;
      final key = b.h.read(vaultSessionProvider).requireKey();
      final repo = b.h.read(vaultRepositoryProvider);
      Future<void> add(String v, String mode, Duration ago) async {
        b.h.clock.advance(-ago);
        await repo.addGeneratorEntry(
          await VaultCipher.sealString(
            key.secretKey,
            v,
            aad: VaultAad.generator,
          ),
          mode: mode,
        );
        b.h.clock.advance(ago);
      }

      await add(
        'orbit-maple-candle-42',
        'passphrase',
        const Duration(hours: 1),
      );
      await add('Hq9!vT2#xLm4', 'password', const Duration(minutes: 2));
    });
    return b;
  }

  Future<void> openGenerator(
    WidgetTester tester,
    VaultTestBed b, {
    Size size = tall,
    bool dark = false,
    double textScale = 1,
  }) async {
    await pumpApp(
      tester,
      b.h,
      AppRoutes.vault,
      size: size,
      dark: dark,
      textScale: textScale,
    );
    final container = b.h.container;
    container.read(vaultTabProvider.notifier).select(VaultTab.generator);
    await settle(tester);
  }

  void phoneInsets(WidgetTester tester) {
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.resetPadding);
  }

  setUpAll(() async {
    await loadAppFonts();
    await loadMonoFont();
    // Loaded in the real zone: a first load started inside a test's fake
    // zone would never complete under runAsync.
    await EffWordlist.load();
  });

  for (final dark in [false, true]) {
    testWidgets('21 generator matches the mockup${dark ? ' (dark)' : ''}', (
      tester,
    ) async {
      final b = await bed(tester);
      phoneInsets(tester);
      await openGenerator(tester, b, dark: dark);
      expect(find.text('Generator'), findsWidgets);
      expect(find.text('VERY STRONG · 98 bits entropy'), findsOneWidget);
      expect(find.text('Hq9!vT2#xLm4'), findsOneWidget);
      expect(find.text('orbit-maple-candle-42'), findsOneWidget);
      expect(find.text('2m ago'), findsOneWidget);
      expect(find.text('1h ago'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      await captureScreen(tester, '21_vault_generator${dark ? '_dark' : ''}');
      await _tearDown(tester, b);
    });
  }

  testWidgets('21 copy clears later and lands in the encrypted history', (
    tester,
  ) async {
    final b = await bed(tester, history: false);
    await openGenerator(tester, b);
    final value = b.h.read(generatorControllerProvider).value!.value;
    await tester.tap(find.bySemanticsLabel('Copy'));
    await settle(tester, rounds: 3);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester, rounds: 2);
    expect(b.clipboard.last, value);
    expect(find.text('Password copied · clears in 30s'), findsOneWidget);
    final rows = (await tester.runAsync(
      () => b.h.read(vaultRepositoryProvider).watchGeneratorHistory().first,
    ))!;
    expect(rows, hasLength(1));
    // Stored sealed: the plaintext never reaches the database.
    expect(latin1.decode(rows.single.encryptedValue).contains(value), isFalse);
    await _tearDown(tester, b);
  });

  testWidgets('21 PIN and passphrase modes regenerate', (tester) async {
    final b = await bed(tester, history: false);
    await openGenerator(tester, b);
    await tester.tap(find.bySemanticsLabel('PIN'));
    await settle(tester);
    final pin = b.h.read(generatorControllerProvider).value!;
    expect(pin.mode, GeneratorMode.pin);
    expect(RegExp(r'^\d{6}$').hasMatch(pin.value), isTrue);
    expect(find.text('Digits'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Passphrase'));
    await tester.runAsync(() => b.h.read(effWordlistProvider.future));
    await settle(tester);
    final phrase = b.h.read(generatorControllerProvider).value!;
    expect(phrase.mode, GeneratorMode.passphrase);
    expect(phrase.value.split('-'), hasLength(4));
    expect(find.text('Words'), findsOneWidget);
    await _tearDown(tester, b);
  });

  testWidgets('21 save opens the editor with the password filled in', (
    tester,
  ) async {
    final b = await bed(tester, history: false);
    await openGenerator(tester, b);
    final value = b.h.read(generatorControllerProvider).value!.value;
    final save = find.bySemanticsLabel('Save to new vault item');
    await tester.ensureVisible(save);
    await settle(tester);
    await tester.tap(save);
    // Sealing + the history insert run on real async I/O.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await settle(tester, rounds: 2);
    }
    expect(find.text(value), findsOneWidget);
    final location = b.h.read(routerProvider).state.uri.toString();
    expect(location, '/vault/new?type=login');
    expect(location.contains(value), isFalse);
    expect(find.text(value), findsOneWidget);
    expect(b.h.read(vaultEditorPrefillProvider), isNull);
    await _tearDown(tester, b);
  });

  testWidgets('21 no overflow at 360 pt and text scale 1.3', (tester) async {
    final b = await bed(tester);
    await openGenerator(tester, b, size: small, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await _tearDown(tester, b);
  });

  test('length slider: 16 near the middle, every length reachable', () {
    final slider = VaultLengthSlider(
      label: 'Length',
      value: 16,
      min: PasswordOptions.minLength,
      max: PasswordOptions.maxLength,
      stops: const [(16, 0.45), (32, 0.8)],
      onChanged: (_) {},
    );
    expect(slider.positionOf(8), 0);
    expect(slider.positionOf(16), closeTo(0.45, 1e-9));
    expect(slider.positionOf(64), 1);
    for (var v = 8; v <= 64; v++) {
      expect(slider.valueAt(slider.positionOf(v)), v);
    }
  });

  test('strength buckets follow the entropy', () {
    expect(GeneratorStrength.of(20), GeneratorStrength.weak);
    expect(GeneratorStrength.of(52), GeneratorStrength.fair);
    expect(GeneratorStrength.of(70), GeneratorStrength.strong);
    expect(GeneratorStrength.of(98), GeneratorStrength.veryStrong);
    // 16 chars over 89 symbols ≈ 103.6 bits.
    expect(
      PasswordGenerator.passwordEntropy(const PasswordOptions(length: 16)),
      closeTo(103.6, 0.1),
    );
  });
}
