/// Vault rows of the shared item actions sheet (screen 09): Copy username,
/// Copy password (or card number / note / the type's primary field),
/// Open website, Duplicate. Owned by the vault feature; see
/// shared/item_actions/module_item_actions.dart. Copying goes through
/// vault_copy_actions.dart (unlock → decrypt one payload → auto-clear).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
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
  // The payload is only readable while the vault is open: "Open website" is
  // offered when an address is saved, and a schema type names what its copy
  // button copies ("Copy IBAN").
  final payload =
      record.type == VaultItemType.login || record.type.isSchemaType
      ? await readVaultPayload(ref, record)
      : null;
  final website = payload == null
      ? null
      : vaultWebsiteUri(payload.websiteFor(record.type));
  final primary = payload == null || !record.type.isSchemaType
      ? null
      : record.type.primaryOf(payload.fields, payload.password).spec;
  if (!context.mounted) return ModuleItemActions.none;
  void copy(VaultCopyField field) =>
      unawaited(copyVaultSecret(context, ref, record, field: field));
  return ModuleItemActions(
    leading: [
      if (record.type == VaultItemType.login)
        FFActionItem(
          icon: FontAwesomeIcons.solidUser,
          label: tr('Copy username'),
          colors: colors,
          onTap: () => copy(VaultCopyField.username),
        ),
      FFActionItem(
        icon: FontAwesomeIcons.solidCopy,
        label: switch (record.type) {
          VaultItemType.card => tr('Copy card number'),
          VaultItemType.secureNote => tr('Copy note'),
          _ when record.type.isSchemaType => tr('Copy {what}', {
            'what': (primary?.label ?? record.type.label).toLowerCase(),
          }),
          _ => tr('Copy password'),
        },
        colors: colors,
        onTap: () => copy(VaultCopyField.primary),
      ),
      if (website != null)
        FFActionItem(
          icon: FontAwesomeIcons.arrowUpRightFromSquare,
          label: tr('Open website'),
          colors: colors,
          onTap: () => unawaited(openVaultWebsite(context, ref, record)),
        ),
      FFActionItem(
        icon: FontAwesomeIcons.solidClone,
        label: tr('Duplicate'),
        colors: colors,
        onTap: () => unawaited(duplicateVaultItem(context, ref, record)),
      ),
    ],
  );
}

/// A copy of [record] ("Name (copy)"): same type, fields, folder and tags,
/// re-sealed under a new id. It is never a favourite; a duplicated password
/// shows as REUSED until the user changes one of them, which is accurate.
Future<void> duplicateVaultItem(
  BuildContext context,
  WidgetRef ref,
  VaultItemRecord record,
) async {
  if (!await ensureVaultUnlocked(context)) return;
  final payload = await readVaultPayload(ref, record);
  final key = ref.read(vaultSessionProvider).key;
  if (!context.mounted) return;
  if (payload == null || key == null || key.isDestroyed) {
    showFFToast(context, tr("Couldn't decrypt this item"));
    return;
  }
  try {
    await ref
        .read(vaultItemServiceProvider)
        .save(
          key: key,
          draft: VaultItemDraft(
            type: record.type,
            title: tr('{title} (copy)', {'title': record.title}),
            iconKey: record.iconKey,
            colorHex: record.colorHex,
            folderId: record.folderId,
            tagNames: [for (final t in record.tags) t.name],
            expiryDays: record.expiryDays,
          ),
          payload: payload,
        );
  } on Object {
    if (context.mounted) showFFToast(context, tr("Couldn't save this item"));
    return;
  }
  ref.read(vaultSessionProvider.notifier).touch();
  if (context.mounted) {
    showFFToast(context, tr('Item duplicated'), icon: FontAwesomeIcons.solidCircleCheck);
  }
}
