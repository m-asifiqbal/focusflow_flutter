/// ============================================================
/// VAULT GENERATOR VIEW — the Generator inner tab (screen 21)
/// ============================================================
///
/// Title + history button, Password / Passphrase / PIN, the result card
/// (Regenerate / Copy), OPTIONS, RECENTLY GENERATED and "Save to new vault
/// item" (parks the value in memory for the editor — never in the URL).
/// State: generatorControllerProvider; history: encrypted, last 10.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_generator_controller.dart';
import 'package:focusflow/features/vault/presentation/widgets/generator/vault_generator_history.dart';
import 'package:focusflow/features/vault/presentation/widgets/generator/vault_generator_options.dart';
import 'package:focusflow/features/vault/presentation/widgets/generator/vault_generator_result.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_primary_button.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_tab_title.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultGeneratorView extends ConsumerWidget {
  const VaultGeneratorView({super.key});

  static const _segments = [
    FFSegment(value: GeneratorMode.password, label: 'Password'),
    FFSegment(value: GeneratorMode.passphrase, label: 'Passphrase'),
    FFSegment(value: GeneratorMode.pin, label: 'PIN'),
  ];

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final c = ref.read(generatorControllerProvider.notifier);
    final mode = ref.read(generatorControllerProvider).mode;
    final seconds = await c.copy();
    if (seconds == null || !context.mounted) return;
    if (ref.read(settingsProvider).hapticsEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
    final what = switch (mode) {
      GeneratorMode.password => 'Password',
      GeneratorMode.passphrase => 'Passphrase',
      GeneratorMode.pin => 'PIN',
    };
    showFFToast(
      context,
      seconds > 0 ? '$what copied · clears in ${seconds}s' : '$what copied',
      icon: FontAwesomeIcons.solidCircleCheck,
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(generatorControllerProvider.notifier)
        .prepareNewItem();
    if (!ok || !context.mounted) return;
    unawaited(context.push(AppRoutes.newVaultItem(type: 'login')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(generatorControllerProvider);
    final c = ref.read(generatorControllerProvider.notifier);
    const gutter = EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.grouped,
    );
    return ListView(
      // The inner tab bar overlays the body: MediaQuery's bottom padding
      // here is its height, so the last card can scroll clear of it.
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
      ),
      children: [
        VaultTabTitle(
          title: 'Generator',
          trailing: VaultGlassButton(
            icon: FontAwesomeIcons.clockRotateLeft,
            semanticLabel: 'Generator history',
            onTap: () => showVaultGeneratorHistorySheet(context),
          ),
        ),
        const SizedBox(height: AppSpacing.lg + 2),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: vaultTabTitleInset,
          ),
          child: FFSegmented<GeneratorMode>(
            vault: true,
            height: VaultSizes.segmentedLg,
            segments: _segments,
            value: s.mode,
            onChanged: c.setMode,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: vaultTabTitleInset,
          ),
          child: VaultGeneratorResult(
            value: s.value,
            onRegenerate: c.regenerate,
            onCopy: s.value == null ? null : () => _copy(context, ref),
          ),
        ),
        const Padding(
          padding: gutter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VaultSectionLabel('Options'),
              VaultGeneratorOptions(),
              VaultRecentGenerated(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl + 1),
        Padding(
          padding: gutter,
          child: VaultPrimaryButton(
            label: 'Save to new vault item',
            icon: FontAwesomeIcons.solidFloppyDisk,
            fontSize: VaultType.row,
            onPressed: s.value == null ? null : () => _save(context, ref),
          ),
        ),
      ],
    );
  }
}
