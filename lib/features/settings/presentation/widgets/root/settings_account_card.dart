/// ============================================================
/// SETTINGS ACCOUNT CARD — profile summary at the top of Settings (30)
/// ============================================================
///
/// Signed in: avatar · name · provider logo + email · "SYNCED 2 MIN AGO"
/// pill (live from the sync engine) → Account & profile (36).
/// Signed out: "Sign in to back up" + Continue with Google (in place).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/auth/presentation/widgets/profile_avatar.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/widgets/google_logo.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsAccountCard extends ConsumerWidget {
  const SettingsAccountCard({super.key});

  static const double _avatar = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(cloudAccountProvider);
    return account == null
        ? const _SignedOutCard()
        : _SignedInCard(account: account);
  }
}

class _SignedInCard extends ConsumerWidget {
  const _SignedInCard({required this.account});

  final CloudAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final settingsName = ref.watch(
      settingsProvider.select((s) => s.displayName),
    );
    final lastSettingsSync = ref.watch(
      settingsProvider.select((s) => s.lastSyncAt),
    );
    final sync = ref.watch(syncStatusProvider);
    final now = ref.watch(clockProvider).now();
    final name = settingsName.trim().isNotEmpty
        ? settingsName.trim()
        : (account.displayName?.trim().isNotEmpty ?? false)
        ? account.displayName!.trim()
        : account.email.split('@').first;

    final (
      String pill,
      ModuleColors? pillColors,
      IconData pillIcon,
    ) = switch (sync) {
      _ when sync.isBusy => ('SYNCING…', null, FontAwesomeIcons.arrowsRotate),
      _ when sync.phase == SyncPhase.error => (
        'SYNC PAUSED',
        TagPalette.finance,
        FontAwesomeIcons.triangleExclamation,
      ),
      _ => (
        SettingsLabels.syncedAgo(sync.lastSyncAt ?? lastSettingsSync, now),
        null,
        FontAwesomeIcons.solidCircleCheck,
      ),
    };

    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      semanticLabel: '$name, ${account.email}. Account and profile',
      onTap: () => context.push(AppRoutes.settingsAccount),
      child: Row(
        children: [
          ProfileAvatar(
            initial: name.isEmpty ? null : name.characters.first.toUpperCase(),
            size: SettingsAccountCard._avatar,
            border: false,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.sectionTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    if (account.provider == CloudProvider.google)
                      const GoogleLogo(size: 14)
                    else
                      Icon(FontAwesomeIcons.apple, size: 14, color: ff.ink),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall.copyWith(height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FFBadge(pill, icon: pillIcon, colors: pillColors),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? FontAwesomeIcons.chevronLeft
                : FontAwesomeIcons.chevronRight,
            size: 13,
            color: ff.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _SignedOutCard extends ConsumerWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final name = ref.watch(settingsProvider.select((s) => s.displayName));
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfileAvatar(
                initial: name.trim().isEmpty
                    ? null
                    : name.trim().characters.first.toUpperCase(),
                size: SettingsAccountCard._avatar,
                border: false,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in to back up',
                      style: context.text.sectionTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Your data stays on this device. Add Google Drive to '
                      'back up and sync.',
                      style: context.text.bodySmall.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FFSecondaryButton(
            label: 'Continue with Google',
            icon: FontAwesomeIcons.google,
            variant: FFSecondaryVariant.outlined,
            foreground: ff.ink,
            onPressed: () => signInWithGoogle(context, ref),
          ),
        ],
      ),
    );
  }
}
