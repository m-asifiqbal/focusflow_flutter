/// ============================================================
/// VAULT DETAIL ACTIONS — what the item detail's buttons do (screen 19)
/// ============================================================
///
/// Reveal (optional biometric / PIN re-auth per Settings › Vault security
/// › Ask for PIN to reveal), copy an already-decrypted value with auto-clear,
/// favourite, open the editor, Archive / Delete through the shared
/// lifecycle actions (confirmation + 5 s Undo). Every action counts as
/// vault activity for the auto-lock timer. Nothing here logs a value.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Shows / hides [field] of item [id]. Revealing re-authenticates first
/// when "Ask for PIN to reveal passwords" is on (biometrics, else PIN).
Future<void> toggleVaultReveal(
  BuildContext context,
  WidgetRef ref,
  String id,
  String field,
) async {
  ref.read(vaultSessionProvider.notifier).touch();
  final reveal = ref.read(vaultRevealProvider(id).notifier);
  if (!reveal.isShown(field) && !await confirmVaultReveal(context, ref)) {
    return;
  }
  reveal.toggle(field);
}

/// Copies an already-decrypted [value] ("Password", "Code", "Website" …
/// as [what]). Secrets clear after Settings › Clipboard clear; a username
/// or website ([secret] false) stays.
Future<void> copyVaultValue(
  BuildContext context,
  WidgetRef ref,
  String value,
  String what, {
  bool secret = true,
}) async {
  if (value.isEmpty) return;
  final settings = ref.read(settingsProvider);
  final seconds = settings.clipboardClearSeconds;
  final clears = secret && seconds > 0;
  await ref
      .read(secureClipboardProvider)
      .copy(value, clearAfter: clears ? Duration(seconds: seconds) : null);
  ref.read(vaultSessionProvider.notifier).touch();
  if (settings.hapticsEnabled) unawaited(HapticFeedback.lightImpact());
  if (!context.mounted) return;
  showFFToast(
    context,
    clears ? '$what copied · clears in ${seconds}s' : '$what copied',
    icon: FontAwesomeIcons.solidCircleCheck,
  );
}

Future<void> toggleVaultFavourite(WidgetRef ref, VaultItemRecord record) {
  ref.read(vaultSessionProvider.notifier).touch();
  return ref.read(itemsRepositoryProvider).setFavorite([
    record.ref,
  ], !record.isFavorite);
}

/// Archives the item and leaves the detail screen (Undo restores it).
Future<void> archiveVaultItem(
  BuildContext context,
  WidgetRef ref,
  VaultItemRecord record,
) async {
  final router = GoRouter.of(context);
  final done = await archiveItems(context, ref, [
    record.ref,
  ], title: record.title);
  if (done && router.canPop()) router.pop();
}

/// Confirms, moves the item to Recently Deleted and leaves the screen.
Future<void> deleteVaultItem(
  BuildContext context,
  WidgetRef ref,
  VaultItemRecord record,
) async {
  final router = GoRouter.of(context);
  final done = await deleteItems(context, ref, [
    record.ref,
  ], title: record.title);
  if (done && router.canPop()) router.pop();
}

/// Decrypts every previous password of [id] (newest first) for the
/// history sheet; empty when locked.
Future<List<(DateTime, String)>> readVaultHistory(
  WidgetRef ref,
  List<VaultHistoryEntry> entries,
) async {
  final key = ref.read(vaultSessionProvider).key;
  if (key == null || key.isDestroyed) return const [];
  final out = <(DateTime, String)>[];
  for (final e in entries) {
    try {
      out.add((e.changedAt, await _openHistory(ref, e)));
    } on Object {
      // Unreadable entry (other key): skipped, never shown half-decoded.
    }
  }
  return out;
}

Future<String> _openHistory(WidgetRef ref, VaultHistoryEntry e) {
  final key = ref.read(vaultSessionProvider).requireKey();
  return VaultItemService.openHistory(key, e.encryptedPassword);
}
