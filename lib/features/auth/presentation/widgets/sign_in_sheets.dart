/// ============================================================
/// SIGN IN SHEETS — "What should we call you?" and "Backup found"
/// ============================================================
///
/// * [showOfflineNameSheet] — optional display name for the offline
///   profile. Returns the typed name ('' = skipped) or null when the sheet
///   is dismissed (the user changed their mind; stay on Sign in).
/// * [showBackupFoundSheet] — after Google sign-in finds a Drive backup:
///   Restore (→ restore picker) or Start fresh (its backups are not merged
///   automatically). Returns true for Restore, false for Start fresh, null
///   when dismissed (undecided: merging stays on hold).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/sync/drive_backup_file.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:intl/intl.dart';

/// Asks for an optional name before starting offline.
Future<String?> showOfflineNameSheet(BuildContext context) =>
    showFFBottomSheet<String>(context, builder: (_) => const _NameSheet());

class _NameSheet extends StatefulWidget {
  const _NameSheet();

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done([String? value]) =>
      Navigator.of(context).pop((value ?? _controller.text).trim());

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('What should we call you?'), style: text.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tr(
            'Optional — your name stays on this device. You can connect Google Drive later in Settings › Backup.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 40,
          onSubmitted: (v) => _done(v),
          decoration: InputDecoration(
            hintText: tr('Your name'),
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FFPrimaryButton(label: tr('Continue'), onPressed: _done),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: FFTextButton(label: tr('Skip'), onPressed: () => _done('')),
        ),
      ],
    );
  }
}

/// "Backup found" — true = Restore, false = Start fresh, null = dismissed.
Future<bool?> showBackupFoundSheet(
  BuildContext context,
  DriveBackupFile backup,
) =>
    showFFBottomSheet<bool>(context, builder: (_) => _BackupFoundSheet(backup));

class _BackupFoundSheet extends StatelessWidget {
  const _BackupFoundSheet(this.backup);

  final DriveBackupFile backup;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final local = backup.createdAt.toLocal();
    final when = DateFormats.of('d MMM y · h:mm a').format(local);
    final items = NumberFormat.decimalPattern().format(backup.itemCount);
    final count = tr('{count, plural, one {# item} other {{items} items}}', {
      'count': backup.itemCount,
      'items': items,
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FFIconTile.soft(
            icon: FontAwesomeIcons.cloudArrowDown,
            colors: ModuleStyle.notes.colors,
            size: AppSizes.iconTileLg,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(tr('Backup found'), style: text.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          backup.deviceName.isEmpty
              ? tr(
                  'Your Google Drive has a backup — {when}, {v}. Restore it to pick up where you left off, or start fresh — the backup stays in Drive and isn\'t merged unless you restore it.',
                  {'when': when, 'v': count},
                )
              : tr(
                  'Your Google Drive has a backup from {device} — {when}, {v}. Restore it to pick up where you left off, or start fresh — the backup stays in Drive and isn\'t merged unless you restore it.',
                  {'device': backup.deviceName, 'when': when, 'v': count},
                ),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Restore'),
          icon: FontAwesomeIcons.clockRotateLeft,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSecondaryButton(
          label: tr('Start fresh'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
