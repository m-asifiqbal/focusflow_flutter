/// ============================================================
/// SETTINGS ACCOUNT CARD — profile summary at the top of Settings (30)
/// ============================================================
///
/// Signed in: avatar · name · provider logo + email · "Synced 2 min ago"
/// pill (live from the sync engine) with a small Sync button beside it →
/// Account & profile (36). The Sync button (Google Drive accounts, when
/// Drive is set up in this build) runs the same "Sync now" as Backup &
/// Sync — behind the backup PIN choice — spins while any sync runs and
/// toasts the result. It wears the pill's colours and corner radius; its
/// tap box is the full 44 pt, and the card's bottom padding gives back the
/// box's empty margin so the card keeps the mockup's proportions.
/// Signed out: "Sign in to back up" + Continue with Google (in place).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/auth/presentation/widgets/profile_avatar.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/widgets/google_logo.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_prompts.dart';
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
    final canSync =
        account.hasDrive &&
        ref.watch(cloudAccountControllerProvider).googleAvailable;
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
      _ when sync.isBusy => (
        tr('Syncing…'),
        null,
        FontAwesomeIcons.arrowsRotate,
      ),
      _ when sync.phase == SyncPhase.error => (
        tr('Sync paused'),
        TagPalette.finance,
        FontAwesomeIcons.triangleExclamation,
      ),
      _ => (
        SettingsLabels.syncedAgo(sync.lastSyncAt ?? lastSettingsSync, now),
        null,
        FontAwesomeIcons.solidCircleCheck,
      ),
    };

    // The Sync button's tap box overhangs the pill row by [_SyncButton.slack]
    // above and below: the gap above the row and the card's bottom padding
    // absorb it, and the avatar / chevron centre on what is visible.
    final slack = canSync ? _SyncButton.slack : 0.0;
    final badge = FFBadge(
      pill,
      icon: pillIcon,
      colors: pillColors,
      uppercase: false,
    );
    return FFCard(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg - slack,
      ),
      semanticLabel: tr('{name}, {email}. Account and profile', {
        'name': name,
        'email': account.email,
      }),
      onTap: () => context.push(AppRoutes.settingsAccount),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: slack),
            child: ProfileAvatar(
              initial: name.isEmpty
                  ? null
                  : name.characters.first.toUpperCase(),
              size: SettingsAccountCard._avatar,
              rounded: true,
              border: false,
            ),
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
                if (canSync)
                  Row(
                    children: [
                      Flexible(child: badge),
                      _SyncButton(status: sync, colors: pillColors),
                    ],
                  )
                else ...[
                  const SizedBox(height: AppSpacing.sm),
                  badge,
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: slack),
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? FontAwesomeIcons.chevronLeft
                  : FontAwesomeIcons.chevronRight,
              size: 13,
              color: ff.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "Sync now" chip beside the sync pill (its own tap target:
/// tapping it never opens Account & profile, even while a sync runs).
class _SyncButton extends ConsumerWidget {
  const _SyncButton({required this.status, this.colors});

  final SyncStatus status;

  /// The pill's colours (null = primary), so the two read as a pair.
  final ModuleColors? colors;

  /// The visible chip: about the pill's height, with its corner radius.
  static const double _chip = 26;

  /// Empty margin of the 44 pt tap box around the chip.
  static const double slack = (AppSizes.minTap - _chip) / 2;

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    FFHaptics.light(context);
    final outcome = await syncNowWithPrompt(context, ref);
    if (!context.mounted) return;
    final after = ref.read(syncStatusProvider);
    if (outcome != null) {
      final summary = SyncController.summary(outcome);
      showFFToast(
        context,
        summary,
        icon: FontAwesomeIcons.check,
        duration: Duration(seconds: summary.contains(' · ') ? 4 : 2),
      );
    } else if (after.phase == SyncPhase.error) {
      showFFToast(
        context,
        after.message ?? tr("Couldn't sync. Try again."),
        icon: FontAwesomeIcons.triangleExclamation,
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final busy = status.isBusy;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final c = colors;
    final bg = c == null ? ff.primarySoft : c.softFor(ff.brightness);
    final fg = c == null ? ff.primaryStrong : c.inkFor(ff.brightness);
    return Semantics(
      container: true,
      button: true,
      enabled: !busy,
      label: busy ? tr('Syncing with Google Drive') : tr('Sync now'),
      excludeSemantics: true,
      child: FFPressable(
        // A no-op while busy still claims the tap from the card.
        onTap: busy ? () {} : () => _sync(context, ref),
        scale: 0.92,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: Container(
              width: _chip,
              height: _chip,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: busy
                  ? SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: fg,
                        value: reduce ? (status.progress ?? 0.1) : null,
                      ),
                    )
                  : Icon(FontAwesomeIcons.arrowsRotate, size: 12, color: fg),
            ),
          ),
        ),
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
                rounded: true,
                border: false,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Sign in to back up'),
                      style: context.text.sectionTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      tr(
                        'Your data stays on this device. Add Google Drive to back up and sync.',
                      ),
                      style: context.text.bodySmall.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FFSecondaryButton(
            label: tr('Continue with Google'),
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
