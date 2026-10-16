/// Screen 22 (vault Security tab): captures against the mockup, the report
/// maths (tiles, issues, score weights), the all-good state, breach
/// monitoring sending only hash prefixes, and small-screen / large-text
/// overflow.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/core/crypto/breach_check.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/services/vault_security_report.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_security_providers.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_tab_bar.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/screen_harness.dart';
import '../vault_test_helpers.dart';
import 'vault_detail_test.dart' show loadMonoFont;

/// Records every requested URL; answers with no matches.
class _FakeRange {
  final urls = <Uri>[];

  late final client = MockClient((req) async {
    urls.add(req.url);
    return http.Response('', 200);
  });

  List<String> get prefixes => [for (final u in urls) u.pathSegments.last];
}

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
  const tall = Size(390, 1114);
  const small = Size(360, 800);

  /// The mockup: 24 logins, LinkedIn breached, Netflix + 2 reused, Figma
  /// weak, Dutch-Bangla Bank 410 days old, 14 with 2FA.
  Future<VaultTestBed> bed(
    WidgetTester tester, {
    bool issues = true,
    _FakeRange? range,
  }) async {
    final b = (await tester.runAsync(
      () => VaultTestBed.create(
        now,
        overrides: [
          if (range != null)
            breachCheckerProvider.overrideWithValue(
              BreachChecker(client: range.client),
            ),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(b.h.dispose));
    await tester.runAsync(() async {
      await b.setUpVault();
      var totp = 14, count = 0;
      Future<void> add(
        String t, {
        String? pw,
        int? strength,
        int? breaches,
        DateTime? changed,
      }) {
        count++;
        return b.add(
          t,
          password: pw ?? 'Strong-$t-pass-2026!',
          strength: strength,
          breaches: breaches,
          passwordUpdatedAt: changed,
          hasTotp: totp-- > 0,
        );
      }

      if (issues) {
        await add('LinkedIn', pw: 'linked-pass-77', strength: 3, breaches: 3);
        for (final t in ['Netflix', 'Prime Video', 'Spotify']) {
          await add(t, pw: 'shared-family-pw', strength: 3);
        }
        await add('Figma', pw: 'figma123', strength: 1);
        await add(
          'Dutch-Bangla Bank',
          changed: now.subtract(const Duration(days: 410)),
        );
      }
      for (var i = count; i < 24; i = count) {
        await add('Site ${String.fromCharCode(65 + i)}');
      }
      final store = b.h.read(vaultSecurityStoreProvider);
      await store.setLastScanAt(DateTime(2026, 6, 13, 8, 2));
      final report = await b.h.read(securityReportProvider.future);
      await store.recordScore(
        now.subtract(const Duration(days: 8)),
        report.score - 6,
      );
    });
    return b;
  }

  Future<void> open(
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
    b.h.container.read(vaultTabProvider.notifier).select(VaultTab.security);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester, rounds: 3);
  }

  setUpAll(() async {
    await loadAppFonts();
    await loadMonoFont();
  });

  for (final dark in [false, true]) {
    testWidgets('22 security matches the mockup${dark ? ' (dark)' : ''}', (
      tester,
    ) async {
      final b = await bed(tester);
      tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
      addTearDown(tester.view.resetPadding);
      await tester.runAsync(
        () => b.h
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(breachMonitoring: true)),
      );
      await open(tester, b, dark: dark);
      expect(find.text('Last scan: today, 8:02 AM'), findsOneWidget);
      expect(find.text('+6 since last week'), findsOneWidget);
      expect(find.text('NEEDS ATTENTION · 4'), findsOneWidget);
      expect(find.text('Netflix + 2 more'), findsOneWidget);
      expect(find.text('Same password on 3 sites'), findsOneWidget);
      expect(find.text('Only 8 characters, no symbols'), findsOneWidget);
      expect(find.text('Not changed in 410 days'), findsOneWidget);
      expect(find.text('14 / 24'), findsOneWidget);
      await captureScreen(tester, '22_vault_security${dark ? '_dark' : ''}');
      await _tearDown(tester, b);
    });
  }

  testWidgets('22 all-good state', (tester) async {
    final b = await bed(tester, issues: false);
    await open(tester, b);
    expect(find.text('Your vault is in great shape'), findsOneWidget);
    expect(find.textContaining('NEEDS ATTENTION'), findsNothing);
    await _tearDown(tester, b);
  });

  testWidgets('22 breach monitoring sends only 5-char SHA-1 prefixes', (
    tester,
  ) async {
    final range = _FakeRange();
    final b = await bed(tester, range: range);
    await open(tester, b);
    await tester.scrollUntilVisible(
      find.text('Breach monitoring'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.byType(FFSwitch).first);
    await settle(tester);
    // Re-auth first (as in Settings): nothing changes until the PIN.
    expect(find.text("Confirm it's you"), findsOneWidget);
    expect(b.h.read(settingsProvider).breachMonitoring, isFalse);
    for (final d in '123456'.split('')) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settle(tester, rounds: 2);
    }
    expect(b.h.read(settingsProvider).breachMonitoring, isTrue);
    expect(range.prefixes, isNotEmpty);
    for (final p in range.prefixes) {
      expect(p, matches(RegExp(r'^[0-9A-F]{5}$')));
    }
    expect(range.prefixes, contains(BreachChecker.prefixOf('linked-pass-77')));
    expect(
      range.prefixes.toSet(),
      hasLength(range.prefixes.length),
      reason: 'reused passwords are checked once per scan',
    );
    for (final u in range.urls) {
      expect(u.toString(), startsWith(BreachChecker.endpoint));
      expect(u.hasQuery, isFalse);
    }
    await _tearDown(tester, b);
  });

  testWidgets('22 no overflow at 360 pt and text scale 1.3', (tester) async {
    final b = await bed(tester);
    await open(tester, b, size: small, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await _tearDown(tester, b);
  });

  test('score weights strength 40 / unique 25 / breach 25 / age 10', () {
    VaultItemRecord rec(String id, {int s = 4, String fp = '', int? br}) =>
        VaultItemRecord(
          id: id,
          type: VaultItemType.login,
          title: id,
          encryptedPayload: Uint8List(0),
          passwordStrength: s,
          passwordFingerprint: fp.isEmpty ? id : fp,
          breachCount: br,
          passwordUpdatedAt: now,
          createdAt: now,
          updatedAt: now,
        );
    expect(VaultSecurityReport.compute([rec('a')], now).score, 100);
    // Breached: loses 25.
    expect(VaultSecurityReport.compute([rec('a', br: 2)], now).score, 75);
    // Strength 2 of 4: loses 20.
    expect(VaultSecurityReport.compute([rec('a', s: 2)], now).score, 80);
    final reused = VaultSecurityReport.compute([
      rec('a', fp: 'x'),
      rec('b', fp: 'x'),
    ], now);
    expect(reused.score, 75);
    expect(reused.reused, 2);
    expect(reused.issues.single.title, 'a + 1 more');
  });
}
