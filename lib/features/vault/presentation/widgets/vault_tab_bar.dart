/// ============================================================
/// VAULT TAB BAR — the vault's inner tabs (Vault · Generator · Favourites ·
/// Security), on the dark #042A21 @95 % bar (screens 17–22)
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

enum VaultTab {
  vault('Vault', FontAwesomeIcons.shieldHalved),
  generator('Generator', FontAwesomeIcons.wandMagicSparkles),
  favourites('Favourites', FontAwesomeIcons.solidHeart),
  security('Security', FontAwesomeIcons.shieldHeart);

  const VaultTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class VaultTabController extends AutoDisposeNotifier<VaultTab> {
  @override
  VaultTab build() => VaultTab.vault;

  void select(VaultTab tab) => state = tab;
}

/// The selected inner tab (resets when the vault screen closes).
final vaultTabProvider =
    NotifierProvider.autoDispose<VaultTabController, VaultTab>(
      VaultTabController.new,
    );

class VaultTabBar extends ConsumerWidget {
  const VaultTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final current = ref.watch(vaultTabProvider);
    final haptics = ref.watch(settingsProvider.select((s) => s.hapticsEnabled));
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        // Opaque: the 95 % bar over the canvas, so rows never show through.
        color: Color.alphaBlend(ff.vaultTabBar, ff.vaultCanvas),
        border: Border(top: BorderSide(color: ff.vaultBorder)),
      ),
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: bottom > 0 ? bottom : AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final tab in VaultTab.values)
            Expanded(
              child: _TabItem(
                tab: tab,
                selected: tab == current,
                onTap: () {
                  if (haptics) unawaited(HapticFeedback.selectionClick());
                  ref.read(vaultTabProvider.notifier).select(tab);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final VaultTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final color = selected ? ff.vaultAccent : ff.vaultTabIdle;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Icon(tab.icon, size: VaultSizes.iconLg, color: color),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.15),
                style: context.text.meta.copyWith(
                  fontSize: VaultType.label,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
