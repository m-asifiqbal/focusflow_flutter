/// ============================================================
/// VAULT DETAIL SHEETS — large type, Wi-Fi QR, password history (19)
/// ============================================================
///
/// * [showVaultLargeType]      — long-press a secret: each character big,
///   numbered, colour-coded (read it out / type it on a TV).
/// * [showVaultWifiQr]         — "WIFI:" QR code so a guest can join by
///   scanning (drawn locally; nothing leaves the device).
/// * [showVaultPasswordHistory] — previous passwords, decrypted only while
///   the sheet is open, masked until tapped, copy with auto-clear.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/presentation/vault_auto_hide.dart';
import 'package:focusflow/features/vault/presentation/vault_detail_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/detail/vault_detail_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reveal.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:pdf/widgets.dart' as pw show Barcode, BarcodeBar;

/// Large-type view of [value].
Future<void> showVaultLargeType(BuildContext context, String value) {
  if (value.isEmpty) return Future.value();
  return showFFDialog<void>(
    context,
    builder: (ctx) {
      final ff = ctx.ff;
      final chars = value.characters.toList();
      return FFDialog(
        title: 'Large type',
        content: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (i, c) in chars.indexed)
              Container(
                width: VaultSizes.charCell,
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: ff.vaultKey,
                  borderRadius: BorderRadius.circular(AppRadii.tileSm),
                ),
                child: Column(
                  children: [
                    VaultSecretText(
                      c,
                      colour: true,
                      style: ctx.vaultMonoStyle.copyWith(
                        fontSize: VaultType.display,
                      ),
                    ),
                    Text(
                      '${i + 1}',
                      style: ctx.text.caption.copyWith(
                        color: ff.vaultFieldLabel,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FFPrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      );
    },
  );
}

/// The standard Wi-Fi join string (`WIFI:T:WPA;S:name;P:pass;;`).
String vaultWifiQrData(VaultPayload p) {
  String esc(String v) =>
      v.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');
  final sec = p.wifiSecurity.toUpperCase();
  final type = sec.startsWith('WEP')
      ? 'WEP'
      : sec == 'NONE' || p.password.isEmpty
      ? 'nopass'
      : 'WPA';
  final pass = type == 'nopass' ? '' : 'P:${esc(p.password)};';
  return 'WIFI:T:$type;S:${esc(p.wifiSsid)};$pass;';
}

Future<void> showVaultWifiQr(BuildContext context, VaultPayload p) =>
    showFFBottomSheet<void>(
      context,
      vault: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Join ${p.wifiSsid}',
              textAlign: TextAlign.center,
              style: ctx.text.sectionTitle.copyWith(color: ctx.ff.vaultInk),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Scan with a phone camera to connect',
              textAlign: TextAlign.center,
              style: ctx.text.bodySmall.copyWith(
                color: ctx.ff.vaultSubtitleMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              image: true,
              label: 'QR code for ${p.wifiSsid}',
              child: Container(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ctx.ff.vaultBrandLight,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: SizedBox.square(
                  dimension: 200,
                  child: CustomPaint(
                    painter: _QrPainter(
                      vaultWifiQrData(p),
                      ctx.ff.vaultOnAccentInk,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

class _QrPainter extends CustomPainter {
  _QrPainter(this.data, this.color);

  final String data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final elements = pw.Barcode.qrCode().make(
      data,
      width: size.width,
      height: size.height,
      drawText: false,
    );
    for (final e in elements) {
      if (e is pw.BarcodeBar && e.black) {
        canvas.drawRect(
          Rect.fromLTWH(e.left, e.top, e.width + 0.5, e.height + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data || old.color != color;
}

/// Previous passwords of [entries] (already loaded, newest first).
Future<void> showVaultPasswordHistory(
  BuildContext context,
  List<VaultHistoryEntry> entries,
) => showFFBottomSheet<void>(
  context,
  vault: true,
  builder: (_) => _HistorySheet(entries: entries),
);

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet({required this.entries});

  final List<VaultHistoryEntry> entries;

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  /// Hiding is free; revealing an old password goes through the same
  /// "Ask for PIN to reveal" gate as the detail's eye button.
  Future<void> _toggle(int i) async {
    if (_auto.isShown(i)) {
      _auto.hide(i);
      return;
    }
    if (!await confirmVaultReveal(context, ref) || !mounted) return;
    _auto.show(i);
  }

  /// Shown rows hide themselves after 4 s, like the detail's eye.
  late final VaultAutoHide<int> _auto = VaultAutoHide<int>(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void dispose() {
    _auto.dispose();
    super.dispose();
  }

  late final Future<List<(DateTime, String)>> _items = readVaultHistory(
    ref,
    widget.entries,
  );

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final fmt = DateFormats.of('MMM d, y');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen - 4,
        AppSpacing.sm,
        AppSpacing.screen - 4,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Password history',
            style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Older passwords of this item, kept encrypted.',
            style: context.text.bodySmall.copyWith(
              color: ff.vaultSubtitleMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder(
            future: _items,
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const FFSkeletonList(count: 2, kind: FFSkeletonKind.row);
              }
              if (items.isEmpty) {
                return Text(
                  'No previous passwords.',
                  style: context.text.body.copyWith(color: ff.vaultInkSoft),
                );
              }
              return VaultCard(
                children: [
                  for (final (i, (at, pw)) in items.indexed)
                    VaultFieldRow(
                      label: 'Changed ${fmt.format(at)}',
                      value: VaultSecretSwitcher(
                        open: _auto.isShown(i),
                        revealed: VaultSecretText(pw, colour: true),
                        masked: Text('•' * 12, style: context.vaultMonoStyle),
                      ),
                      actions: [
                        VaultRevealButton(
                          open: _auto.isShown(i),
                          what: 'password',
                          cycle: _auto.cycleOf(i),
                          onTap: () => unawaited(_toggle(i)),
                        ),
                        VaultRoundButton(
                          icon: FontAwesomeIcons.solidCopy,
                          semanticLabel: 'Copy password',
                          onTap: () => unawaited(
                            copyVaultValue(context, ref, pw, 'Password'),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
