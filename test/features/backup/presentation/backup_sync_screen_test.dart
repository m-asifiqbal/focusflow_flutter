/// Screen 34 — Backup & Sync: mockup captures (light / dark), the
/// not-connected / syncing / error states, a real Sync now against the
/// fake Drive, back up to device, and no overflow at 360 pt / 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/presentation/screens/backup_sync_screen.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../backup_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> lastSync(dynamic h) => h
      .read(sharedPreferencesProvider)
      .setString(
        SyncController.lastSyncKey,
        backupNow
            .subtract(const Duration(minutes: 2))
            .toUtc()
            .toIso8601String(),
      );

  testWidgets('matches the mockup (light + dark captures)', (tester) async {
    final (h, _) = await backupHarness(tester);
    await tester.runAsync(() async {
      await seedHistory(h);
      await lastSync(h);
    });
    await pumpApp(tester, h, AppRoutes.settingsBackup);
    expect(find.byType(BackupSyncScreen), findsOneWidget);
    expect(find.text('asif.design@gmail.com'), findsOneWidget);
    expect(find.text('Everything is backed up'), findsOneWidget);
    expect(find.text('Last sync 2 min ago · 113 items'), findsOneWidget);
    expect(find.text('2.4 MB of 15 GB'), findsOneWidget);
    expect(find.text('Daily · 9:00 PM'), findsOneWidget);
    await captureScreen(tester, '34_backup_sync');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    expect(find.text('Today, 9:39 AM'), findsOneWidget);
    expect(find.text('Google Drive · 2.4 MB · auto'), findsOneWidget);
    expect(find.text('Local · /FocusFlow · 2.3 MB'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Disconnect Google account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Disconnect Google account'), findsOneWidget);
    await captureScreen(tester, '34_backup_sync_bottom');

    await pumpApp(tester, h, AppRoutes.settingsBackup, dark: true);
    await captureScreen(tester, '34_backup_sync_dark');
  });

  testWidgets('not connected shows Connect Google Drive', (tester) async {
    final (h, _) = await backupHarness(tester, account: null);
    await pumpApp(tester, h, AppRoutes.settingsBackup);
    expect(find.text('Connect Google Drive'), findsWidgets);
    expect(find.text('Auto backup to Drive'), findsNothing);
    expect(find.text('Encrypt backups'), findsOneWidget);
    expect(find.text('Disconnect Google account'), findsNothing);
    await captureScreen(tester, '34_backup_not_connected');
  });

  testWidgets('Sync now uploads to Drive and records history', (tester) async {
    final (h, fakes) = await backupHarness(tester);
    await pumpApp(tester, h, AppRoutes.settingsBackup);
    expect(find.text('Not backed up yet'), findsOneWidget);
    await tester.tap(find.text('Sync now'));
    for (var i = 0; i < 6; i++) {
      await settle(tester);
    }
    expect(fakes.drive.backupNames, hasLength(1));
    expect(h.read(syncStatusProvider).phase, SyncPhase.done);
    expect(find.text('Everything is backed up'), findsOneWidget);
    final records = await tester.runAsync(
      () => h.read(backupRecordsRepositoryProvider).watchAll().first,
    );
    expect(records!.single.location, BackupLocation.drive);
  });

  testWidgets('offline error state', (tester) async {
    final (h, fakes) = await backupHarness(tester);
    fakes.net.online = false;
    await pumpApp(tester, h, AppRoutes.settingsBackup);
    await tester.tap(find.text('Sync now'));
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    expect(h.read(syncStatusProvider).failure, DriveFailureKind.offline);
    expect(find.text("You're offline"), findsOneWidget);
    await captureScreen(tester, '34_backup_error');
  });

  testWidgets('Back up to device now writes a local backup', (tester) async {
    final (h, _) = await backupHarness(tester);
    await pumpApp(tester, h, AppRoutes.settingsBackup);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await settle(tester);
    await tester.tap(find.text('Back up to device now'));
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    final records = await tester.runAsync(
      () => h.read(backupRecordsRepositoryProvider).watchAll().first,
    );
    expect(records!.single.location, BackupLocation.local);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    final (h, _) = await backupHarness(tester);
    await tester.runAsync(() => seedHistory(h));
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsBackup,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
