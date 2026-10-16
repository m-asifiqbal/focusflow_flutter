/// ============================================================
/// VAULT SECURITY ACTIONS — Change / Fix / Update / Fix all (screen 22)
/// ============================================================
///
/// * Change (breached) — opens the item's editor and, when it has a
///   website, the site itself so the password can be changed there.
/// * Fix (reused / weak), Update (old) — the editor.
/// * Fix all — walks the issues one editor at a time; stops as soon as an
///   editor is closed without saving.
/// * [rescanVault] — pull-to-refresh / breach-monitoring switch.
/// The editor (and the browser opened by "Change") run inside
/// keepUnlockedDuring, so the background lock does not drop the editor
/// while the user changes the password on the website. Turning breach
/// monitoring on/off asks for the PIN / biometrics first, as in Settings.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/services/vault_security_report.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_security_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// The action pill's label for [kind].
String vaultIssueAction(VaultIssueKind kind) => switch (kind) {
  VaultIssueKind.breached => 'Change',
  VaultIssueKind.old => 'Update',
  _ => 'Fix',
};

/// Opens the fix flow for [issue]; true when the item was saved.
Future<bool> fixVaultIssue(
  BuildContext context,
  WidgetRef ref,
  VaultIssue issue,
) async {
  final repo = ref.read(vaultRepositoryProvider);
  final before = await repo.getItem(issue.itemId);
  if (before == null || !context.mounted) return false;
  Uri? site;
  if (issue.kind == VaultIssueKind.breached) {
    final payload = await readVaultPayload(ref, before);
    site = payload == null ? null : vaultWebsiteUri(payload.url);
    if (!context.mounted) return false;
  }
  final session = ref.read(vaultSessionProvider.notifier);
  await session.keepUnlockedDuring(() async {
    final editing = context.push<void>(AppRoutes.vaultItemEdit(issue.itemId));
    if (site != null) {
      await launchUrl(site, mode: LaunchMode.externalApplication);
    }
    await editing;
  });
  final after = await repo.getItem(issue.itemId);
  return after != null && after.updatedAt != before.updatedAt;
}

/// Walks [issues] one by one (stops when an editor is left unsaved).
Future<void> fixAllVaultIssues(
  BuildContext context,
  WidgetRef ref,
  List<VaultIssue> issues,
) async {
  var fixed = 0;
  for (final issue in issues) {
    if (!context.mounted) return;
    if (!await fixVaultIssue(context, ref, issue)) break;
    fixed++;
  }
  if (!context.mounted || fixed == 0) return;
  showFFToast(
    context,
    fixed == issues.length
        ? 'All $fixed fixed'
        : '$fixed of ${issues.length} fixed',
    icon: FontAwesomeIcons.solidCircleCheck,
  );
}

/// Runs a rescan and reports offline / locked results.
Future<void> rescanVault(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(vaultScanProvider.notifier).rescan();
  if (!context.mounted) return;
  switch (result) {
    case VaultScanResult.offline:
      showFFToast(context, "Couldn't reach the breach service · try again");
    case VaultScanResult.locked:
      showFFToast(context, 'Unlock the vault to scan');
    case VaultScanResult.done:
      break;
  }
}

/// Turns breach monitoring on / off from the dashboard after the same
/// re-auth as Settings › Vault security; turning it on scans right away.
Future<void> setBreachMonitoring(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final confirmed = await vaultReauthenticate(
    context,
    ref,
    reason: 'Confirm to change breach monitoring',
  );
  if (!confirmed) return;
  await ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(breachMonitoring: on));
  if (!on || !context.mounted) return;
  showFFToast(context, 'Breach monitoring on · only hash prefixes are sent');
  await rescanVault(context, ref);
}
