/// Vault rows of the shared item actions sheet (screen 09): Copy username,
/// Copy password (or card number / note), Open website. Owned by the vault feature; see
/// shared/item_actions/module_item_actions.dart. Copying goes through
/// vault_copy_actions.dart (unlock → decrypt one payload → auto-clear).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Module rows for [item]. Each row's onTap runs after the sheet closes.
Future<ModuleItemActions> vaultItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final record = await ref.read(vaultRepositoryProvider).getItem(item.ref.id);
  if (record == null || !record.isActive || !context.mounted) {
    return ModuleItemActions.none;
  }
  final colors = ModuleStyle.vault.colors;
  // Only offered when the vault is open and a website is saved.
  final website = record.type == VaultItemType.login
      ? vaultWebsiteUri((await readVaultPayload(ref, record))?.url ?? '')
      : null;
  if (!context.mounted) return ModuleItemActions.none;
  void copy(VaultCopyField field) =>
      unawaited(copyVaultSecret(context, ref, record, field: field));
  return ModuleItemActions(
    leading: [
      if (record.type == VaultItemType.login)
        FFActionItem(
          icon: FontAwesomeIcons.solidUser,
          label: 'Copy username',
          colors: colors,
          onTap: () => copy(VaultCopyField.username),
        ),
      FFActionItem(
        icon: FontAwesomeIcons.solidCopy,
        label: switch (record.type) {
          VaultItemType.card => 'Copy card number',
          VaultItemType.secureNote => 'Copy note',
          _ => 'Copy password',
        },
        colors: colors,
        onTap: () => copy(VaultCopyField.primary),
      ),
      if (website != null)
        FFActionItem(
          icon: FontAwesomeIcons.arrowUpRightFromSquare,
          label: 'Open website',
          colors: colors,
          onTap: () => unawaited(openVaultWebsite(context, ref, record)),
        ),
    ],
  );
}
