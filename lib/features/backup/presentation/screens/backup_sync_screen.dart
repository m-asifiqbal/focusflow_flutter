/// ============================================================
/// BACKUP & SYNC SCREEN — Settings › Backup & Sync (screen 34)
/// ============================================================
///
/// What: "‹ Settings | Backup & Sync" over the Drive card (or "Connect
/// Google Drive"), AUTOMATIC BACKUP, LOCAL BACKUP, HISTORY and
/// "Disconnect Google account". Banners on top while backups are paused
/// for a missing backup PIN, or while other devices' backups wait for the
/// Restore / Start fresh choice.
/// Why: one place for the optional cloud; everything is live (sync status,
/// history, settings) and works without an account (local backups).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_history_section.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_prompts.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_settings_sections.dart';
import 'package:focusflow/features/backup/presentation/widgets/connect_drive_card.dart';
import 'package:focusflow/features/backup/presentation/widgets/drive_card.dart';

class BackupSyncScreen extends ConsumerWidget {
  const BackupSyncScreen({super.key});

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final ok = await showFFConfirm(
      context,
      title: 'Disconnect Google account?',
      message:
          'Backups stay in your Drive and everything stays on this phone. '
          'Sync stops until you connect again.',
      confirmLabel: 'Disconnect',
      destructive: true,
      icon: FontAwesomeIcons.linkSlash,
    );
    if (!ok) return;
    await ref.read(backupActionsProvider).disconnect();
    if (context.mounted) showFFToast(context, 'Google account disconnected');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(cloudAccountProvider);
    final drive = account != null && account.hasDrive;
    const gap = SizedBox(height: AppSpacing.section);
    return FFScaffold(
      body: Column(
        children: [
          const FFNavHeader(
            leading: FFBackButton(label: 'Settings'),
            title: 'Backup & Sync',
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
                const BackupEncryptionBanner(),
                if (drive) const MergeDecisionBanner(),
                if (drive)
                  DriveCard(account: account)
                else
                  const ConnectDriveCard(),
                gap,
                AutomaticBackupSection(connected: drive),
                gap,
                const LocalBackupSection(),
                gap,
                const BackupHistorySection(),
                if (drive) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _DisconnectButton(onTap: () => _disconnect(context, ref)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisconnectButton extends StatelessWidget {
  const _DisconnectButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FFCard(
    onTap: onTap,
    semanticLabel: 'Disconnect Google account',
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg + 2,
    ),
    child: Text(
      'Disconnect Google account',
      textAlign: TextAlign.center,
      style: context.text.button.copyWith(
        color: context.ff.danger,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
