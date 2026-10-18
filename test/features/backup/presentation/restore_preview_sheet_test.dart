/// The restore preview says when a backup carries the app's settings
/// (a row, and what Merge does with them) and stays as it was for backups
/// that don't — including every backup made before settings were carried.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';

import '../../../core/sync/sync_fixtures.dart';
import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

BackupManifest _manifest({required bool hasSettings}) => BackupManifest(
  schemaVersion: 2,
  appVersion: '1.0.0',
  createdAt: syncNow,
  deviceId: 'other',
  deviceName: 'Pixel 8',
  platform: 'Android',
  counts: const {'notes': 4, 'tasks': 2},
  itemCount: 6,
  checksum: 'x',
  hasSettings: hasSettings,
);

class _Host extends StatelessWidget {
  const _Host({required this.manifest, required this.onResult});

  final BackupManifest manifest;
  final ValueChanged<RestoreMode?> onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async => onResult(
          await showRestorePreviewSheet(context, manifest, now: syncNow),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  Future<void> open(
    WidgetTester tester, {
    required bool hasSettings,
    required ValueChanged<RestoreMode?> onResult,
  }) async {
    final h = (await tester.runAsync(() => TestHarness.create(now: syncNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpScreen(
      tester,
      h,
      _Host(
        manifest: _manifest(hasSettings: hasSettings),
        onResult: onResult,
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('a backup with settings shows the row and the Merge promise', (
    tester,
  ) async {
    RestoreMode? chosen;
    await open(tester, hasSettings: true, onResult: (m) => chosen = m);

    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(find.text('App settings'), findsOneWidget);
    expect(find.text('Included'), findsOneWidget);
    expect(
      find.textContaining('Settings you changed on this phone stay.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Merge with this phone'));
    await settle(tester);
    expect(chosen, RestoreMode.merge);
  });

  testWidgets('a backup without settings looks as it always did', (
    tester,
  ) async {
    await open(tester, hasSettings: false, onResult: (_) {});

    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(find.text('App settings'), findsNothing);
    expect(find.text('Included'), findsNothing);
    expect(
      find.text('Adds what is missing; the newest edit of each item wins.'),
      findsOneWidget,
    );
  });
}
