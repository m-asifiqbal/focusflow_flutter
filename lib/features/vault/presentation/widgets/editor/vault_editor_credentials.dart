/// ============================================================
/// VAULT EDITOR CREDENTIALS — title card + the per-type secret fields (20)
/// ============================================================
///
/// [VaultTitleCard]: 56 pt brand tile, TITLE field (Lexend 20 w700) and
/// "Change icon". [VaultCredentialsCard]: the CREDENTIALS rows of the
/// selected type — Login (username, password + strength + Generate,
/// website, 2FA secret with QR scan), Card (holder, number, expiry, CVV,
/// PIN), Wi-Fi (network, password, security). Secure notes have none.
/// Edits go straight to [VaultEditorController]; the text lives in
/// [VaultEditorTexts].
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
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_editor_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_editor_state.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_generate_sheet.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_password_widgets.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_editor_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/editor/vault_qr_scanner.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_avatar.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultTitleCard extends StatelessWidget {
  const VaultTitleCard({
    required this.state,
    required this.controller,
    required this.onTitle,
    required this.onChangeIcon,
    super.key,
  });

  final VaultEditorState state;
  final TextEditingController controller;
  final ValueChanged<String> onTitle;
  final VoidCallback onChangeIcon;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return VaultCard(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg + 1,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: tr('Change icon'),
                excludeSemantics: true,
                child: FFPressable(
                  onTap: onChangeIcon,
                  child: VaultAvatar(
                    title: state.title,
                    type: state.type,
                    iconKey: state.iconKey,
                    colorHex: state.colorHex,
                    size: VaultSizes.editorAvatar,
                    radius: AppRadii.statTile,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md + 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VaultFieldLabel(tr('Title')),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      textField: true,
                      label: tr('Title'),
                      child: TextField(
                        controller: controller,
                        onChanged: onTitle,
                        autofocus: state.isNew,
                        textCapitalization: TextCapitalization.words,
                        enableIMEPersonalizedLearning: false,
                        cursorColor: ff.vaultAccent,
                        style: context.text.cardTitle.copyWith(
                          fontSize: VaultType.stat,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: ff.vaultInk,
                        ),
                        decoration: vaultBareDecoration(
                          hintText: tr('e.g. {example}', {
                            'example': _example(state.type),
                          }),
                          hintStyle: context.text.cardTitle.copyWith(
                            fontSize: VaultType.stat,
                            color: ff.vaultFieldLabel,
                          ),
                        ),
                      ),
                    ),
                    if (state.titleError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        state.titleError!,
                        style: context.text.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ff.vaultDanger.fg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FFPressable(
                onTap: onChangeIcon,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSizes.minTap),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      tr('Change icon'),
                      style: context.text.caption.copyWith(
                        fontSize: VaultType.secondary,
                        fontWeight: FontWeight.w600,
                        color: ff.vaultAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _example(VaultItemType t) => switch (t) {
    VaultItemType.login => 'Figma', // brand name
    VaultItemType.card => 'Visa Platinum', // product name
    VaultItemType.wifi => tr('Home Wi-Fi'),
    VaultItemType.secureNote => tr('Passport'),
  };
}

class VaultCredentialsCard extends ConsumerStatefulWidget {
  const VaultCredentialsCard({
    required this.args,
    required this.state,
    required this.texts,
    super.key,
  });

  final VaultEditorArgs args;
  final VaultEditorState state;
  final VaultEditorTexts texts;

  @override
  ConsumerState<VaultCredentialsCard> createState() =>
      _VaultCredentialsCardState();
}

class _VaultCredentialsCardState extends ConsumerState<VaultCredentialsCard> {
  final Set<String> _shown = {};

  @override
  void initState() {
    super.initState();
    // The password being edited is visible (as in the mockup) unless the
    // user asked for re-authentication before revealing secrets.
    if (!ref.read(settingsProvider).vaultReauthToReveal) _shown.add('password');
  }

  VaultEditorController get _c =>
      ref.read(vaultEditorProvider(widget.args).notifier);

  TextEditingController _t(String field, String initial) =>
      widget.texts.of(field, initial);

  Widget _eye(String field, String name) {
    final shown = _shown.contains(field);
    return VaultIconButton(
      // The icon shows the current state (eye = visible), as in the mockup.
      icon: shown ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
      semanticLabel: shown
          ? tr('Hide {name}', {'name': name})
          : tr('Show {name}', {'name': name}),
      onTap: () => unawaited(_toggle(field)),
    );
  }

  Future<void> _toggle(String field) async {
    if (_shown.contains(field)) {
      setState(() => _shown.remove(field));
      return;
    }
    if (!await confirmVaultReveal(context, ref) || !mounted) return;
    setState(() => _shown.add(field));
  }

  Future<void> _generate() async {
    final value = await showVaultGenerateSheet(context);
    if (value == null || !mounted) return;
    widget.texts.set('password', value);
    _c.setPassword(value);
  }

  Future<void> _scan() async {
    final uri = await scanVaultTotpQr(context, ref);
    if (uri == null || !mounted) return;
    widget.texts.set('totp', uri);
    _c.setTotp(uri);
    final title = ref.read(vaultEditorProvider(widget.args)).valueOrNull?.title;
    if (title != null && widget.texts.of('title').text != title) {
      widget.texts.set('title', title);
    }
  }

  Widget _password(VaultEditorState s) => VaultTextRow(
    label: tr('Password'),
    controller: _t('password', s.payload.password),
    onChanged: _c.setPassword,
    mono: true,
    obscure: !_shown.contains('password'),
    autofillHints: const [AutofillHints.newPassword],
    trailing: [
      _eye('password', tr('password')),
      VaultGeneratePill(onTap: () => unawaited(_generate())),
    ],
    below: VaultStrengthMeter(strength: s.strength),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = s.payload;
    final c = _c;
    final rows = switch (s.type) {
      VaultItemType.login => [
        VaultTextRow(
          label: tr('Username / email'),
          controller: _t('username', p.username),
          onChanged: c.setUsername,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
        ),
        _password(s),
        VaultTextRow(
          label: tr('Website'),
          hint: 'example.com',
          controller: _t('url', p.url),
          onChanged: c.setUrl,
          keyboardType: TextInputType.url,
        ),
        VaultTextRow(
          label: tr('2FA secret (TOTP)'),
          hint: tr('Scan QR or paste key'),
          controller: _t('totp', p.totpSecret ?? ''),
          onChanged: c.setTotp,
          errorText: s.totpInvalid ? tr('Not a valid 2FA key') : null,
          trailing: [
            VaultIconButton(
              icon: FontAwesomeIcons.qrcode,
              semanticLabel: tr('Scan 2FA QR code'),
              onTap: () => unawaited(_scan()),
            ),
          ],
        ),
      ],
      VaultItemType.card => [
        VaultTextRow(
          label: tr('Cardholder name'),
          controller: _t('cardholder', p.cardholder),
          onChanged: c.setCardholder,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.creditCardName],
        ),
        VaultTextRow(
          label: tr('Card number'),
          hint: '4242 4242 4242 4242',
          controller: _t('cardNumber', p.cardNumber),
          onChanged: c.setCardNumber,
          mono: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
          ],
          autofillHints: const [AutofillHints.creditCardNumber],
        ),
        VaultTextRow(
          label: tr('Expiry (MM/YY)'),
          hint: tr('MM/YY'),
          controller: _t('cardExpiry', p.cardExpiry),
          onChanged: c.setCardExpiry,
          mono: true,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
            LengthLimitingTextInputFormatter(5),
          ],
        ),
        VaultTextRow(
          label: tr('Security code (CVV)'),
          controller: _t('cardCvv', p.cardCvv),
          onChanged: c.setCardCvv,
          mono: true,
          obscure: !_shown.contains('cvv'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          trailing: [_eye('cvv', tr('security code'))],
        ),
        VaultTextRow(
          label: tr('PIN'),
          controller: _t('cardPin', p.cardPin),
          onChanged: c.setCardPin,
          mono: true,
          obscure: !_shown.contains('pin'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          trailing: [_eye('pin', tr('PIN'))],
        ),
      ],
      VaultItemType.wifi => [
        VaultTextRow(
          label: tr('Network name (SSID)'),
          controller: _t('wifiSsid', p.wifiSsid),
          onChanged: c.setWifiSsid,
        ),
        _password(s),
        VaultValueRow(
          label: tr('Security'),
          value: vaultWifiSecurityName(
            p.wifiSecurity.isEmpty ? 'WPA2' : p.wifiSecurity,
          ),
          onTap: () => unawaited(_pickSecurity(p.wifiSecurity)),
        ),
      ],
      VaultItemType.secureNote => const <Widget>[],
    };
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VaultSectionLabel(tr('Credentials')),
        VaultCard(children: rows),
      ],
    );
  }

  Future<void> _pickSecurity(String current) async {
    final choice = await showVaultChoiceSheet<String>(
      context,
      title: tr('Security'),
      current: current.isEmpty ? 'WPA2' : current,
      options: [
        // The stored value is the English / protocol name; only the label
        // ("None") is translated.
        for (final v in const ['WPA3', 'WPA2', 'WEP', 'None'])
          (value: v, label: vaultWifiSecurityName(v)),
      ],
    );
    if (choice != null) _c.setWifiSecurity(choice.value);
  }
}
