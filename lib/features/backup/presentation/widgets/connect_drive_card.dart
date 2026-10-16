/// ============================================================
/// CONNECT DRIVE CARD — Backup & Sync, not connected (screen 34)
/// ============================================================
///
/// What: Drive tile, "Connect Google Drive", three benefits and the
/// connect button (→ Sign in); "not set up in this build" when the OAuth
/// client ids weren't passed at build time.
/// Why: Drive is optional — the screen still offers local backups below.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/widgets/drive_logo.dart';
import 'package:go_router/go_router.dart';

/// Not connected: invite to connect Google Drive.
class ConnectDriveCard extends ConsumerWidget {
  const ConnectDriveCard({super.key});

  static const _benefits = [
    (FontAwesomeIcons.lock, 'Encrypted backups in a private app folder'),
    (FontAwesomeIcons.mobileScreen, 'Sync between your phones and tablets'),
    (FontAwesomeIcons.clockRotateLeft, 'Restore everything on a new device'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final text = context.text;
    final available = ref.watch(cloudAccountControllerProvider).googleAvailable;
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.iconTileLg,
                height: AppSizes.iconTileLg,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BackupTints.drive.soft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadii.tileLg),
                ),
                child: const DriveLogo(size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Google Drive',
                      style: text.cardTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Optional · FocusFlow works fully offline',
                      style: text.bodySmall.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (icon, label) in _benefits)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: ff.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(label, style: text.bodySmall)),
                ],
              ),
            ),
          if (!available) ...[
            const FFInfoBanner(
              icon: FontAwesomeIcons.circleInfo,
              text:
                  'Google Drive is not set up in this build. Local backups '
                  'still work.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FFPrimaryButton(
            label: 'Connect Google Drive',
            icon: FontAwesomeIcons.google,
            height: 50,
            onPressed: available ? () => context.push(AppRoutes.signIn) : null,
          ),
        ],
      ),
    );
  }
}
