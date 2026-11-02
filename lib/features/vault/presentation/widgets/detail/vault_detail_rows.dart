/// ============================================================
/// VAULT DETAIL ROWS — the row kinds of the item detail (19)
/// ============================================================
///
/// [VaultDetailRows] builds the rows every item type uses: a plain value
/// (with copy), a secret (masked, revealed through the eye, auto-hides after
/// 4 s, long-press for large type, copy with auto-clear), a link (underlined,
/// copy + open) and the live 2FA code. The built-in types
/// (vault_detail_fields.dart) and the schema-driven ones
/// (vault_detail_schema.dart) both draw from here, so a bank PIN and a
/// login password behave identically. Secrets are masked until revealed
/// ([vaultRevealProvider]); a revealed password is colour-coded (digits sky,
/// symbols amber).
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
import 'package:focusflow/features/vault/presentation/providers/vault_item_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_detail_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_sheets.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_copy_button.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reveal.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

/// Row builders bound to one item's detail screen.
class VaultDetailRows {
  VaultDetailRows({
    required this.context,
    required this.ref,
    required this.id,
    required this.shown,
  });

  final BuildContext context;
  final WidgetRef ref;

  /// The item id (reveal state and the 2FA code are keyed by it).
  final String id;

  /// Fields currently revealed ([vaultRevealProvider]).
  final Set<String> shown;

  /// Fixed-width mask: never hints at the secret's length.
  static String _mask() => '•' * 12;

  Widget copy(String value, String what, {bool secret = true}) =>
      VaultCopyButton(
        semanticLabel: tr('Copy {what}', {'what': what.toLowerCase()}),
        onCopy: () => copyVaultValue(context, ref, value, what, secret: secret),
      );

  Widget reveal(String field, String what) => VaultRevealButton(
    open: shown.contains(field),
    what: what,
    cycle: ref.read(vaultRevealProvider(id).notifier).cycleOf(field),
    onTap: () => unawaited(toggleVaultReveal(context, ref, id, field)),
  );

  /// A masked value. [format] shapes the revealed text (card grouping);
  /// [mono] keeps the revealed text in the monospaced face (always on for
  /// secrets).
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
          _mask(),
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

  /// A visible value with a copy button ([secret] decides whether the copy
  /// auto-clears; [note] is a small tinted line under it, e.g. "Expires in
  /// 12 days").
  Widget plain(
    String label,
    String value, {
    bool secret = false,
    bool mono = false,
    String? note,
    VaultTone? noteTone,
    double? height,
  }) {
    final style = mono ? context.vaultMonoStyle : context.vaultValueStyle;
    return VaultFieldRow(
      label: label,
      value: note == null
          ? Text(value, style: height == null ? style : style.copyWith(height: height))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: style),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  note,
                  style: context.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: noteTone?.fg ?? context.ff.vaultInkMuted,
                  ),
                ),
              ],
            ),
      actions: [copy(value, label, secret: secret)],
    );
  }

  /// An underlined link: tap / the arrow button opens it (http / https
  /// only), the other button copies it.
  Widget link(String label, String value) {
    final ff = context.ff;
    final uri = vaultWebsiteUri(value);
    final display = value.replaceFirst(RegExp(r'^https?://'), '');
    void open() => unawaited(openVaultAddress(context, ref, value));
    return VaultFieldRow(
      label: label,
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
        VaultCopyButton(
          semanticLabel: tr('Copy website'),
          onCopy: () =>
              copyVaultValue(context, ref, value, label, secret: false),
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

  /// The live one-time code of this item.
  Widget totp() => VaultTotpRow(id: id);
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
class VaultTotpRow extends ConsumerStatefulWidget {
  const VaultTotpRow({required this.id, super.key});

  final String id;

  @override
  ConsumerState<VaultTotpRow> createState() => _VaultTotpRowState();
}

class _VaultTotpRowState extends ConsumerState<VaultTotpRow> {
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
