/// ============================================================
/// ACCOUNT HEADER — avatar, name, account line and the stats card
/// ============================================================
///
/// * [AccountHeader] — 96-pt avatar (local photo or initial) with a camera
///   badge, the account's name and a provider line (Google "G" + email,
///   Apple, or "Offline · data stays on this device").
/// * [AccountStatsCard] — Items · Best streak · Days active (live).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/auth/presentation/widgets/google_logo.dart';
import 'package:focusflow/features/auth/presentation/widgets/profile_avatar.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The name shown under the avatar: the account's full name, else the
/// display name, else a neutral fallback.
String accountHeaderName(CloudAccount? account, String displayName) =>
    _realName(account, displayName) ?? tr('Your profile');

/// The account's / display name, or null when there is none (the header then
/// shows the neutral fallback and the avatar its placeholder). Kept apart from
/// the fallback text so the logic never compares against a translated label.
String? _realName(CloudAccount? account, String displayName) {
  final full = account?.displayName?.trim() ?? '';
  if (full.isNotEmpty) return full;
  if (displayName.trim().isNotEmpty) return displayName.trim();
  return null;
}

class AccountHeader extends ConsumerWidget {
  const AccountHeader({required this.onPhotoTap, super.key});

  /// Opens the photo options (choose / take / remove).
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final text = context.text;
    final account = ref.watch(cloudAccountProvider);
    final displayName = ref.watch(
      settingsProvider.select((s) => s.displayName),
    );
    final realName = _realName(account, displayName);
    final name = realName ?? tr('Your profile');

    final Widget providerIcon = switch (account?.provider) {
      CloudProvider.google => const GoogleLogo(size: 15),
      CloudProvider.apple => Icon(
        FontAwesomeIcons.apple,
        size: 15,
        color: ff.inkMuted,
      ),
      null => Icon(
        FontAwesomeIcons.solidHardDrive,
        size: 13,
        color: ff.inkMuted,
      ),
    };
    final providerText = switch (account) {
      null => tr('Offline · data stays on this device'),
      final a when a.email.isNotEmpty => a.email,
      _ => tr('Signed in with Apple'),
    };

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(
              initial: realName,
              size: 96,
              onTap: onPhotoTap,
              semanticLabel: tr('Change profile photo'),
            ),
            PositionedDirectional(
              end: -2,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ff.primaryStrong,
                    shape: BoxShape.circle,
                    border: Border.all(color: ff.canvas, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    FontAwesomeIcons.camera,
                    size: 11,
                    color: ff.onGradient,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            providerIcon,
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                providerText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AccountStatsCard extends ConsumerWidget {
  const AccountStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(accountStatsProvider);
    final s = stats.valueOrNull;
    final values = [
      (s?.items, tr('Items')),
      (s?.bestStreak, tr('Best streak')),
      (s?.daysActive, tr('Days active')),
    ];
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 0,
        vertical: 18,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.ff.divider,
                ),
              Expanded(
                child: _Stat(
                  value: values[i].$1,
                  label: values[i].$2,
                  failed: stats.hasError,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.failed});

  final int? value;
  final String label;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final v = value;
    return Semantics(
      label: tr('{label}: {value}', {
        'label': label,
        'value': v ?? (failed ? tr('unavailable') : tr('loading')),
      }),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (v == null && !failed)
            const FFSkeleton(width: 44, height: 24)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                v == null ? '–' : '$v',
                style: text.stat.copyWith(fontSize: 20),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: text.bodySmall.copyWith(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: context.ff.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
