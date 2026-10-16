/// Screen 02 — Sign in: mockup captures (light / dark), offline flow with
/// a name, Google sign-in that finds a Drive backup, silent cancel,
/// restore intent, and no overflow at 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../auth_test_support.dart';

final _now = DateTime(2026, 10, 13, 9, 41);

void main() {
  setUpAll(loadAppFonts);

  late AuthFakes fakes;

  Future<TestHarness> harness(WidgetTester tester) async {
    fakes = AuthFakes();
    final h = (await tester.runAsync(() => authHarness(fakes, now: _now)))!;
    addTearDown(() async {
      await tester.runAsync(h.dispose);
      fakes.dir.deleteSync(recursive: true);
    });
    return h;
  }

  String location(TestHarness h) =>
      h.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  Future<void> open(
    WidgetTester tester,
    TestHarness h, {
    String path = AppRoutes.signIn,
    bool dark = false,
    Size? size,
    double textScale = 1,
  }) => pumpApp(
    tester,
    h,
    path,
    onboardingSeen: false,
    dark: dark,
    textScale: textScale,
    size: size ?? kMockupSize,
  );

  testWidgets('matches the mockup (light + dark captures)', (tester) async {
    final h = await harness(tester);
    await open(tester, h);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Welcome to FocusFlow'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Use offline (local only)'), findsOneWidget);
    await captureScreen(tester, '02_sign_in');

    await open(tester, h, dark: true);
    await captureScreen(tester, '02_sign_in_dark');
  });

  testWidgets('offline: optional name, offline mode, then Home', (
    tester,
  ) async {
    final h = await harness(tester);
    await open(tester, h);
    await tester.tap(find.text('Use offline (local only)'));
    await settle(tester);
    expect(find.text('What should we call you?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Asif ');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    final s = h.read(settingsProvider);
    expect(s.accountMode, AccountMode.offline);
    expect(s.onboardingSeen, isTrue);
    expect(s.displayName, 'Asif');
    expect(location(h), AppRoutes.home);
  });

  testWidgets('Google: a Drive backup shows "Backup found" → Restore', (
    tester,
  ) async {
    final h = await harness(tester);
    await tester.runAsync(
      () => fakes.addDriveBackup(createdAt: DateTime(2026, 10, 12, 21, 5)),
    );
    await open(tester, h);
    await tester.tap(find.text('Continue with Google'));
    await settle(tester);

    expect(find.text('Backup found'), findsOneWidget);
    expect(find.textContaining('113 items'), findsOneWidget);
    expect(h.read(settingsProvider).accountMode, AccountMode.google);
    await captureScreen(tester, '02_sign_in_backup_found');

    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect(location(h), AppRoutes.settingsBackupRestore);
  });

  testWidgets('Google without backups goes Home', (tester) async {
    final h = await harness(tester);
    await open(tester, h);
    await tester.tap(find.text('Continue with Google'));
    await settle(tester);
    expect(find.text('Backup found'), findsNothing);
    expect(location(h), AppRoutes.home);
  });

  testWidgets('cancelling Google is silent and stays put', (tester) async {
    final h = await harness(tester);
    fakes.google.profile = null;
    await open(tester, h);
    await tester.tap(find.text('Continue with Google'));
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(location(h), AppRoutes.signIn);
    expect(h.read(settingsProvider).accountMode, AccountMode.none);
  });

  testWidgets('intent=restore opens the restore picker after Google', (
    tester,
  ) async {
    final h = await harness(tester);
    await tester.runAsync(
      () => fakes.addDriveBackup(createdAt: DateTime(2026, 10, 12)),
    );
    await open(tester, h, path: AppRoutes.signInRestore);
    await tester.tap(find.text('Continue with Google'));
    await settle(tester);
    expect(find.text('Backup found'), findsNothing);
    expect(location(h), AppRoutes.settingsBackupRestore);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    final h = await harness(tester);
    await open(tester, h, size: const Size(360, 800), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
