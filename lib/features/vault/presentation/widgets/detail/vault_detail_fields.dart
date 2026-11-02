/// ============================================================
/// VAULT DETAIL FIELDS — the secrets card of the item detail (19)
/// ============================================================
///
/// Per built-in type: Login (username · password · 2FA code · website), Card
/// (cardholder · number · expiry · CVV · PIN), Wi-Fi (network · password ·
/// security, QR share) and Secure note (the note). Custom fields follow.
/// The schema-driven types (bank account, passport …) are drawn by
/// [VaultSchemaDetail]. Row kinds (plain / secret / link / 2FA) live in
/// vault_detail_rows.dart: secrets are masked until revealed, hide again by
/// themselves after 4 s, copy with auto-clear.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_rows.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_schema_detail.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';

export 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_rows.dart'
    show VaultSecretText;

class VaultDetailFields extends ConsumerWidget {
  const VaultDetailFields({
    required this.record,
    required this.payload,
    super.key,
  });

  final VaultItemRecord record;
  final VaultPayload payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = record.id;
    final shown = ref.watch(vaultRevealProvider(id));
    final b = VaultDetailRows(context: context, ref: ref, id: id, shown: shown);
    final p = payload;
    if (record.type.isSchemaType) {
      return VaultSchemaDetail(record: record, payload: p, rows: b);
    }

    final rows = <Widget>[
      ...switch (record.type) {
        VaultItemType.login => [
          if (p.username.isNotEmpty) b.plain(tr('Username'), p.username),
          if (p.password.isNotEmpty)
            b.secret(tr('Password'), 'password', p.password, colour: true),
          if (record.hasTotp) b.totp(),
          if (p.url.isNotEmpty) b.link(tr('Website'), p.url),
        ],
        VaultItemType.card => [
          if (p.cardholder.isNotEmpty)
            b.plain(tr('Cardholder'), p.cardholder),
          if (p.cardNumber.isNotEmpty)
            b.secret(
              tr('Card number'),
              'number',
              p.cardNumber.replaceAll(' ', ''),
              format: VaultCardNumber.format,
            ),
          if (p.cardExpiry.isNotEmpty) b.plain(tr('Expiry'), p.cardExpiry),
          if (p.cardCvv.isNotEmpty) b.secret(tr('CVV'), 'cvv', p.cardCvv),
          if (p.cardPin.isNotEmpty) b.secret(tr('PIN'), 'pin', p.cardPin),
        ],
        VaultItemType.wifi => [
          if (p.wifiSsid.isNotEmpty)
            VaultFieldRow(
              label: tr('Network'),
              value: Text(p.wifiSsid, style: context.vaultValueStyle),
              actions: [
                VaultRoundButton(
                  icon: FontAwesomeIcons.qrcode,
                  semanticLabel: tr('Share network as QR code'),
                  // The QR encodes the password: same gate as revealing it.
                  onTap: () => unawaited(() async {
                    if (!await confirmVaultReveal(context, ref)) return;
                    if (!context.mounted) return;
                    await showVaultWifiQr(context, p);
                  }()),
                ),
                b.copy(p.wifiSsid, tr('Network'), secret: false),
              ],
            ),
          if (p.password.isNotEmpty)
            b.secret(tr('Password'), 'password', p.password, colour: true),
          if (p.wifiSecurity.isNotEmpty)
            VaultFieldRow(
              label: tr('Security'),
              value: Text(
                vaultWifiSecurityName(p.wifiSecurity),
                style: context.vaultValueStyle,
              ),
            ),
        ],
        VaultItemType.secureNote => [
          if (p.notes.isNotEmpty)
            b.plain(tr('Note'), p.notes, secret: true, height: 1.5),
        ],
        _ => const <Widget>[],
      },
      for (final (i, f) in p.customFields.indexed)
        if (f.hidden)
          b.secret(f.label.isEmpty ? tr('Field') : f.label, 'cf$i', f.value)
        else
          b.plain(f.label.isEmpty ? tr('Field') : f.label, f.value),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VaultCard(children: rows);
  }
}
