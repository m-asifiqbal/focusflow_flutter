/// ============================================================
/// VAULT SECRET CONTROLS — password / 2FA / reveal rows of the editor
/// ============================================================
///
/// The eye toggle, the password row (strength meter + Generate), the 2FA
/// row (QR scan) and their helpers, shared by the Login / Card / Wi-Fi
/// card ([VaultCredentialsCard]) and the schema-driven types
/// ([VaultSchemaSections]) — one implementation, so a bank account's
/// password behaves exactly like a login's: obscured, revealed only after
/// re-authentication when the user asked for that, generated and scanned
/// the same way.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_editor_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_generate_sheet.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_password_widgets.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_qr_scanner.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Mix into the State of an editor card that shows secrets.
mixin VaultSecretControls<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  VaultEditorArgs get editorArgs;
  VaultEditorTexts get editorTexts;

  /// Fields currently shown in clear. The password being edited is visible
  /// (as in the mockup) unless the user asked for re-authentication before
  /// revealing secrets.
  late final Set<String> shownSecrets = {
    if (!ref.read(settingsProvider).vaultReauthToReveal) 'password',
  };

  VaultEditorController get editor =>
      ref.read(vaultEditorProvider(editorArgs).notifier);

  TextEditingController textOf(String field, String initial) =>
      editorTexts.of(field, initial);

  /// The eye: shows the current state (eye = visible), as in the mockup.
  Widget eye(String field, String name) {
    final shown = shownSecrets.contains(field);
    return VaultIconButton(
      icon: shown ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
      semanticLabel: shown
          ? tr('Hide {name}', {'name': name})
          : tr('Show {name}', {'name': name}),
      onTap: () => unawaited(toggleSecret(field)),
    );
  }

  Future<void> toggleSecret(String field) async {
    if (shownSecrets.contains(field)) {
      setState(() => shownSecrets.remove(field));
      return;
    }
    if (!await confirmVaultReveal(context, ref) || !mounted) return;
    setState(() => shownSecrets.add(field));
  }

  Future<void> generatePassword() async {
    final value = await showVaultGenerateSheet(context);
    if (value == null || !mounted) return;
    editorTexts.set('password', value);
    editor.setPassword(value);
  }

  Future<void> scanTotp() async {
    final uri = await scanVaultTotpQr(context, ref);
    if (uri == null || !mounted) return;
    editorTexts.set('totp', uri);
    editor.setTotp(uri);
    final title = ref.read(vaultEditorProvider(editorArgs)).valueOrNull?.title;
    if (title != null && editorTexts.of('title').text != title) {
      editorTexts.set('title', title);
    }
  }

  /// Password + strength meter + Generate.
  Widget passwordRow(VaultEditorState s, {String? label}) => VaultTextRow(
    label: label ?? tr('Password'),
    controller: textOf('password', s.payload.password),
    onChanged: editor.setPassword,
    mono: true,
    obscure: !shownSecrets.contains('password'),
    autofillHints: const [AutofillHints.newPassword],
    trailing: [
      eye('password', tr('password')),
      VaultGeneratePill(onTap: () => unawaited(generatePassword())),
    ],
    below: VaultStrengthMeter(strength: s.strength),
  );

  /// 2FA secret with QR scan.
  Widget totpRow(VaultEditorState s, {String? label}) => VaultTextRow(
    label: label ?? tr('2FA secret (TOTP)'),
    hint: tr('Scan QR or paste key'),
    controller: textOf('totp', s.payload.totpSecret ?? ''),
    onChanged: editor.setTotp,
    errorText: s.totpInvalid ? tr('Not a valid 2FA key') : null,
    trailing: [
      VaultIconButton(
        icon: FontAwesomeIcons.qrcode,
        semanticLabel: tr('Scan 2FA QR code'),
        onTap: () => unawaited(scanTotp()),
      ),
    ],
  );
}
