/// ============================================================
/// DRIVE CARD — top card of Backup & Sync (screen 34)
/// ============================================================
///
/// What: connected — Drive tile, "Google Drive", account email, CONNECTED
/// badge, the status box (backed up / syncing with progress / error /
/// "3 items updated from another device"), app-folder usage and the
/// Sync now + Restore buttons. (Not connected: connect_drive_card.dart.)
/// Why: everything reads [syncStatusProvider] / [driveUsageProvider], so a
/// background sync or one started elsewhere shows here live.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/widgets/google_logo.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/widgets/drive_logo.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:go_router/go_router.dart';

class DriveCard extends ConsumerWidget {
  const DriveCard({required this.account, super.key});

  final CloudAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final text = context.text;
    final status = ref.watch(syncStatusProvider);
    final usage = ref.watch(driveUsageProvider).valueOrNull;
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.iconTileLg - 4,
                height: AppSizes.iconTileLg - 4,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BackupTints.drive.soft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadii.tileLg),
                ),
                child: const DriveLogo(size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive',
                      style: text.cardTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        const GoogleLogo(size: 13),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            account.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall.copyWith(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FFTag('Connected', colors: ModuleStyle.notes.colors),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _StatusBox(status: status),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'App folder usage',
                  style: text.meta.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              if (usage != null)
                Text(
                  usage.limitBytes == null
                      ? BackupLabels.size(usage.usedBytes)
                      : '${BackupLabels.size(usage.usedBytes)} of '
                            '${BackupLabels.size(usage.limitBytes!)}',
                  style: text.meta.copyWith(fontWeight: FontWeight.w400),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: ff.divider)),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: usage == null
                          ? 0
                          : usage.fraction.clamp(0.06, 1).toDouble(),
                      child: ColoredBox(color: BackupTints.drive.solid),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Sync now',
                  icon: FontAwesomeIcons.arrowsRotate,
                  primary: true,
                  busy: status.isBusy,
                  onPressed: status.isBusy
                      ? null
                      : () => ref.read(syncStatusProvider.notifier).syncNow(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _CardButton(
                  label: 'Restore',
                  icon: FontAwesomeIcons.clockRotateLeft,
                  onPressed: status.isBusy
                      ? null
                      : () => context.push(AppRoutes.settingsBackupRestore),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The two half-width card buttons (Sync now / Restore). The shared
/// FFPrimaryButton's 17 pt label and 20 pt padding don't fit half a card
/// at 390 pt, so these use the 16 pt button style, tighter padding and
/// scale the label down instead of cutting it.
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final fg = primary ? ff.onPrimary : ff.primary;
    final style = context.text.button.copyWith(color: fg);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null && !busy ? 0.45 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: primary ? ff.primaryGradient : null,
              color: primary ? null : ff.primarySoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadii.button),
              boxShadow: primary && onPressed != null ? ff.heroShadow : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    )
                  else
                    Icon(icon, size: 16, color: fg),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Text(label, maxLines: 1, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBox extends ConsumerWidget {
  const _StatusBox({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final text = context.text;
    final now = ref.watch(clockProvider).now();
    final items = ref.watch(backupItemCountProvider).valueOrNull;
    final error = status.phase == SyncPhase.error;
    final last = status.lastSyncAt;

    final String title;
    final String subtitle;
    switch (status.phase) {
      case SyncPhase.preparing:
        title = 'Preparing…';
        subtitle = 'Building an encrypted backup';
      case SyncPhase.uploading:
        final pct = ((status.progress ?? 0) * 100).round();
        title = 'Uploading $pct%…';
        subtitle = 'Sending to your Drive app folder';
      case SyncPhase.downloading:
        title = 'Checking other devices…';
        subtitle = 'Downloading newer backups';
      case SyncPhase.merging:
        title = 'Merging changes…';
        subtitle = 'Newest edit of each item wins';
      case SyncPhase.error:
        title = switch (status.failure) {
          DriveFailureKind.offline => "You're offline",
          DriveFailureKind.authExpired ||
          DriveFailureKind.notSignedIn => 'Sign in again to sync',
          DriveFailureKind.quota => 'Google Drive is full',
          _ => 'Sync failed',
        };
        subtitle = status.message ?? 'Tap Sync now to try again';
      case SyncPhase.done || SyncPhase.idle:
        title = last == null ? 'Not backed up yet' : 'Everything is backed up';
        final conflicts = status.conflictsResolved;
        subtitle = [
          if (status.phase == SyncPhase.done && conflicts > 0)
            '$conflicts ${conflicts == 1 ? 'item' : 'items'} updated from '
                'another device',
          if (last != null) 'Last sync ${BackupLabels.ago(last, now)}',
          if (last == null) 'Tap Sync now to back up',
          if (items != null &&
              !(status.phase == SyncPhase.done && conflicts > 0))
            '$items items',
        ].join(' · ');
    }
    final busy = status.isBusy;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tint = error ? ff.danger : ff.primary;
    final reauth =
        error &&
        (status.failure == DriveFailureKind.authExpired ||
            status.failure == DriveFailureKind.notSignedIn);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: error ? ff.dangerSoft : ff.primarySoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadii.row),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: AppSizes.iconTile,
                  child: busy
                      ? CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: tint,
                          backgroundColor: tint.withValues(alpha: 0.15),
                          value: reduce
                              ? (status.progress ?? 0.1)
                              : status.progress,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: tint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            error
                                ? FontAwesomeIcons.exclamation
                                : last == null
                                ? FontAwesomeIcons.cloudArrowUp
                                : FontAwesomeIcons.check,
                            size: 15,
                            color: ff.onPrimary,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.rowTitle.copyWith(
                          color: error ? ff.danger : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: text.meta.copyWith(
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reauth) ...[
              const SizedBox(height: AppSpacing.md),
              FFSecondaryButton(
                label: 'Sign in again',
                icon: FontAwesomeIcons.google,
                height: 44,
                variant: FFSecondaryVariant.outlined,
                onPressed: () => context.push(AppRoutes.signIn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
