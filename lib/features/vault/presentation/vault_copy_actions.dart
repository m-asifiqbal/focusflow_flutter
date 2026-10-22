/// ============================================================
/// VAULT COPY ACTIONS — copy a secret with auto-clear + toast (18 / 09)
/// ============================================================
///
/// The list's copy button and the item-actions sheet copy secrets through
/// here: unlock if needed → decrypt that one payload in memory → copy via
/// SecureClipboard (cleared after Settings › Vault › Clipboard clear,
/// default 30 s, and on lock) → haptic → toast "Password copied · clears
/// in 30s". The plaintext is not kept or logged.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which value to copy.
enum VaultCopyField {
  /// Password (login / Wi-Fi), card number, note body.
  primary,
  username,
  password,
}

/// Decrypts [record]'s payload with the open session (null when locked or
/// unreadable).
Future<VaultPayload?> readVaultPayload(
  WidgetRef ref,
  VaultItemRecord record,
) async {
  final key = ref.read(vaultSessionProvider).key;
  if (key == null || key.isDestroyed) return null;
  try {
    return await VaultPayloadCodec.open(
      key,
      record.encryptedPayload,
      itemId: record.id,
    );
  } on Object {
    return null;
  }
}

/// Copies [field] of [record]; returns true when something was copied.
Future<bool> copyVaultSecret(
  BuildContext context,
  WidgetRef ref,
  VaultItemRecord record, {
  VaultCopyField field = VaultCopyField.primary,
}) async {
  if (!await ensureVaultUnlocked(context)) return false;
  final payload = await readVaultPayload(ref, record);
  if (!context.mounted) return false;
  if (payload == null) {
    showFFToast(context, tr("Couldn't decrypt this item"));
    return false;
  }
  // (value, what it is called, the "none saved" toast) — each sentence is its
  // own key so a language is free to word the noun and the sentence together.
  final (value, what, none) = switch (field) {
    VaultCopyField.username => (
      payload.username,
      tr('Username'),
      tr('No username saved'),
    ),
    VaultCopyField.password => (
      payload.password,
      tr('Password'),
      tr('No password saved'),
    ),
    VaultCopyField.primary => switch (record.type) {
      VaultItemType.card => (
        payload.primarySecret(record.type),
        tr('Card number'),
        tr('No card number saved'),
      ),
      VaultItemType.secureNote => (
        payload.primarySecret(record.type),
        tr('Note'),
        tr('No note saved'),
      ),
      _ => (
        payload.primarySecret(record.type),
        tr('Password'),
        tr('No password saved'),
      ),
    },
  };
  if (value.isEmpty) {
    showFFToast(context, none);
    return false;
  }
  final settings = ref.read(settingsProvider);
  final seconds = settings.clipboardClearSeconds;
  // A username is not a secret: no auto-clear for it.
  final clears = field != VaultCopyField.username && seconds > 0;
  await ref
      .read(secureClipboardProvider)
      .copy(value, clearAfter: clears ? Duration(seconds: seconds) : null);
  ref.read(vaultSessionProvider.notifier).touch();
  if (settings.hapticsEnabled) unawaited(HapticFeedback.lightImpact());
  if (!context.mounted) return true;
  showFFToast(
    context,
    clears
        ? tr('{what} copied · clears in {s}s', {'what': what, 's': seconds})
        : tr('{what} copied', {'what': what}),
    icon: FontAwesomeIcons.solidCircleCheck,
  );
  return true;
}

/// The http(s) address in [raw] ("github.com" → https://github.com), or null
/// for anything else (javascript:, file:, intent: … are never opened).
Uri? vaultWebsiteUri(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final uri = Uri.tryParse(t.contains('://') ? t : 'https://$t');
  if (uri == null || uri.host.isEmpty) return null;
  return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
}

/// Opens [record]'s website in the browser (a link the user tapped — the
/// only kind of URL the app opens).
Future<void> openVaultWebsite(
  BuildContext context,
  WidgetRef ref,
  VaultItemRecord record,
) async {
  if (!await ensureVaultUnlocked(context)) return;
  final payload = await readVaultPayload(ref, record);
  final uri = payload == null ? null : vaultWebsiteUri(payload.url);
  if (!context.mounted) return;
  if (uri == null) {
    showFFToast(context, tr('No website saved'));
    return;
  }
  ref.read(vaultSessionProvider.notifier).touch();
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showFFToast(context, tr("Couldn't open the website"));
  }
}
