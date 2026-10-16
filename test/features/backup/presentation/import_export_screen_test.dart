/// Screen 35 — Import & Export: mockup captures (light / dark), the
/// live INCLUDE counts / "Export N items", a JSON export through a fake
/// share sheet, a Todoist CSV import end to end (preview → import →
/// summary, dedupe on the second run), and no overflow at 360 pt / 1.3.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/backup/data/export_service.dart';
import 'package:focusflow/features/backup/data/import_file_source.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/screens/import_export_screen.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../backup_test_support.dart';

class _FakeFiles implements ImportFileSource {
  PickedImportFile? next;
  int discarded = 0;

  @override
  Future<PickedImportFile?> pick() async {
    final n = next;
    if (n == null) return null;
    return PickedImportFile(
      name: n.name,
      bytes: n.bytes,
      onDiscard: () async => discarded++,
    );
  }
}

const _counts = ExportCounts(
  active: {
    ExportModule.notes: 48,
    ExportModule.tasks: 23,
    ExportModule.reminders: 12,
    ExportModule.habits: 6,
    ExportModule.vault: 24,
  },
);

const _todoist =
    'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE,'
    'DATE_LANG,TIMEZONE\n'
    'task,Buy milk @errands,,1,1,,,2026-06-14,en,UTC\n'
    'task,Oat milk,,4,2,,,,en,UTC\n'
    'task,Call mom,,4,1,,,every sunday,en,UTC\n';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('matches the mockup (light + dark captures)', (tester) async {
    final (h, _) = await backupHarness(
      tester,
      overrides: [
        exportCountsProvider.overrideWith((ref) => Stream.value(_counts)),
      ],
    );
    await pumpApp(tester, h, AppRoutes.settingsImportExport);
    expect(find.byType(ImportExportScreen), findsOneWidget);
    expect(find.text('.ffbackup'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    // Vault is unchecked by default: 48 + 23 + 12 + 6.
    expect(find.text('Export 89 items'), findsOneWidget);
    await captureScreen(tester, '35_import_export');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    expect(find.text('Evernote (.enex)'), findsOneWidget);
    await captureScreen(tester, '35_import_export_bottom');

    await pumpApp(tester, h, AppRoutes.settingsImportExport, dark: true);
    await captureScreen(tester, '35_import_export_dark');
  });

  testWidgets('vault only with .ffbackup; JSON export goes to share', (
    tester,
  ) async {
    ExportFile? shared;
    final (h, fakes) = await backupHarness(
      tester,
      overrides: [
        exportServiceProvider.overrideWith(
          (ref) => ExportService(
            engine: ref.watch(backupEngineProvider),
            keys: ref.watch(backupKeyStoreProvider),
            drive: ref.watch(driveSyncProvider),
            local: ref.watch(localBackupsProvider),
            clock: ref.watch(clockProvider),
            share: (f) async {
              shared = f;
              return true;
            },
          ),
        ),
      ],
    );
    await tester.runAsync(() async {
      final notes = h.read(notesRepositoryProvider);
      await notes.createEmpty(title: 'Groceries', initialText: 'Milk');
      await notes.createEmpty(title: 'Ideas', initialText: 'Ship it');
    });
    await pumpApp(tester, h, AppRoutes.settingsImportExport);
    expect(find.text('Export 2 items'), findsOneWidget);
    await tester.tap(find.text('Vault'));
    await settle(tester);
    expect(find.text('Export 2 items'), findsOneWidget); // no vault items
    await tester.tap(find.text('JSON'));
    await settle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await settle(tester);
    await tester.tap(find.text('Share…'));
    await settle(tester);
    await tester.tap(find.text('Export 2 items'));
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(shared, isNotNull);
    final json = jsonDecode(utf8.decode(shared!.bytes)) as Map;
    expect(json['format'], 'focusflow-export');
    expect((json['notes'] as List).map((n) => (n as Map)['title']), {
      'Groceries',
      'Ideas',
    });
    expect(json.containsKey('vault'), isFalse);
    expect(fakes.drive.backupNames, isEmpty);
  });

  testWidgets('Todoist CSV import: preview, import, dedupe', (tester) async {
    final files = _FakeFiles()
      ..next = PickedImportFile(
        name: 'Groceries.csv',
        bytes: Uint8List.fromList(utf8.encode(_todoist)),
      );
    final (h, _) = await backupHarness(
      tester,
      overrides: [importFileSourceProvider.overrideWithValue(files)],
    );
    await pumpApp(tester, h, AppRoutes.settingsImportExport);
    await tester.tap(find.text('Import'));
    await settle(tester);
    await tester.tap(find.text('Choose file…'));
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').toLowerCase().contains('todoist'),
      ),
      findsWidgets,
    );
    expect(find.text('Import 2 items'), findsOneWidget);
    expect(files.discarded, 1);
    await captureScreen(tester, '35_import_preview');
    await tester.tap(find.text('Import 2 items'));
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(find.text('Import complete'), findsOneWidget);
    final tasks = await tester.runAsync(
      () =>
          h.read(tasksRepositoryProvider).watchTasks(const TasksQuery()).first,
    );
    expect(tasks!.map((t) => t.title).toSet(), {'Buy milk', 'Call mom'});
    final milk = tasks.firstWhere((t) => t.title == 'Buy milk');
    expect(milk.subtasks.single.title, 'Oat milk');
    expect(milk.tags.single.name, 'errands');

    // Same file again: everything is a duplicate.
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.tap(find.text('Choose file…'));
    await settle(tester);
    await tester.tap(find.text('Import 2 items'));
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(find.text('0 imported · 2 duplicates skipped'), findsOneWidget);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    final (h, _) = await backupHarness(
      tester,
      overrides: [
        exportCountsProvider.overrideWith((ref) => Stream.value(_counts)),
      ],
    );
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsImportExport,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
