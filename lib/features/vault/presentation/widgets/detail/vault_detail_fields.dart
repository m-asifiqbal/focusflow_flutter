/// ============================================================
/// VAULT DETAIL FIELDS — the secrets card of the item detail (19)
/// ============================================================
///
/// Per type: Login (username · password · 2FA code · website), Card
/// (cardholder · number · expiry · CVV · PIN), Wi-Fi (network · password ·
/// security, QR share) and Secure note (the note). Custom fields follow.
/// Secrets are masked until revealed ([vaultRevealProvider]) and hide again
/// by themselves after 4 s (a ring around the eye counts it down); a
/// revealed password is colour-coded (digits sky, symbols amber); long-press a
/// password for the large-type view. Copies auto-clear.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_detail_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reveal.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

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
    final p = payload;

    Widget copy(String value, String what, {bool secret = true}) =>
        VaultRoundButton(
          icon: FontAwesomeIcons.solidCopy,
          semanticLabel: tr('Copy {what}', {'what': what.toLowerCase()}),
          onTap: () => unawaited(
            copyVaultValue(context, ref, value, what, secret: secret),
          ),
        );

    Widget reveal(String field, String what) => VaultRevealButton(
      open: shown.contains(field),
      what: what,
      cycle: ref.read(vaultRevealProvider(id).notifier).cycleOf(field),
      onTap: () => unawaited(toggleVaultReveal(context, ref, id, field)),
    );

    Widget secret(
      String label,
      String field,
      String value, {
      bool colour = false,
      String Function(String)? format,
    }) {
      final open = shown.contains(field);
      final what = label.toLowerCase();
      return VaultFieldRow(
        label: label,
        value: VaultSecretSwitcher(
          open: open,
          revealed: VaultSecretText(
            format == null ? value : format(value),
            colour: colour,
          ),
          masked: Text(
            _mask(value),
            style: context.vaultMonoStyle,
            semanticsLabel: tr('{label} hidden', {'label': label}),
          ),
        ),
        actions: [reveal(field, what), copy(value, label)],
        onLongPress: () => unawaited(() async {
          // Large type shows the raw value: gate it like the eye button
          // unless this field is already revealed.
          if (!open && !await confirmVaultReveal(context, ref)) return;
          if (!context.mounted) return;
          await showVaultLargeType(context, value);
        }()),
      );
    }

    Widget plain(String label, String value, {bool secret = false}) =>
        VaultFieldRow(
          label: label,
          value: Text(value, style: context.vaultValueStyle),
          actions: [copy(value, label, secret: secret)],
        );

    final rows = <Widget>[
      ...switch (record.type) {
        VaultItemType.login => [
          if (p.username.isNotEmpty) plain(tr('Username'), p.username),
          if (p.password.isNotEmpty)
            secret(tr('Password'), 'password', p.password, colour: true),
          if (record.hasTotp) _TotpRow(id: id),
          if (p.url.isNotEmpty) _WebsiteRow(record: record, url: p.url),
        ],
        VaultItemType.card => [
          if (p.cardholder.isNotEmpty) plain(tr('Cardholder'), p.cardholder),
          if (p.cardNumber.isNotEmpty)
            secret(
              tr('Card number'),
              'number',
              p.cardNumber.replaceAll(' ', ''),
              format: _groupCard,
            ),
          if (p.cardExpiry.isNotEmpty) plain(tr('Expiry'), p.cardExpiry),
          if (p.cardCvv.isNotEmpty) secret(tr('CVV'), 'cvv', p.cardCvv),
          if (p.cardPin.isNotEmpty) secret(tr('PIN'), 'pin', p.cardPin),
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
                copy(p.wifiSsid, tr('Network'), secret: false),
              ],
            ),
          if (p.password.isNotEmpty)
            secret(tr('Password'), 'password', p.password, colour: true),
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
            VaultFieldRow(
              label: tr('Note'),
              value: Text(
                p.notes,
                style: context.vaultValueStyle.copyWith(height: 1.5),
              ),
              actions: [copy(p.notes, tr('Note'))],
            ),
        ],
      },
      for (final (i, f) in p.customFields.indexed)
        if (f.hidden)
          secret(f.label.isEmpty ? tr('Field') : f.label, 'cf$i', f.value)
        else
          plain(f.label.isEmpty ? tr('Field') : f.label, f.value),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return VaultCard(children: rows);
  }

  /// Fixed-width mask: never hints at the secret's length.
  static String _mask(String v) => '•' * 12;

  static String _groupCard(String digits) => [
    for (var i = 0; i < digits.length; i += 4)
      digits.substring(i, (i + 4).clamp(0, digits.length)),
  ].join(' ');
}

/// A revealed secret in mono; [colour] codes digits sky and symbols amber.
class VaultSecretText extends StatelessWidget {
  const VaultSecretText(
    this.value, {
    this.colour = false,
    this.style,
    super.key,
  });

  final String value;
  final bool colour;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final base = style ?? context.vaultMonoStyle;
    if (!colour) return Text(value, style: base);
    return Text.rich(
      TextSpan(
        children: [
          for (final ch in value.characters)
            TextSpan(
              text: ch,
              style: _isDigit(ch)
                  ? TextStyle(color: ff.vaultSecretDigit)
                  : _isLetter(ch) || ch == ' '
                  ? null
                  : TextStyle(color: ff.vaultSecretSymbol),
            ),
        ],
      ),
      style: base,
    );
  }

  static bool _isDigit(String c) => RegExp(r'^[0-9]$').hasMatch(c);
  static bool _isLetter(String c) =>
      RegExp(r'^\p{L}$', unicode: true).hasMatch(c);
}

/// "ONE-TIME CODE (2FA)" — big emerald digits + countdown ring; tap copies.
/// Ticks once a second while shown.
class _TotpRow extends ConsumerStatefulWidget {
  const _TotpRow({required this.id});

  final String id;

  @override
  ConsumerState<_TotpRow> createState() => _TotpRowState();
}

class _TotpRowState extends ConsumerState<_TotpRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final config = ref.watch(vaultTotpConfigProvider(widget.id));
    final totp = config == null
        ? null
        : VaultTotpCode.at(config, ref.read(clockProvider).now());
    final code = totp?.code ?? '––– –––';
    return Semantics(
      button: totp != null,
      label: totp == null
          ? tr('One-time code unavailable')
          : tr(
              'One-time code {code}, {secondsLeft} seconds left. Double tap to copy',
              {
                'code': totp.digits.split('').join(' '),
                'secondsLeft': totp.secondsLeft,
              },
            ),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: totp == null
            ? null
            : () => unawaited(
                copyVaultValue(context, ref, totp.digits, tr('Code')),
              ),
        child: VaultFieldRow(
          label: tr('One-time code (2FA)'),
          minHeight: VaultSizes.totpCard,
          value: Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: Text(
              code,
              // Mockup: the geometric heading font (Lexend), wide tracking.
              style: context.text.stat.copyWith(
                fontSize: VaultType.code,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 3.3,
                height: 1.2,
                color: ff.vaultAccentBright,
              ),
            ),
          ),
          actions: [
            if (totp != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xxs),
                child: FFProgressRing(
                  progress: totp.secondsLeft / totp.period,
                  size: VaultSizes.totpRing,
                  stroke: VaultSizes.totpStroke,
                  color: ff.vaultAccent,
                  trackColor: ff.vaultTrack,
                  child: Text(
                    '${totp.secondsLeft}',
                    textScaler: TextScaler.noScaling,
                    style: context.text.meta.copyWith(
                      fontSize: VaultType.secondary,
                      fontWeight: FontWeight.w700,
                      color: ff.vaultInk,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "WEBSITE" — underlined link (opens) + copy + open buttons.
class _WebsiteRow extends ConsumerWidget {
  const _WebsiteRow({required this.record, required this.url});

  final VaultItemRecord record;
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final uri = vaultWebsiteUri(url);
    final display = url.replaceFirst(RegExp(r'^https?://'), '');
    void open() => unawaited(openVaultWebsite(context, ref, record));
    return VaultFieldRow(
      label: tr('Website'),
      value: Semantics(
        link: uri != null,
        child: GestureDetector(
          onTap: uri == null ? null : open,
          child: Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.vaultValueStyle.copyWith(
              color: ff.vaultAccentBright,
              decoration: TextDecoration.underline,
              decorationColor: ff.vaultAccentBright,
            ),
          ),
        ),
      ),
      actions: [
        VaultRoundButton(
          icon: FontAwesomeIcons.solidCopy,
          semanticLabel: tr('Copy website'),
          onTap: () => unawaited(
            copyVaultValue(context, ref, url, tr('Website'), secret: false),
          ),
        ),
        if (uri != null)
          VaultRoundButton(
            icon: FontAwesomeIcons.arrowUpRightFromSquare,
            semanticLabel: tr('Open website'),
            onTap: open,
          ),
      ],
    );
  }
}
