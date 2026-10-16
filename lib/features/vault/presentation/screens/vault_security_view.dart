/// ============================================================
/// VAULT SECURITY VIEW — the Security inner tab (screen 22)
/// ============================================================
///
/// Title + "Last scan", the health ring and weekly delta, the four count
/// tiles, NEEDS ATTENTION (fix actions + Fix all) or the all-good card,
/// and PROTECTION (breach monitoring switch, 2FA coverage). Pull to
/// rescan; opening the tab rescans when the last scan is a day old.
/// Data: securityReportProvider + vaultScanProvider (live from the DB).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/services/vault_security_report.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_security_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_security_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/security/vault_issue_list.dart';
import 'package:focusflow/features/vault/presentation/widgets/security/vault_protection_card.dart';
import 'package:focusflow/features/vault/presentation/widgets/security/vault_security_summary.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_tab_title.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultSecurityView extends ConsumerStatefulWidget {
  const VaultSecurityView({super.key});

  @override
  ConsumerState<VaultSecurityView> createState() => _VaultSecurityViewState();
}

class _VaultSecurityViewState extends ConsumerState<VaultSecurityView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vaultScanProvider.notifier).scanIfDue());
    });
  }

  String _lastScan(DateTime? at) {
    if (at == null) return 'Not scanned yet';
    final now = ref.read(clockProvider).now();
    final use24h = ref.read(settingsProvider).use24HourTime;
    final day = DateUtilsX.relativeDay(at, now);
    final dayText = DateUtilsX.daysBetween(at, now).abs() <= 1
        ? day.toLowerCase()
        : day;
    final time = DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(at);
    return 'Last scan: $dayText, $time';
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final report = ref.watch(securityReportProvider);
    final scan = ref.watch(vaultScanProvider);
    final subtitle = scan.scanning ? 'Scanning…' : _lastScan(scan.lastScanAt);

    final List<Widget> body = switch (report) {
      AsyncData(:final value) => _content(context, value, scan),
      AsyncError() => [
        const SizedBox(height: AppSpacing.xxxl),
        FFEmptyState.compact(
          colors: ModuleStyle.vault.colors,
          icon: FontAwesomeIcons.triangleExclamation,
          title: "Couldn't build the report",
          body: 'Your items are safe. Try again in a moment.',
          ctaLabel: 'Try again',
          ctaIcon: FontAwesomeIcons.rotateRight,
          onCta: () => ref.invalidate(securityReportProvider),
        ),
      ],
      _ => const [_SecuritySkeleton()],
    };

    return RefreshIndicator(
      color: ff.vaultAccent,
      backgroundColor: ff.vaultSurface,
      onRefresh: () => rescanVault(context, ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xxxl),
        children: [
          VaultTabTitle(title: 'Security', subtitle: subtitle),
          ...body,
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    VaultSecurityReport r,
    VaultScanState scan,
  ) {
    const gutter = EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.grouped,
    );
    if (r.isEmpty) {
      return [
        const SizedBox(height: AppSpacing.xxxl),
        FFEmptyState.compact(
          colors: ModuleStyle.vault.colors,
          icon: FontAwesomeIcons.shieldHeart,
          title: 'Nothing to check yet',
          body: 'Save a password and its health shows up here.',
        ),
        const Padding(padding: gutter, child: VaultProtectionCard()),
      ];
    }
    final weekAgo = scan.weekAgoScore;
    return [
      const SizedBox(height: AppSpacing.xxxl - 2),
      Center(child: VaultHealthRing(score: r.score)),
      if (weekAgo != null) ...[
        const SizedBox(height: AppSpacing.xl),
        Center(child: VaultScoreDelta(delta: r.score - weekAgo)),
      ],
      const SizedBox(height: AppSpacing.xxl + 2),
      Padding(
        padding: gutter,
        child: VaultStatTiles(report: r),
      ),
      if (r.allGood) ...[
        const SizedBox(height: AppSpacing.xxl),
        const Padding(padding: gutter, child: VaultAllGood()),
      ] else ...[
        _AttentionHeader(
          count: r.issues.length,
          onFixAll: () => fixAllVaultIssues(context, ref, r.issues),
        ),
        Padding(
          padding: gutter,
          child: VaultIssueCard(
            issues: r.issues,
            onFix: (issue) => unawaited(fixVaultIssue(context, ref, issue)),
          ),
        ),
      ],
      const _ProtectionLabel(),
      const Padding(padding: gutter, child: VaultProtectionCard()),
    ];
  }
}

TextStyle _labelStyle(BuildContext context) =>
    context.text.sectionLabel.copyWith(
      fontSize: VaultType.label,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.2,
      color: context.ff.vaultLabel,
    );

class _AttentionHeader extends StatelessWidget {
  const _AttentionHeader({required this.count, required this.onFixAll});

  final int count;
  final VoidCallback onFixAll;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'NEEDS ATTENTION · $count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle(context),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Fix all $count issues',
            excludeSemantics: true,
            child: FFPressable(
              onTap: onFixAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTap,
                  minWidth: AppSizes.minTap,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Fix all',
                      style: context.text.body.copyWith(
                        fontSize: VaultType.small,
                        fontWeight: FontWeight.w700,
                        color: ff.vaultAccentBright,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionLabel extends StatelessWidget {
  const _ProtectionLabel();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xxl,
      AppSpacing.xxl + 4,
      AppSpacing.xxl,
      AppSpacing.md + 2,
    ),
    child: Semantics(
      header: true,
      child: Text('PROTECTION', style: _labelStyle(context)),
    ),
  );
}

class _SecuritySkeleton extends StatelessWidget {
  const _SecuritySkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.grouped),
    child: Column(
      children: [
        SizedBox(height: AppSpacing.xxxl),
        FFSkeleton(
          width: VaultSizes.scoreGauge,
          height: VaultSizes.scoreGauge,
          radius: VaultSizes.scoreGauge / 2,
        ),
        SizedBox(height: AppSpacing.xxl),
        FFSkeleton(height: VaultSizes.securityTile, radius: AppRadii.card),
        SizedBox(height: AppSpacing.xxl),
        FFSkeleton(height: VaultSizes.skeletonCardLg, radius: AppRadii.card),
      ],
    ),
  );
}
