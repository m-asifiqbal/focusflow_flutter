/// ============================================================
/// VAULT GENERATOR HISTORY — "RECENTLY GENERATED" card + history sheet
/// ============================================================
///
/// The card lists the newest three values (mono, muted) with "2m ago" and
/// a copy button; the header's history button opens the sheet with all
/// ten and "Clear history". Values come decrypted from
/// vaultGeneratorHistoryProvider and are only ever shown or copied.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_generator_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_generator_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// "now", "2m ago", "1h ago", "3d ago".
String vaultShortAgo(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return tr('now');
  if (d.inHours < 1) return tr('{n}m ago', {'n': d.inMinutes});
  if (d.inDays < 1) return tr('{n}h ago', {'n': d.inHours});
  return tr('{n}d ago', {'n': d.inDays});
}

/// Copies [value] from the history (toast + haptic).
Future<void> copyGeneratedValue(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final seconds = await ref
      .read(generatorControllerProvider.notifier)
      .copy(value);
  if (seconds == null || !context.mounted) return;
  if (ref.read(settingsProvider).hapticsEnabled) {
    unawaited(HapticFeedback.lightImpact());
  }
  showFFToast(
    context,
    seconds > 0 ? tr('Copied · clears in {s}s', {'s': seconds}) : tr('Copied'),
    icon: FontAwesomeIcons.solidCircleCheck,
  );
}

/// The "RECENTLY GENERATED" section (hidden while empty).
class VaultRecentGenerated extends ConsumerWidget {
  const VaultRecentGenerated({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vaultGeneratorHistoryProvider).valueOrNull;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VaultSectionLabel(tr('Recently generated')),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.ff.vaultSurface,
            borderRadius: BorderRadius.circular(vaultCardRadius),
            border: Border.all(color: context.ff.vaultBorder),
          ),
          child: Column(
            children: [
              for (final e in entries.take(3)) _HistoryRow(entry: e, now: now),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry, required this.now});

  final GeneratorHistoryEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final when = vaultShortAgo(entry.createdAt, now);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: VaultSizes.historyRow),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.lg + 1,
          end: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.vaultMonoStyle.copyWith(
                  fontSize: VaultType.subtitle,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.6,
                  color: ff.vaultInkSoft,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              when,
              style: context.text.caption.copyWith(
                fontSize: VaultType.caption,
                color: ff.vaultFieldLabel,
              ),
            ),
            Semantics(
              button: true,
              label: tr('Copy value generated {when}', {'when': when}),
              excludeSemantics: true,
              child: FFPressable(
                onTap: () => copyGeneratedValue(context, ref, entry.value),
                child: SizedBox.square(
                  dimension: AppSizes.minTap,
                  child: Icon(
                    FontAwesomeIcons.solidCopy,
                    size: VaultSizes.iconLg,
                    color: ff.vaultAccentBright,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All remembered values (max 10) with copy and "Clear history".
Future<void> showVaultGeneratorHistorySheet(BuildContext context) =>
    showFFBottomSheet<void>(
      context,
      vault: true,
      builder: (_) => const _HistorySheet(),
    );

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final entries = ref.watch(vaultGeneratorHistoryProvider).valueOrNull;
    final now = ref.watch(clockProvider).now();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.grouped,
        0,
        AppSpacing.grouped,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Generator history'),
            style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr(
              'The last 10 values you copied or saved · encrypted on this device only.',
            ),
            style: context.text.bodySmall.copyWith(color: ff.vaultInkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (entries == null)
            const FFSkeleton(height: VaultSizes.skeletonRows)
          else if (entries.isEmpty)
            FFEmptyState.compact(
              colors: ModuleStyle.vault.colors,
              icon: FontAwesomeIcons.clockRotateLeft,
              title: tr('Nothing yet'),
              body: tr('Values you copy or save show up here.'),
            )
          else ...[
            VaultCard(
              children: [
                for (final e in entries) _HistoryRow(entry: e, now: now),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FFTextButton(
              label: tr('Clear history'),
              color: ff.vaultDanger.fg,
              onPressed: () async {
                await ref
                    .read(generatorControllerProvider.notifier)
                    .clearHistory();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}
