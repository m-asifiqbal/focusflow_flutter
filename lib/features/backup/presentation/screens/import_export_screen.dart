/// ============================================================
/// IMPORT & EXPORT SCREEN — Settings › Import & Export (screen 35)
/// ============================================================
///
/// What: "‹ Settings | Import & Export" over the Export / Import segmented
/// control and the selected tab.
/// Why: exports in several formats (vault only inside an encrypted
/// .ffbackup) and imports from other apps, all offline.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/notifiers/import_export_controllers.dart';
import 'package:focusflow/features/backup/presentation/widgets/export_tab.dart';
import 'package:focusflow/features/backup/presentation/widgets/import_tab.dart';

enum ImportExportTab { export, import }

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({
    this.initialTab = ImportExportTab.export,
    super.key,
  });

  final ImportExportTab initialTab;

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  late ImportExportTab _tab = widget.initialTab;

  void _importFrom(String app) {
    setState(() => _tab = ImportExportTab.import);
    ref.read(importControllerProvider.notifier).pick();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the import flow alive while the Export tab is showing.
    ref.watch(importControllerProvider.select((s) => s.phase));
    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: FFBackButton(label: tr('Settings')),
            title: tr('Import & Export'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.sm,
                AppSpacing.grouped,
                AppSpacing.xxl,
              ),
              children: [
                FFSegmented<ImportExportTab>(
                  segments: [
                    FFSegment(
                      value: ImportExportTab.export,
                      label: tr('Export'),
                    ),
                    FFSegment(
                      value: ImportExportTab.import,
                      label: tr('Import'),
                    ),
                  ],
                  value: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
                const SizedBox(height: AppSpacing.section),
                if (_tab == ImportExportTab.export)
                  ExportTab(onImportApp: _importFrom)
                else
                  const ImportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
