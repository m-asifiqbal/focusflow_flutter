/// The restore flow's safety rails: a progress dialog closes exactly itself
/// (also when something was pushed above it — a blind pop used to close
/// that instead and leave "Restoring…" up for good), and only one restore
/// runs at a time (a second tap while a backup downloads is ignored).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';

void main() {
  Future<(BuildContext, WidgetRef)> host(WidgetTester tester) async {
    late BuildContext ctx;
    late WidgetRef r;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(AccentColor.values.first),
          home: Consumer(
            builder: (context, ref, _) {
              ctx = context;
              r = ref;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );
    return (ctx, r);
  }

  testWidgets('a progress dialog closes itself, not what is above it', (
    tester,
  ) async {
    final (context, _) = await host(tester);
    final progress = showFFProgressDialog(context, 'Restoring…');
    await tester.pump(const Duration(milliseconds: 400));
    unawaited(
      showFFDialog<void>(
        context,
        builder: (_) => const FFDialog(title: 'On top'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    progress.close();
    progress.close(); // twice is fine
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Restoring…'), findsNothing);
    expect(find.text('On top'), findsOneWidget);
  });

  testWidgets('only one restore runs at a time', (tester) async {
    final (context, ref) = await host(tester);
    final download = Completer<BackupArchive?>();
    var opens = 0;
    Future<BackupArchive?> open() {
      opens++;
      return download.future;
    }

    final first = restoreFromSource(context, ref, open);
    await tester.pump();
    expect(find.text('Downloading the backup…'), findsOneWidget);
    // A second tap while the backup downloads does nothing.
    await restoreFromSource(context, ref, open);
    expect(opens, 1);

    download.complete(null); // cancelled / nothing to restore
    await first;
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Downloading the backup…'), findsNothing);

    // Free again afterwards.
    await restoreFromSource(context, ref, () async {
      opens++;
      return null;
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(opens, 2);
  });
}
