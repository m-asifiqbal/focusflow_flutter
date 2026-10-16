/// ============================================================
/// EXPORT TAB — Import & Export › Export (screen 35)
/// ============================================================
///
/// What: FORMAT tiles, INCLUDE checklist with live counts (Vault only for
/// .ffbackup and unchecked by default), Include archived / attachments,
/// the amber vault warning, SAVE TO tiles, "Export N items", and the
/// IMPORT FROM OTHER APPS pills (they open the Import tab's picker).
/// Why: state lives in [exportControllerProvider]; counts are a live
/// query, so the button label follows edits made anywhere.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/notifiers/import_export_controllers.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/widgets/drive_logo.dart';
import 'package:focusflow/features/backup/presentation/widgets/export_tiles.dart';

/// The IMPORT FROM OTHER APPS pills.
const List<String> kImportApps = [
  'Google Keep',
  'Todoist',
  'Bitwarden CSV',
  '1Password',
  'Loop Habit',
  'Evernote (.enex)',
];

class ExportTab extends ConsumerWidget {
  const ExportTab({required this.onImportApp, super.key});

  /// A pill was tapped (switch to Import and pick a file).
  final ValueChanged<String> onImportApp;

  static const _formatIcons = {
    ExportFormat.ffbackup: FontAwesomeIcons.fileZipper,
    ExportFormat.json: FontAwesomeIcons.fileCode,
    ExportFormat.csv: FontAwesomeIcons.fileCsv,
    ExportFormat.pdfMd: FontAwesomeIcons.fileLines,
  };

  static ModuleStyle _style(ExportModule m) => switch (m) {
    ExportModule.notes => ModuleStyle.notes,
    ExportModule.tasks => ModuleStyle.tasks,
    ExportModule.reminders => ModuleStyle.reminders,
    ExportModule.habits => ModuleStyle.habits,
    ExportModule.vault => ModuleStyle.vault,
  };

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final msg = await ref.read(exportControllerProvider.notifier).export();
    if (msg != null && context.mounted) showFFToast(context, msg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportControllerProvider);
    final c = ref.read(exportControllerProvider.notifier);
    final o = state.options;
    final counts = ref.watch(exportCountsProvider);
    final account = ref.watch(cloudAccountProvider);
    final drive = account != null && account.hasDrive;
    final total = counts.valueOrNull?.total(o) ?? 0;
    // A .ffbackup is sealed only when a backup PIN exists: say so.
    final sealed = ref.watch(backupKeyExistsProvider).valueOrNull;
    String? subtitleOf(ExportFormat f) => f != ExportFormat.ffbackup
        ? f.subtitle
        : switch (sealed) {
            true => f.subtitle,
            false => 'Full · not encrypted',
            null => 'Full backup',
          };
    const gap = SizedBox(height: AppSpacing.section);
    const tileGap = SizedBox(width: AppSpacing.sm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FFSectionLabel('Format'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in ExportFormat.values) ...[
                if (f != ExportFormat.ffbackup) tileGap,
                Expanded(
                  child: ExportChoiceTile(
                    label: f.label,
                    subtitle: subtitleOf(f),
                    icon: _formatIcons[f],
                    selected: o.format == f,
                    onTap: () => c.setFormat(f),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap,
        const FFSectionLabel('Include'),
        if (counts.hasError)
          FFErrorBanner(
            message: "Couldn't count your items",
            onRetry: () => ref.invalidate(exportCountsProvider),
          )
        else
          FFGroupedList(
            children: [
              for (final m in ExportModule.values)
                _IncludeRow(
                  module: m,
                  style: _style(m),
                  count: counts.valueOrNull?.of(
                    m,
                    includeArchived: o.includeArchived,
                  ),
                  checked: o.effectiveModules.contains(m),
                  enabled: o.format.allows(m),
                  onTap: () => c.toggleModule(m),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.cardGap),
        FFGroupedList(
          children: [
            FFListRow.toggle(
              leading: FFIconTile(
                icon: FontAwesomeIcons.boxArchive,
                colors: BackupTints.archived,
                size: AppSizes.iconTileSm,
              ),
              title: 'Include archived items',
              value: o.includeArchived,
              onChanged: c.setArchived,
            ),
            FFListRow.toggle(
              leading: FFIconTile(
                icon: FontAwesomeIcons.paperclip,
                colors: BackupTints.attachments,
                size: AppSizes.iconTileSm,
              ),
              title: 'Include attachments',
              subtitle: o.format == ExportFormat.ffbackup
                  ? null
                  : 'Only in .ffbackup files',
              value: o.includeAttachments,
              enabled: o.format == ExportFormat.ffbackup,
              onChanged: c.setAttachments,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FFInfoBanner(
          icon: FontAwesomeIcons.triangleExclamation,
          colors: ModuleStyle.vault.colors,
          text:
              'Vault items are only exported inside an encrypted '
              '.ffbackup file — never as plain CSV.',
        ),
        gap,
        const FFSectionLabel('Save to'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ExportChoiceTile(
                  label: 'Google Drive',
                  iconWidget: const DriveLogo(size: 24),
                  style: ExportTileStyle.ring,
                  enabled: drive && o.format == ExportFormat.ffbackup,
                  selected: o.target == ExportTarget.drive,
                  onTap: () => c.setTarget(ExportTarget.drive),
                ),
              ),
              tileGap,
              Expanded(
                child: ExportChoiceTile(
                  label: 'This device',
                  icon: FontAwesomeIcons.mobileScreenButton,
                  iconColor: context.ff.primary,
                  style: ExportTileStyle.ring,
                  selected: o.target == ExportTarget.device,
                  onTap: () => c.setTarget(ExportTarget.device),
                ),
              ),
              tileGap,
              Expanded(
                child: ExportChoiceTile(
                  label: 'Share…',
                  icon: FontAwesomeIcons.arrowUpFromBracket,
                  iconColor: BackupTints.drive.solid,
                  style: ExportTileStyle.ring,
                  selected: o.target == ExportTarget.share,
                  onTap: () => c.setTarget(ExportTarget.share),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FFPrimaryButton(
          label: 'Export $total ${total == 1 ? 'item' : 'items'}',
          icon: FontAwesomeIcons.fileExport,
          loading: state.busy,
          onPressed:
              total == 0 ||
                  (o.target == ExportTarget.drive &&
                      (!drive || o.format != ExportFormat.ffbackup))
              ? null
              : () => _export(context, ref),
        ),
        gap,
        const FFSectionLabel('Import from other apps'),
        Wrap(
          spacing: AppSpacing.sm + 2,
          runSpacing: AppSpacing.sm + 2,
          children: [
            for (final app in kImportApps)
              _AppPill(label: app, onTap: () => onImportApp(app)),
          ],
        ),
      ],
    );
  }
}

class _IncludeRow extends StatelessWidget {
  const _IncludeRow({
    required this.module,
    required this.style,
    required this.count,
    required this.checked,
    required this.enabled,
    required this.onTap,
  });

  final ExportModule module;
  final ModuleStyle style;
  final int? count;
  final bool checked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Semantics(
      checked: checked,
      enabled: enabled,
      label: '${module.label}, ${count ?? 0} items',
      excludeSemantics: true,
      child: FFListRow(
        leading: FFIconTile(
          icon: style.icon,
          colors: style.colors,
          size: AppSizes.iconTileSm,
        ),
        title: module.label,
        enabled: enabled,
        chevron: false,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count == null ? '–' : '$count',
              style: text.body.copyWith(color: context.ff.inkFaint),
            ),
            const SizedBox(width: AppSpacing.lg + 2),
            ExportCheckbox(checked: checked, enabled: enabled),
          ],
        ),
      ),
    );
  }
}

class _AppPill extends StatelessWidget {
  const _AppPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: 'Import from $label',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md + 1,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: ff.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: ff.chipBorder, width: AppSizes.hairline),
          ),
          // In a Row so the label is centred in the chip's 44 pt minimum
          // height on every font (a bare Text hugs the top).
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: context.text.rowTitle.copyWith(
                    fontSize: 13.5,
                    color: ff.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
