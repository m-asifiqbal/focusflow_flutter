/// ============================================================
/// ACCOUNT SCREEN — Settings › Account & profile (screen 36)
/// ============================================================
///
/// What: "‹ Settings | Account | Edit" over avatar + name + account line,
/// the stats card, PROFILE, LINKED DEVICES and DANGER ZONE.
/// Why: one place for who-am-I and the account-level destructive actions;
/// everything reads live providers (settings, library counts, Drive
/// manifest) so edits show up everywhere at once.
///
/// Signed-out variant: the account line says "Offline", a card offers
/// "Connect Google Drive" (→ Sign in), devices list only this device and
/// the danger zone only offers Erase local data.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/data/profile_photo_picker.dart';
import 'package:focusflow/features/auth/presentation/notifiers/account_actions_controller.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/auth/presentation/widgets/account_danger_section.dart';
import 'package:focusflow/features/auth/presentation/widgets/account_editors.dart';
import 'package:focusflow/features/auth/presentation/widgets/account_header.dart';
import 'package:focusflow/features/auth/presentation/widgets/account_profile_section.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _pickPhoto(
    BuildContext context,
    WidgetRef ref, {
    required bool camera,
  }) async {
    try {
      final bytes = await ref
          .read(profilePhotoPickerProvider)
          .pick(camera: camera);
      if (bytes == null) return;
      await ref.read(accountActionsProvider.notifier).setPhoto(bytes);
    } on Object {
      if (context.mounted) {
        showUndoSnackbar(
          context,
          message: "Couldn't use that photo.",
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    }
  }

  void _photoOptions(BuildContext context, WidgetRef ref) {
    final hasPhoto = ref.read(profilePhotoProvider).valueOrNull != null;
    final tint = ModuleStyle.notes.colors;
    showFFActionSheet(
      context,
      FFActionSheetData(
        header: FFActionSheetHeader(
          title: 'Profile',
          icon: FontAwesomeIcons.solidUser,
          colors: tint,
        ),
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.solidImage,
            label: 'Choose photo',
            colors: tint,
            onTap: () => _pickPhoto(context, ref, camera: false),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.camera,
            label: 'Take photo',
            colors: tint,
            onTap: () => _pickPhoto(context, ref, camera: true),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.pen,
            label: 'Edit display name',
            colors: ModuleStyle.tasks.colors,
            onTap: () async {
              final current = ref.read(settingsProvider).displayName;
              final name = await showDisplayNameSheet(context, current);
              if (name != null) {
                await ref
                    .read(accountActionsProvider.notifier)
                    .setDisplayName(name);
              }
            },
          ),
          if (hasPhoto)
            FFActionItem(
              icon: FontAwesomeIcons.trashCan,
              label: 'Remove photo',
              colors: ModuleStyle.scan.colors,
              destructive: true,
              onTap: () =>
                  ref.read(accountActionsProvider.notifier).setPhoto(null),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(cloudAccountProvider) != null;
    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: const FFBackButton(label: 'Settings'),
            title: 'Account',
            trailing: [
              FFNavAction(
                label: 'Edit',
                onPressed: () => _photoOptions(context, ref),
              ),
            ],
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
                AccountHeader(onPhotoTap: () => _photoOptions(context, ref)),
                const SizedBox(height: AppSpacing.xxl),
                if (!signedIn) ...[
                  const _ConnectDriveCard(),
                  const SizedBox(height: AppSpacing.cardGap),
                ],
                const AccountStatsCard(),
                const SizedBox(height: AppSpacing.section),
                const AccountProfileSection(),
                const SizedBox(height: AppSpacing.section),
                const AccountDevicesSection(),
                const SizedBox(height: AppSpacing.section),
                const AccountDangerSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed-out variant: invite to connect Google Drive.
class _ConnectDriveCard extends StatelessWidget {
  const _ConnectDriveCard();

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FFIconTile.soft(
                icon: FontAwesomeIcons.cloudArrowUp,
                colors: ModuleStyle.notes.colors,
                size: AppSizes.iconTile,
                iconSize: 16,
              ),
              const SizedBox(width: AppSpacing.rowLeadingGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Not signed in', style: text.rowTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Connect Google Drive for encrypted backup and sync '
                      'across your devices.',
                      style: text.bodySmall.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FFSecondaryButton(
            label: 'Connect Google Drive',
            icon: FontAwesomeIcons.google,
            onPressed: () => context.push(AppRoutes.signIn),
          ),
        ],
      ),
    );
  }
}
