/// ============================================================
/// SCREEN 17 — Vault locked (and first-run PIN set-up)
/// ============================================================
///
/// Header ("24 items · AES-256 encrypted") · disabled search with a lock ·
/// the lock card (biometrics + PIN pad) · two faded preview tiles. Nothing
/// is decrypted here, and the previews do not show titles either (spec:
/// "blurred names"): a masked placeholder of the title's length is drawn
/// blurred, so neither the screen nor a screenshot reveals the name. Biometrics are prompted once on open when enabled.
/// ============================================================
library;

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_avatar.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_header.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_lock_card.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultLockedView extends ConsumerWidget {
  const VaultLockedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final total = ref.watch(vaultCountsProvider).valueOrNull?.total ?? 0;
    final setUp = ref.watch(
      vaultPinPadProvider.select((s) => s.step == VaultPadStep.unlock),
    );
    final preview = ref.watch(vaultLockedPreviewProvider);
    return ListView(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
      ),
      children: [
        VaultHeader(
          subtitle: setUp
              ? tr(
                  '{count, plural, one {# item · AES-256 encrypted} other {# items · AES-256 encrypted}}',
                  {'count': total},
                )
              : tr('Set up · AES-256 encrypted'),
          lockLabel: tr('Vault is locked'),
          onLock: () => showFFToast(
            context,
            tr('Vault is locked'),
            icon: FontAwesomeIcons.lock,
          ),
          onAdd: () async {
            if (await ensureVaultUnlocked(context) && context.mounted) {
              unawaited(context.push(AppRoutes.newVaultItem()));
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.screen,
          ),
          child: FFSearchField(
            vault: true,
            readOnly: true,
            hint: tr(
              '{count, plural, one {Search # account…} other {Search # accounts…}}',
              {'count': total},
            ),
            trailing: Semantics(
              label: tr('Locked'),
              child: Icon(
                FontAwesomeIcons.lock,
                size: VaultSizes.iconMd,
                color: ff.vaultAccent.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.screen,
          ),
          child: VaultLockCard(),
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.screen,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _PreviewTile(record: preview.first)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: preview.length > 1
                      ? _PreviewTile(record: preview[1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The locked preview's stand-in for [title]: same rough length, no
/// letters of the real name.
@visibleForTesting
String maskedPreviewTitle(String title) =>
    'W' * title.trim().length.clamp(4, 12);

/// Faded tile: brand avatar, blurred masked title, masked dots — no names,
/// no secrets.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.record});

  final VaultItemRecord record;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: ff.vaultGlassFaint,
          borderRadius: BorderRadius.circular(AppRadii.card + 2),
          border: Border.all(color: ff.vaultBorder),
        ),
        child: Opacity(
          opacity: 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VaultAvatar.record(
                record,
                size: VaultSizes.totpRing,
                radius: AppRadii.tile,
              ),
              const SizedBox(height: AppSpacing.md + 2),
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Text(
                  maskedPreviewTitle(record.title),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: context.text.cardTitle.copyWith(
                    fontSize: VaultType.value,
                    color: ff.vaultInk,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '•' * 10,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: context.text.meta.copyWith(
                  letterSpacing: 2,
                  color: ff.vaultInkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
