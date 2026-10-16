/// ============================================================
/// VAULT PROTECTION CARD — breach monitoring + 2FA coverage (screen 22)
/// ============================================================
///
/// Two rows in a vault card: the opt-in "Breach monitoring" switch (HIBP
/// k-anonymity; turning it on scans right away) and "2FA coverage"
/// (logins with a one-time code / all logins).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_security_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_security_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultProtectionCard extends ConsumerWidget {
  const VaultProtectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final monitoring = ref.watch(
      settingsProvider.select((s) => s.breachMonitoring),
    );
    final report = ref.watch(securityReportProvider).valueOrNull;
    final labelStyle = context.text.rowTitle.copyWith(
      fontSize: VaultType.row,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: ff.vaultInk,
    );
    return VaultCard(
      children: [
        _Row(
          child: Row(
            children: [
              Expanded(child: Text('Breach monitoring', style: labelStyle)),
              const SizedBox(width: AppSpacing.md),
              FFSwitch(
                vault: true,
                value: monitoring,
                semanticLabel: 'Breach monitoring',
                onChanged: (on) =>
                    unawaited(setBreachMonitoring(context, ref, on)),
              ),
            ],
          ),
        ),
        if (report != null)
          _Row(
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(child: Text('2FA coverage', style: labelStyle)),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${report.loginsWithTotp} / ${report.logins}',
                    style: context.text.title.copyWith(
                      fontSize: VaultType.value,
                      fontWeight: FontWeight.w600,
                      color: ff.vaultAccentBright,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg + 2,
        vertical: AppSpacing.sm,
      ),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    ),
  );
}
